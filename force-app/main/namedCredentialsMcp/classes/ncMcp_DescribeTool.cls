/**
* @description MCP tool "describe": returns how to use one Named Credential API
* (purpose, docs, base URL, allowed methods and endpoint patterns). Discovery
* is the listCredentials tool's job; this tool details a single credential and
* fails with an actionable error when it is unknown or not authenticated.
* Exposed as an invocable action so it is also usable from Flows and Agentforce.
* @team Laserburst
*/
global with sharing class ncMcp_DescribeTool {
    @InvocableMethod(
        label='Describe a Named Credential API'
        description='Returns how to use one Named Credential API: its purpose, base URL, reference documentation URL, allowed HTTP methods, and allowed endpoint path patterns. Call listCredentials first to discover credentials, and call this before sendRequest. Fails with an error when the credential is unknown or not authenticated.'
        callout=true
        category='Named Credentials MCP'
    )
    global static List<ncMcp_DescribeResult> describe(List<Request> requests) {
        List<ncMcp_DescribeResult> results = new List<ncMcp_DescribeResult>();
        for (Request request : requests) {
            results.add(new ncMcp_DescribeResult(JSON.serialize(buildApi(request?.namedCredential))));
        }
        return results;
    }

    private static ncMcp_DescribeResult.Api buildApi(String namedCredential) {
        if (String.isBlank(namedCredential)) {
            throw new GuardedCalloutException(
                'Field "namedCredential" is required. Call the listCredentials tool to list available credentials.'
            );
        }
        GuardedCalloutConfig config = loadConfig(namedCredential);
        CalloutAuthenticationGuardrail.Status status = CalloutAuthenticationGuardrail.getStatus(namedCredential);
        if (!status.isAuthenticated) {
            throw new GuardedCalloutException(
                CalloutAuthenticationGuardrail.notAuthenticatedMessage(namedCredential)
                + ' Call the listCredentials tool to check credential status.'
            );
        }

        ncMcp_DescribeResult.Api api = new ncMcp_DescribeResult.Api();
        api.name = namedCredential;
        api.description = config.description;
        api.apiDocsUrl = config.apiDocsUrl;
        api.baseUrl = status.baseUrl;
        api.allowedMethods = config.allowedMethods;
        api.allowedEndpointPatterns = config.allowedEndpointPatterns;
        return api;
    }

    // GuardedCalloutConfig.forName throws module-neutral messages; re-add the MCP
    // discovery hint when the credential simply has no active configuration.
    private static GuardedCalloutConfig loadConfig(String namedCredential) {
        try {
            return GuardedCalloutConfig.forName(namedCredential);
        } catch (GuardedCalloutException e) {
            if (e.getMessage().contains('No active configuration')) {
                throw new GuardedCalloutException(
                    e.getMessage() + ' Call the listCredentials tool to list available credentials.'
                );
            }
            throw e;
        }
    }

    global class Request {
        global Request() {
        }

        @InvocableVariable(
            required=true
            description='DeveloperName of the Named Credential to describe, exactly as returned by the listCredentials tool.'
        )
        global String namedCredential;
    }
}