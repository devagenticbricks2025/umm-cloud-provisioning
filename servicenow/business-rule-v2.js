/**
 * ServiceNow Business Rule: Trigger GitHub Actions - Research Computing
 * Version: 2.0 (Fixed for GitHub API 10 property limit)
 *
 * Table: sc_req_item (Requested Item)
 * When: after
 * Update: true
 * Advanced: true
 *
 * Filter Conditions: State is Work in Progress
 */

(function executeRule(current, previous) {

    var config = {
        githubPAT: gs.getProperty('x_umm_cloud.github_pat', ''),
        githubOwner: gs.getProperty('x_umm_cloud.github_owner', 'your-org'),
        githubRepo: gs.getProperty('x_umm_cloud.github_repo', 'umm-cloud-provisioning'),
        eventType: 'provision-research-environment'
    };

    if (!config.githubPAT) {
        current.work_notes = 'ERROR: GitHub PAT not configured. Set system property: x_umm_cloud.github_pat';
        current.update();
        return;
    }

    try {
        var catalogItemName = current.cat_item.name.toString();
        var isPhiRequest = catalogItemName.indexOf('PHI') > -1 || catalogItemName.indexOf('AVE') > -1;
        var requestType = isPhiRequest ? 'phi_ave' : 'standard_research';

        gs.info('Processing ' + requestType + ' request: ' + current.number);

        var variables = getRequestVariables(current.sys_id);
        var payload = buildPayload(requestType, variables, current);
        var result = triggerGitHubWorkflow(config, payload);

        if (result.success) {
            var msg = 'Provisioning workflow triggered successfully!\n\n';
            msg += 'Request Type: ' + requestType + '\n';
            msg += 'Project: ' + (variables.project_name || 'N/A') + '\n';
            msg += 'Ticket: ' + current.number + '\n\n';
            msg += 'Check GitHub Actions for progress.';
            current.work_notes = msg;
        } else {
            current.work_notes = 'ERROR: Failed to trigger provisioning.\n' + result.error;
            gs.error('GitHub trigger failed for ' + current.number + ': ' + result.error);
        }
        current.update();

    } catch (ex) {
        gs.error('[Research Computing] Exception: ' + ex.message);
        current.work_notes = 'ERROR: Exception during provisioning trigger.\n' + ex.message;
        current.update();
    }

    function getRequestVariables(ritmSysId) {
        var vars = {};
        var mtom = new GlideRecord('sc_item_option_mtom');
        mtom.addQuery('request_item', ritmSysId);
        mtom.query();
        while (mtom.next()) {
            var option = mtom.sc_item_option;
            if (option && option.item_option_new && option.item_option_new.name) {
                vars[option.item_option_new.name.toString()] = option.value ? option.value.toString() : '';
            }
        }
        return vars;
    }

    function buildPayload(requestType, variables, ritm) {
        // GitHub API limits client_payload to 10 properties MAX
        var payload = {
            event_type: config.eventType,
            client_payload: {
                ticket_number: ritm.number.toString(),
                request_type: requestType,
                project_name: variables.project_name || 'research-project',
                principal_investigator: variables.principal_investigator || '',
                department: variables.department || 'research',
                cost_center: variables.grant_code || variables.funding_source || 'default'
            }
        };

        if (requestType === 'standard_research') {
            // Standard research: 8 properties total
            payload.client_payload.workload_types = getWorkloadTypes(variables);
            payload.client_payload.environment = 'dev';
        } else {
            // PHI/AVE: 9 properties total
            payload.client_payload.irb_number = variables.irb_number || '';
            payload.client_payload.access_method = variables.access_method || 'both';
            payload.client_payload.environment = 'prod';
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

})(current, previous);
