/**
 * ServiceNow Business Rule: Trigger GitHub Actions - Research Computing
 * Version: 3.0 (Fixed for GitHub API 10 property limit)
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
        // Build Payload (MAX 10 properties!)
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
        // GitHub API limits client_payload to 10 properties
        // Consolidate data into JSON strings where needed

        var payload = {
            event_type: config.eventType,
            client_payload: {
                // Property 1: ticket_number
                ticket_number: ritm.number.toString(),
                // Property 2: request_type
                request_type: requestType,
                // Property 3: project_name
                project_name: variables.project_name || 'research-project',
                // Property 4: principal_investigator
                principal_investigator: getPIEmail(variables, ritm),
                // Property 5: department
                department: variables.department || 'research',
                // Property 6: cost_center
                cost_center: variables.grant_code || variables.funding_source || ''
            }
        };

        if (requestType === 'standard_research') {
            // Property 7: workload_types
            payload.client_payload.workload_types = getWorkloadTypes(variables);
            // Property 8: extra_data (consolidated)
            payload.client_payload.extra_data = JSON.stringify({
                data_type: variables.data_type || 'non_phi',
                expected_end_date: variables.expected_end_date || '',
                additional_users: variables.additional_users || '',
                environment: 'dev',
                security_level: 'standard'
            });

        } else if (requestType === 'phi_ave') {
            // Property 7: irb_number
            payload.client_payload.irb_number = variables.irb_number || '';
            // Property 8: access_method
            payload.client_payload.access_method = variables.access_method || 'both';
            // Property 9: extra_data (consolidated)
            payload.client_payload.extra_data = JSON.stringify({
                irb_status: variables.irb_status || '',
                expected_duration: variables.expected_duration || '6_months',
                data_retention: variables.data_retention || '90_days',
                environment: 'prod',
                security_level: 'hipaa',
                data_classification: 'phi'
            });
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
        var msg = 'Provisioning workflow triggered successfully!\n\n';

        if (requestType === 'standard_research') {
            msg += 'Request Details:\n';
            msg += '- Type: Standard Research Computing\n';
            msg += '- Project: ' + (variables.project_name || 'N/A') + '\n';
            msg += '- Department: ' + (variables.department || 'N/A') + '\n';
            msg += '- Workloads: ' + getWorkloadTypes(variables) + '\n\n';
            msg += 'Expected provisioning time: 10-15 minutes\n';
            msg += 'You will receive an email when your environment is ready.';

        } else if (requestType === 'phi_ave') {
            msg += 'Request Details:\n';
            msg += '- Type: Secure PHI Research (AVE)\n';
            msg += '- Project: ' + (variables.project_name || 'N/A') + '\n';
            msg += '- IRB: ' + (variables.irb_number || 'N/A') + '\n';
            msg += '- Access: ' + (variables.access_method || 'N/A') + '\n\n';
            msg += 'Security Level: HIPAA Compliant\n';
            msg += 'Expected provisioning time: 15-30 minutes\n';
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
