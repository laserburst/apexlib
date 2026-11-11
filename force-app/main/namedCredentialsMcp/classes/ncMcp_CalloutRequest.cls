/**
 * @description ncMcp_CalloutRequest is one callout an agent asks for through an exposed Named Credential: the input
 * of the sendRequest tool. Every field is untrusted, and the policies decide what may be sent and what comes back.
 * @team Laserburst
 */
global with sharing class ncMcp_CalloutRequest {
    private static final Integer MAX_TIMEOUT = 120000;
    @TestVisible
    private static final String SENT_BUT_FAILED =
        'The request was sent, but its response was blocked or could not be read. A write may have happened.';

    @InvocableVariable(required=true description='The name of an API, exactly as listCredentials returns it.')
    global String namedCredential;

    @InvocableVariable(description='GET, POST, PUT, PATCH, DELETE or HEAD. GET when empty.')
    global String method;

    @InvocableVariable(
        description='The concrete path after the API\'s base URL, such as /items/5: replace each {name} from describe with its value. The API\'s root when empty.'
    )
    global String path;

    @InvocableVariable(description='Request headers as a JSON object, such as {"Accept":"application/json"}.')
    global String headers;

    @InvocableVariable(
        description='Query parameters as a JSON object, such as {"limit":"10"}. They always go in the URL, for every method, and are encoded for you.'
    )
    global String queryParameters;

    @InvocableVariable(
        description='The request body. With a JSON Content-Type, or none, it must be JSON and is sent re-serialized; with any other Content-Type it is sent as is. GET and HEAD can\'t have one.'
    )
    global String body;

    @InvocableVariable(description='Timeout in milliseconds, from 1 to 120000. 10000 when empty.')
    global Integer timeoutMilliseconds;

    /**
     * @description sendAll sends the requests in order and stops at the first one that throws
     */
    public static List<ncMcp_CalloutResponse> sendAll(List<ncMcp_CalloutRequest> requests) {
        List<ncMcp_CalloutResponse> responses = new List<ncMcp_CalloutResponse>();
        for (ncMcp_CalloutRequest request : requests) {
            responses.add(request.send());
        }
        return responses;
    }

    /**
     * @description send returns every status as a response; an error whose message may carry response content
     * becomes SENT_BUT_FAILED
     */
    public ncMcp_CalloutResponse send() {
        ncMcp_PolicyCatalog catalog = ncMcp_PolicyCatalog.getInstance();
        SecureCalloutBuilder callout =
            new SecureCalloutBuilder(this.toCalloutBuilder(catalog.toScope(this.namedCredential))).withPolicies(
                catalog.getPolicies()
            );
        try {
            return ncMcp_CalloutResponse.forResponse(callout.getHttpResponse());
        } catch (Exception e) {
            if (this.isSafeToShow(e)) {
                throw e;
            }
            throw new ncMcp_ToolException(SENT_BUT_FAILED);
        }
    }

    // a policy block or an error raised before sending names no response content, and the platform's own message
    // names none either
    private Boolean isSafeToShow(Exception e) {
        return e instanceof CalloutGuardrailException
            || (
                e instanceof CalloutBuilder.CalloutBuilderException
                && ((CalloutBuilder.CalloutBuilderException) e).code == null
            )
            || e instanceof System.CalloutException;
    }

    private CalloutBuilder toCalloutBuilder(String scope) {
        CalloutBuilder callout =
            new CalloutBuilder(scope)
                .withMethod(this.toMethod())
                .withEndpoint(this.toEndpoint())
                .withHeaders(this.toStringMap(this.headers, 'headers'))
                .withBypassResponseValidation(true);
        if (String.isNotEmpty(this.body)) {
            callout.withBody(this.toBodyValue(callout));
        }
        if (this.timeoutMilliseconds != null) {
            callout.withTimeout(this.toTimeout());
        }
        return callout;
    }

    private String toMethod() {
        if (String.isBlank(this.method)) {
            return 'GET';
        }
        return this.method.trim().toUpperCase();
    }

    // never withQueryParameters(): CB sends them as a form body for a non-GET request without a body
    private String toEndpoint() {
        String path = '';
        if (String.isNotBlank(this.path)) {
            path = this.path;
        }
        String query = new CalloutUrlEncodedForm(this.toStringMap(this.queryParameters, 'queryParameters')).toString();
        if (String.isEmpty(query)) {
            return path;
        }
        String separator = '?';
        if (path.contains('?')) {
            separator = '&';
        }
        return path + separator + query;
    }

    // CB JSON-serializes a String body under a JSON Content-Type, so a JSON body goes in parsed
    private Object toBodyValue(CalloutBuilder callout) {
        if (this.isBodyless(callout.getMethod())) {
            throw new ncMcp_ToolException('GET and HEAD requests can\'t have a body');
        }
        if (!CalloutBody.isJson(callout.getContentType())) {
            return this.body;
        }
        try {
            return JSON.deserializeUntyped(this.body);
        } catch (JSONException e) {
            throw new ncMcp_ToolException('Field "body" must be JSON when the Content-Type is JSON or not set');
        }
    }

    private Boolean isBodyless(String method) {
        return method == 'GET' || method == 'HEAD';
    }

    private Integer toTimeout() {
        if (!this.isTimeoutInRange()) {
            throw new ncMcp_ToolException('Field "timeoutMilliseconds" must be from 1 to 120000');
        }
        return this.timeoutMilliseconds;
    }

    private Boolean isTimeoutInRange() {
        return this.timeoutMilliseconds >= 1 && this.timeoutMilliseconds <= MAX_TIMEOUT;
    }

    private Map<String, String> toStringMap(String jsonObject, String fieldName) {
        Map<String, String> values = new Map<String, String>();
        if (String.isBlank(jsonObject)) {
            return values;
        }
        Map<String, Object> fields = this.toFields(jsonObject, fieldName);
        for (String name : fields.keySet()) {
            Object value = fields.get(name);
            if (this.isNested(value)) {
                throw new ncMcp_ToolException('Field "' + fieldName + '" must have text, number or boolean values');
            }
            if (value != null) {
                values.put(name, String.valueOf(value));
            }
        }
        return values;
    }

    private Boolean isNested(Object value) {
        return value instanceof Map<String, Object> || value instanceof List<Object>;
    }

    // the JSON literal null counts as no fields
    private Map<String, Object> toFields(String jsonObject, String fieldName) {
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(jsonObject) ?? new Map<String, Object>();
        } catch (Exception e) {
            throw new ncMcp_ToolException('Field "' + fieldName + '" must be a JSON object, such as {"name":"value"}');
        }
    }
}