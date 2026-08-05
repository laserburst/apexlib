/**
* @description MCP tool "sendRequest": sends a guarded HTTP request through a
* Named Credential. Exposed as an invocable action so it is also usable from
* Flows and Agentforce. Parses the string-typed tool inputs and drives
* GuardedCalloutBuilder, which enforces the guardrail chain and performs
* the callout.
* @team Laserburst
*/
global with sharing class ncMcp_SendRequestTool {
    @InvocableMethod(
        label='Send HTTP Request via Named Credential'
        description='Sends an HTTP request to an external API through one of the org\'s Named Credentials. Salesforce injects authentication; credentials and tokens are never exposed. Only credentials returned by the listCredentials tool can be called; the describe tool shows how to call each one. Fails with an error on guardrail violations and on HTTP 4xx/5xx responses (the error message contains the HTTP status and response body).'
        callout=true
        category='Named Credentials MCP'
    )
    global static List<ncMcp_HttpResponseFacade> sendRequest(List<Request> requests) {
        List<ncMcp_HttpResponseFacade> responses = new List<ncMcp_HttpResponseFacade>();
        for (Request request : requests) {
            try {
                responses.add(new ncMcp_HttpResponseFacade(toGuardedBuilder(request).getHttpResponse()));
            } catch (CalloutBuilder.CalloutBuilderException e) {
                if (e.code == null) {
                    throw e;
                }
                // The exception message is only the response body; prepend the
                // status so the tool keeps its promise to report both
                throw new GuardedCalloutException('HTTP ' + e.code + ' ' + e.status + ': ' + e.getMessage());
            }
        }
        return responses;
    }

    private static GuardedCalloutBuilder toGuardedBuilder(Request input) {
        if (String.isBlank(input.namedCredential)) {
            throw new GuardedCalloutException(
                'Field "namedCredential" is required. Call the listCredentials tool to list available credentials.'
            );
        }
        if (String.isBlank(input.path)) {
            throw new GuardedCalloutException('Field "path" is required, e.g. "/v1/resource".');
        }
        // Assigned before chaining: the inherited setters return CalloutBuilder
        GuardedCalloutBuilder guarded = new GuardedCalloutBuilder(input.namedCredential);
        guarded
            .withEndpoint(input.path)
            .withMethod(input.method)
            .withHeaders(parseStringMap(input.headers, 'headers'))
            .withQueryParameters(parseStringMap(input.queryParameters, 'queryParameters'))
            .withTimeout(input.timeoutMilliseconds);
        if (String.isNotBlank(input.body)) {
            guarded.withBody(input.body);
        }
        return guarded;
    }

    private static Map<String, String> parseStringMap(String jsonObject, String fieldName) {
        Map<String, String> result = new Map<String, String>();
        if (String.isBlank(jsonObject)) {
            return result;
        }
        Map<String, Object> parsed;
        try {
            parsed = (Map<String, Object>) JSON.deserializeUntyped(jsonObject);
        } catch (Exception e) {
            throw new GuardedCalloutException(
                'Field "' + fieldName + '" must be a JSON object string, e.g. {"Header-Name":"value"}.'
            );
        }
        if (parsed == null) {
            return result; // the JSON literal null means "none provided"
        }
        for (String key : parsed.keySet()) {
            Object value = parsed.get(key);
            if (value != null) {
                // a null value means "not provided"; forwarding it would crash HttpRequest.setHeader
                result.put(key, String.valueOf(value));
            }
        }
        return result;
    }

    global class Request {
        global Request() {
        }

        @InvocableVariable(
            required=true
            description='DeveloperName of the Named Credential to call, exactly as returned by the listCredentials tool.'
        )
        global String namedCredential;

        @InvocableVariable(
            required=true
            description='URL path relative to the API base URL, starting with "/" (e.g. "/v1/models"). Do not include the protocol or domain. A query string is allowed here and is the way to put parameters in the URL of a non-GET request.'
        )
        global String path;

        @InvocableVariable(
            description='HTTP method: GET, POST, PUT, PATCH, or DELETE. Defaults to GET. Must be one of the allowedMethods returned by the describe tool for this API.'
        )
        global String method;

        @InvocableVariable(
            description='Raw request body string sent as-is (for JSON APIs, pass a serialized JSON object). Omit for requests without a body.'
        )
        global String body;

        @InvocableVariable(
            description='HTTP request headers as a JSON object string, e.g. {"Accept":"application/json"}. No header is set for you: when sending a body, set Content-Type explicitly, e.g. {"Content-Type":"application/json"}.'
        )
        global String headers;

        @InvocableVariable(
            description='URL query parameters as a JSON object string with string values, e.g. {"limit":"10","q":"name"}. Keys and values are URL-encoded automatically. They are appended to the path for GET requests; for other methods they are form-encoded into the request body, and only when "body" is omitted. To put them in the URL of a non-GET request, write the query string into "path" instead.'
        )
        global String queryParameters;

        @InvocableVariable(
            description='Request timeout in milliseconds. Omit to use the platform default of 10000. Values outside 1000-120000 are rejected by the platform and make the request fail.'
        )
        global Integer timeoutMilliseconds;
    }
}