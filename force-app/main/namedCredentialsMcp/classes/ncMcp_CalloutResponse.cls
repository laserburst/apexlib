/**
 * @description ncMcp_CalloutResponse is what an agent gets back from a callout, after the policies' sanitizers: the
 * output of the sendRequest tool
 * @team Laserburst
 */
global with sharing class ncMcp_CalloutResponse {
    @InvocableVariable(description='The HTTP status code, for every status.')
    global Integer statusCode;

    @InvocableVariable(description='The HTTP status text, or "Withheld by policy" when the error body is withheld.')
    global String status;

    @InvocableVariable(
        description='Response headers as a JSON object with lower-case names. A header that may carry a credential, such as Set-Cookie or a token, is empty unless a policy grants it, as is a header a policy blanks.'
    )
    global String headers;

    @InvocableVariable(description='The response body as text, after the policies\' sanitizers.')
    global String body;

    // a static factory, not a constructor: invocable action parameters need the implicit no-argument constructor
    public static ncMcp_CalloutResponse forResponse(HttpResponse response) {
        ncMcp_CalloutResponse result = new ncMcp_CalloutResponse();
        result.statusCode = response.getStatusCode();
        result.status = response.getStatus();
        result.headers = JSON.serialize(toHeaderValues(response));
        result.body = response.getBody();
        return result;
    }

    // a sanitizer's setHeader() under another case than the server sent adds a second key, so a blank one wins
    private static Map<String, String> toHeaderValues(HttpResponse response) {
        Map<String, String> valueByName = new Map<String, String>();
        for (String key : response.getHeaderKeys()) {
            if (key == null) {
                continue;
            }
            String name = key.toLowerCase();
            String value = response.getHeader(key) ?? '';
            if (!valueByName.containsKey(name) || String.isEmpty(value)) {
                valueByName.put(name, value);
            }
        }
        return valueByName;
    }
}