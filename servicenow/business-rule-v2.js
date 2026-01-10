/**
 * ServiceNow Business Rule: Trigger GitHub Actions - Research Computing
 * Version: 2.0 (Updated for wireframe design)
 *
 * Table: sc_req_item
 * When: after
 * Update: true
 * Advanced: true
 *
 * Condition (Script):
 *   current.state == 3 && previous.state != 3 &&
 *   (current.cat_item.name == 'Start Research Computing' ||
 *    current.cat_item.name == 'Request Secure PHI Research (AVE)')
 *
 * Description:
 *   Triggers GitHub Actions workflow when a research computing request
 *   is approved. Handles both Standard and PHI/AVE request types.
 */

(function executeRule(current, previous) {

    // ==========================================
    // Configuration - System Properties
    // ==========================================
    var config = {
        githubPAT: gs.getProperty('x_umm_cloud.github_pat', ''),
        githubOwner: gs.getProperty('x_umm_cloud.github_owner', 'your-org'),
        githubRepo: gs.getProperty('x_umm_cloud.github_repo', 'umm-cloud-provisioning'),
        eventType: 'provision-research-environment'
    };

    // Validate configuration
    if (!config.githubPAT) {
        logError('GitHub PAT not configured. Set system property: x_umm_cloud.github_pat');
        updateWorkNotes('ERROR: GitHub integration not configured. Contact IT administrator.');
        return;
    }

    try {
        // ==========================================
        // Determine Request Type
        // ==========================================
        var catalogItemName = current.cat_item.name.toString();
        var isPhiRequest = catalogItemName.indexOf('PHI') > -1 || catalogItemName.indexOf('AVE') > -1;
        var requestType = isPhiRequest ? 'phi_ave' : 'standard_research';

        gs.info('Processing ' + requestType + ' request: ' + current.number);

        // ==========================================
        // Get Variables
        // ==========================================
        var variables = getRequestVariables(current.sys_id);

        // ==========================================
        // Build Payload
        // ==========================================
        var payload = buildPayload(requestType, variables, current);

        // ==========================================
        // Send to GitHub
        // ==========================================
        var result = triggerGitHubWorkflow(config, payload);

        // ==========================================
        // Update Work Notes
        // ==========================================
        if (result.success) {
            var successMsg = buildSuccessMessage(requestType, variables);
            updateWorkNotes(successMsg);
            gs.info('GitHub workflow triggered successfully for ' + current.number);
        } else {
            updateWorkNotes('ERROR: Failed to trigger provisioning.\n' + result.error);
            gs.error('GitHub trigger failed for ' + current.number + ': ' + result.error);
        }

    } catch (ex) {
        logError('Exception in GitHub trigger: ' + ex.message);
        updateWorkNotes('ERROR: Exception during provisioning trigger.\n' + ex.message);
    }

    // ==========================================
    // Helper Functions
    // ==========================================

    function getRequestVariables(ritmSysId) {
        var vars = {};
        var mtom = new GlideRecord('sc_item_option_mtom');
        mtom.addQuery('request_item', ritmSysId);
        mtom.query();

        while (mtom.next()) {
            var option = mtom.sc_item_option;
            if (option) {
                var itemOption = option.item_option_new;
                if (itemOption && itemOption.name) {
                    var varName = itemOption.name.toString();
                    var varValue = option.value ? option.value.toString() : '';
                    vars[varName] = varValue;
                }
            }
        }
        return vars;
    }

    function buildPayload(requestType, variables, ritm) {
        var payload = {
            event_type: config.eventType,
            client_payload: {
                // Common fields
                ticket_number: ritm.number.toString(),
                request_type: requestType,
                project_name: variables.project_name || '',
                principal_investigator: getPIEmail(variables, ritm),
                department: variables.department || '',
                cost_center: variables.grant_code || variables.funding_source || '',
                requested_by: getRequesterEmail(ritm),
                created_at: new GlideDateTime().toString()
            }
        };

        if (requestType === 'standard_research') {
            // Standard Research specific fields
            payload.client_payload.workload_types = getWorkloadTypes(variables);
            payload.client_payload.data_type = variables.data_type || 'non_phi';
            payload.client_payload.expected_end_date = variables.expected_end_date || '';
            payload.client_payload.additional_users = variables.additional_users || '';
            payload.client_payload.environment = 'dev';
            payload.client_payload.security_level = 'standard';

        } else if (requestType === 'phi_ave') {
            // PHI/AVE specific fields
            payload.client_payload.irb_number = variables.irb_number || '';
            payload.client_payload.irb_status = variables.irb_status || '';
            payload.client_payload.research_purpose = variables.research_purpose || '';
            payload.client_payload.access_method = variables.access_method || 'remote_desktop';
            payload.client_payload.expected_duration = variables.expected_duration || '6_months';
            payload.client_payload.data_retention = variables.data_retention || '90_days';
            payload.client_payload.additional_researchers = variables.additional_researchers || '';
            payload.client_payload.additional_analysts = variables.additional_analysts || '';
            payload.client_payload.additional_viewers = variables.additional_viewers || '';
            payload.client_payload.environment = 'prod';
            payload.client_payload.security_level = 'hipaa';
            payload.client_payload.data_classification = 'phi';
        }

        return payload;
    }

    function getWorkloadTypes(variables) {
        var workloads = [];
        if (variables.workload_statistical === 'true') workloads.push('statistical');
        if (variables.workload_imaging === 'true') workloads.push('imaging');
        if (variables.workload_ml === 'true') workloads.push('ml');
        if (variables.workload_data_prep === 'true') workloads.push('data_prep');
        if (variables.workload_unsure === 'true') workloads.push('recommend');
        return workloads.join(',') || 'general';
    }

    function getPIEmail(variables, ritm) {
        try {
            if (variables.principal_investigator) {
                var user = new GlideRecord('sys_user');
                if (user.get(variables.principal_investigator)) {
                    return user.email.toString();
                }
            }
        } catch (e) {
            gs.warn('Could not get PI email: ' + e.message);
        }
        return getRequesterEmail(ritm);
    }

    function getRequesterEmail(ritm) {
        try {
            if (ritm.request && ritm.request.requested_for) {
                var email = ritm.request.requested_for.email;
                if (email) return email.toString();
            }
        } catch (e) {
            gs.warn('Could not get requester email: ' + e.message);
        }
        return 'unknown@umich.edu';
    }

    function triggerGitHubWorkflow(config, payload) {
        var endpoint = 'https://api.github.com/repos/' + config.githubOwner + '/' + config.githubRepo + '/dispatches';

        var request = new sn_ws.RESTMessageV2();
        request.setEndpoint(endpoint);
        request.setHttpMethod('POST');
        request.setRequestHeader('Accept', 'application/vnd.github.v3+json');
        request.setRequestHeader('Authorization', 'token ' + config.githubPAT);
        request.setRequestHeader('Content-Type', 'application/json');
        request.setRequestHeader('User-Agent', 'ServiceNow-UMM-ResearchComputing');
        request.setRequestBody(JSON.stringify(payload));

        var response = request.execute();
        var httpStatus = response.getStatusCode();

        if (httpStatus == 204 || httpStatus == 200) {
            return { success: true };
        } else {
            return {
                success: false,
                error: 'HTTP ' + httpStatus + ': ' + response.getBody()
            };
        }
    }

    function buildSuccessMessage(requestType, variables) {
        var msg = '✅ Provisioning workflow triggered successfully!\n\n';

        if (requestType === 'standard_research') {
            msg += '📋 Request Details:\n';
            msg += '• Type: Standard Research Computing\n';
            msg += '• Project: ' + (variables.project_name || 'N/A') + '\n';
            msg += '• Department: ' + (variables.department || 'N/A') + '\n';
            msg += '• Workloads: ' + getWorkloadTypes(variables) + '\n\n';
            msg += '⏱️ Expected provisioning time: 1-2 business days\n';
            msg += 'You will receive an email when your environment is ready.';

        } else if (requestType === 'phi_ave') {
            msg += '📋 Request Details:\n';
            msg += '• Type: Secure PHI Research (AVE)\n';
            msg += '• Project: ' + (variables.project_name || 'N/A') + '\n';
            msg += '• IRB: ' + (variables.irb_number || 'N/A') + '\n';
            msg += '• Access: ' + (variables.access_method || 'N/A') + '\n';
            msg += '• Duration: ' + (variables.expected_duration || 'N/A') + '\n\n';
            msg += '🔒 Security Level: HIPAA Compliant\n';
            msg += '⏱️ Expected provisioning time: 3-5 business days\n';
            msg += '(Includes security review and compliance verification)\n\n';
            msg += 'You will receive email updates throughout the process.';
        }

        return msg;
    }

    function updateWorkNotes(message) {
        current.work_notes = message;
        current.update();
    }

    function logError(message) {
        gs.error('[Research Computing] ' + message);
    }

})(current, previous);


// ==========================================
// ADDITIONAL BUSINESS RULE: IRB Status Check
// ==========================================
// Create a separate business rule for IRB pending cases
/*
 * Name: Hold PHI Request for IRB Approval
 * Table: sc_req_item
 * When: before
 * Insert/Update: true
 *
 * Condition:
 *   current.cat_item.name == 'Request Secure PHI Research (AVE)' &&
 *   current.state == 3
 *
 * Script:
(function executeRule(current, previous) {
    var variables = getVariables(current.sys_id);

    if (variables.irb_status === 'pending') {
        // Don't trigger provisioning yet - wait for IRB
        current.state = 2; // Waiting for Approval
        current.work_notes = 'Request on hold pending IRB approval.\n' +
                            'IRB Number: ' + variables.irb_number + '\n' +
                            'Once IRB is approved, update the request to proceed.';
        gs.info('PHI request ' + current.number + ' held for IRB approval');
    }

    function getVariables(ritmSysId) {
        // Same helper function as above
    }
})(current, previous);
*/
