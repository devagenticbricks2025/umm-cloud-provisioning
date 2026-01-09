/**
 * ServiceNow Business Rule: Trigger GitHub Actions After Approval
 *
 * Table: sc_req_item
 * When: after
 * Update: true
 * Advanced: true
 *
 * Condition (filter):
 *   current.state == 3 && previous.state != 3 &&
 *   current.cat_item.name == 'Request Azure Cloud Resource'
 *
 * Description:
 *   This business rule triggers a GitHub Actions workflow when a cloud resource
 *   request is approved (state changes to 3 - Work in Progress).
 */

(function executeRule(current, previous) {

    try {
        // ==========================================
        // Configuration - Set these as System Properties
        // Navigation: System Properties > All Properties
        // ==========================================
        var githubPAT = gs.getProperty('x_umm_cloud.github_pat', '');
        var githubOwner = gs.getProperty('x_umm_cloud.github_owner', 'your-org');
        var githubRepo = gs.getProperty('x_umm_cloud.github_repo', 'umm-cloud-provisioning');

        if (!githubPAT) {
            gs.error('GitHub PAT not configured. Set system property: x_umm_cloud.github_pat');
            current.work_notes = 'ERROR: GitHub integration not configured. Contact IT administrator.';
            current.update();
            return;
        }

        // ==========================================
        // Get Variables from Request Item
        // ==========================================
        var variables = getRequestVariables(current.sys_id);

        gs.info('Processing cloud request: ' + current.number +
                ' | Type: ' + variables.resource_type +
                ' | Name: ' + variables.resource_name);

        // ==========================================
        // Build Payload for GitHub
        // ==========================================
        var payload = {
            event_type: 'provision-azure-resource',
            client_payload: {
                ticket_number: current.number.toString(),
                resource_type: variables.resource_type || '',
                resource_name: variables.resource_name || '',
                environment: variables.environment || 'dev',
                cost_center: variables.cost_center || '',
                requested_by: getRequesterEmail(current),
                // VM specific
                vm_size: variables.vm_size || 'Standard_D2s_v3',
                os_type: variables.os_type || 'ubuntu',
                // Storage specific
                storage_tier: variables.storage_tier || 'Standard',
                replication: variables.replication || 'LRS',
                // Databricks specific
                pricing_tier: variables.pricing_tier || 'standard',
                data_classification: variables.data_classification || 'internal'
            }
        };

        // ==========================================
        // Send Request to GitHub
        // ==========================================
        var endpoint = 'https://api.github.com/repos/' + githubOwner + '/' + githubRepo + '/dispatches';

        var request = new sn_ws.RESTMessageV2();
        request.setEndpoint(endpoint);
        request.setHttpMethod('POST');

        // Headers
        request.setRequestHeader('Accept', 'application/vnd.github.v3+json');
        request.setRequestHeader('Authorization', 'token ' + githubPAT);
        request.setRequestHeader('Content-Type', 'application/json');
        request.setRequestHeader('User-Agent', 'ServiceNow-UMM-CloudCatalog');

        // Body
        request.setRequestBody(JSON.stringify(payload));

        // Execute
        var response = request.execute();
        var httpStatus = response.getStatusCode();
        var responseBody = response.getBody();

        // ==========================================
        // Handle Response
        // ==========================================
        if (httpStatus == 204 || httpStatus == 200) {
            // Success - GitHub returns 204 No Content for dispatches
            current.work_notes = 'GitHub Actions workflow triggered successfully!\n\n' +
                'Resource Type: ' + variables.resource_type + '\n' +
                'Resource Name: ' + variables.resource_name + '\n' +
                'Environment: ' + variables.environment + '\n\n' +
                'Provisioning is in progress. You will be notified when complete.';

            gs.info('GitHub webhook success for ' + current.number + '. Status: ' + httpStatus);

        } else if (httpStatus == 401) {
            // Unauthorized
            current.work_notes = 'ERROR: GitHub authentication failed. Contact IT administrator.\n' +
                'Status: ' + httpStatus;
            gs.error('GitHub 401 Unauthorized for ' + current.number + '. Check PAT token.');

        } else if (httpStatus == 404) {
            // Not found - wrong repo/owner
            current.work_notes = 'ERROR: GitHub repository not found. Contact IT administrator.\n' +
                'Status: ' + httpStatus;
            gs.error('GitHub 404 Not Found for ' + current.number + '. Check owner/repo settings.');

        } else {
            // Other error
            current.work_notes = 'ERROR: Failed to trigger provisioning.\n' +
                'Status: ' + httpStatus + '\n' +
                'Response: ' + responseBody;
            gs.error('GitHub webhook failed for ' + current.number +
                     '. Status: ' + httpStatus + '. Body: ' + responseBody);
        }

        current.update();

    } catch (ex) {
        gs.error('Exception in GitHub trigger for ' + current.number + ': ' + ex.message);
        current.work_notes = 'ERROR: Exception during provisioning trigger.\n' + ex.message;
        current.update();
    }

    // ==========================================
    // Helper Functions
    // ==========================================

    /**
     * Get all variables from the request item
     */
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

    /**
     * Get the requester's email address
     */
    function getRequesterEmail(ritm) {
        try {
            if (ritm.request && ritm.request.requested_for) {
                var email = ritm.request.requested_for.email;
                if (email) {
                    return email.toString();
                }
            }
        } catch (e) {
            gs.warn('Could not get requester email: ' + e.message);
        }
        return 'unknown@umich.edu';
    }

})(current, previous);
