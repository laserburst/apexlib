/**
 * @description Facade over HttpResponse. It flattens the parts of a response an
 * agent needs into serializable fields, and is the output type of the sendRequest
 * MCP tool (so its @InvocableVariable descriptions become the tool's output schema).
 * @team Laserburst
 */
global with sharing class ncMcp_HttpResponseFacade {
    @InvocableVariable(
        description='HTTP status code of the response (2xx/3xx only; 4xx and 5xx raise an error instead of returning).'
    )
    global Integer statusCode;

    @InvocableVariable(description='HTTP status text, e.g. "OK".')
    global String status;

    @InvocableVariable(description='Raw response body string. Parse as JSON when the API returns JSON.')
    global String body;

    @InvocableVariable(description='HTTP response headers as a JSON object string.')
    global String headers;

    global ncMcp_HttpResponseFacade() {
    }

    global ncMcp_HttpResponseFacade(HttpResponse response) {
        this.statusCode = response.getStatusCode();
        this.status = response.getStatus();
        this.body = response.getBody();
        this.headers = serializeHeaders(response);
    }

    private String serializeHeaders(HttpResponse response) {
        Map<String, String> headerMap = new Map<String, String>();
        for (String key : response.getHeaderKeys()) {
            headerMap.put(key, response.getHeader(key));
        }
        return JSON.serialize(headerMap);
    }
}
