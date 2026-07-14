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
            throw new ncMcp_Exception(
                'Field "namedCredential" is required. Call the listCredentials tool to list available credentials.'
            );
        }
        ncMcp_Config config = ncMcp_Config.forName(namedCredential);
        ncMcp_AuthenticationGuardrail.Status status = ncMcp_AuthenticationGuardrail.getStatus(namedCredential);
        if (!status.isAuthenticated) {
            throw new ncMcp_Exception(
                ncMcp_AuthenticationGuardrail.notAuthenticatedMessage(namedCredential) +
                    ' Call the listCredentials tool to check credential status.'
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
