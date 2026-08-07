/**
* @description It is to establish unified callout approach.
* GET is a default method.
* It can be used to obtain:
* 1. Raw HttpResponse
* 2. Map<String,Object> response
* 3. Response of concrete type
* @example
CalloutBuilder cb = new CalloutBuilder('callout:MyNc')
    .withMethod('POST')
    .withEndpoint('/v1/data')
    .withBody(myPayload)
    .withHeader('Attribute', 'value')
    .withHeader('Attribute2', 'value2')
    .withTimeout(30000)
    .withSuccessType(MyType.class);

MyType response = (MyType)cb.getTypedResponseBody();
* @team Laserburst
*/
public virtual with sharing class CalloutBuilder {
    @TestVisible
    private static final Map<CalloutBuilder, HttpCalloutMock> BUILDER_TO_MOCK_OVERRIDE = new Map<CalloutBuilder, HttpCalloutMock>();

    private String ncOrBaseUrl;
    private String endpoint;
    private String method = 'GET';
    private Object body;

    private System.Type successType;
    private Integer timeout; // 120000 is the max timeout
    private Map<String, String> headersMap = new Map<String, String>();
    private Boolean hasBlobBody = false;
    private Map<String, String> queryParameters = new Map<String, String>();

    private HttpRequest request;
    private HttpResponse response;
    private HttpCalloutMock mock;
    private Boolean suppressApexObjectNulls = false;

    private CalloutRetrier retrier;
    private Integer maxRetries = 1;
    private Integer attempt = 0;

    private List<CalloutGuardrail> guardrails = new List<CalloutGuardrail>();
    private Boolean enforcingGuardrails = false;

    private List<CalloutResponseSanitizer> responseSanitizers = new List<CalloutResponseSanitizer>();
    private Boolean sanitizingResponse = false;

    // CalloutErrorResponse implementation
    private System.Type errorResponseImplType;
    private CalloutErrorResponse error;
    private Boolean bypassResponseValidation = false;
    private Boolean debugMode = false;

    public CalloutBuilder(String ncOrBaseUrl) {
        this.ncOrBaseUrl = ncOrBaseUrl;
    }

    // Optional setters

    /**
     * @description withEndpoint sets the right part of the URL,
     * but not parameters.
     * It knows that there is one redundant slash in the URL like this:
     * https://example.com//test, so the request will be sent to
     * https://example.com/test
     * It won't help when a redundant slash comes from Named Credential.
     * For the same reason, it won't add any slash to not harm.
     */
    public virtual CalloutBuilder withEndpoint(String endpoint) {
        if (endpoint?.startsWith('/') && this.ncOrBaseUrl?.endsWith('/')) {
            endpoint = endpoint.removeStart('/');
        }
        this.endpoint = endpoint;
        return this;
    }

    public virtual CalloutBuilder withMethod(String method) {
        this.method = method;
        return this;
    }

    /**
    * @description withMockIfTest sets mock for test context
    * It has no effect on code out of test context, so it may be used not only in test classes
    * @param  mock may be any HttpCalloutMock implementation
    */
    public CalloutBuilder withMockIfTest(HttpCalloutMock mock) {
        this.mock = mock;
        return this;
    }

    public CalloutBuilder withHeader(String key, String value) {
        this.headersMap.put(key, value);
        return this;
    }

    public CalloutBuilder withHeaders(Map<String, String> headers) {
        this.headersMap.putAll(headers);
        return this;
    }

    public virtual CalloutBuilder withBody(Object body) {
        this.body = body;
        return this;
    }

    public virtual CalloutBuilder withBlobBody(Object body) {
        this.hasBlobBody = true;
        this.body = body; // not withBody(): it is virtual and must not be re-entered by a subclass
        return this;
    }

    public CalloutBuilder withSuccessType(System.Type successType) {
        this.successType = successType;
        return this;
    }

    public CalloutBuilder withRetrier(CalloutRetrier retrier) {
        this.retrier = retrier;
        return this;
    }

    /**
     * @description withGuardrails adds checks running before the callout;
     * a guardrail blocks it by throwing
     * @param guardrails appended to any already attached
     */
    public CalloutBuilder withGuardrails(List<CalloutGuardrail> guardrails) {
        this.guardrails.addAll(guardrails);
        return this;
    }

    @SuppressWarnings('PMD.ApexDoc')
    public CalloutBuilder withGuardrail(CalloutGuardrail guardrail) {
        this.guardrails.add(guardrail);
        return this;
    }

    /**
     * @description withResponseSanitizers adds transformations applied to a
     * validated response before the caller sees it;
     * a sanitizer blocks the response by throwing
     * @param sanitizers appended to any already attached
     */
    public CalloutBuilder withResponseSanitizers(List<CalloutResponseSanitizer> sanitizers) {
        this.responseSanitizers.addAll(sanitizers);
        return this;
    }

    @SuppressWarnings('PMD.ApexDoc')
    public CalloutBuilder withResponseSanitizer(CalloutResponseSanitizer sanitizer) {
        this.responseSanitizers.add(sanitizer);
        return this;
    }

    public CalloutBuilder withMaxRetries(Integer maxRetries) {
        this.maxRetries = maxRetries;
        return this;
    }

    public CalloutBuilder withBypassResponseValidation(Boolean bypassResponseValidation) {
        this.bypassResponseValidation = bypassResponseValidation;
        return this;
    }

    public CalloutBuilder withDebugMode(Boolean debugMode) {
        this.debugMode = debugMode;
        return this;
    }

    /**
     * @description withFile creates multipart request
     * with blob body and Content-Type header
     * @param  formBuilder  fully configured CalloutHexFormBuilder including file content
     * @return  this
     */
    public CalloutBuilder withFile(CalloutHexFormBuilder formBuilder) {
        this.withHeader('Content-Type', CalloutHexFormBuilder.getContentType());
        return this.withBlobBody(formBuilder.getFormAsBlob());
    }

    /**
     * @description withSuppressApexObjectNulls affects request body serialization
     * @param  suppressApexObjectNulls if true, null values are omitted from serialization (default: false)
     */
    public CalloutBuilder withSuppressApexObjectNulls(Boolean suppressApexObjectNulls) {
        this.suppressApexObjectNulls = suppressApexObjectNulls;
        return this;
    }

    /**
     * @description withQueryParameter sets query parameter for the callout
     * Note: If the method is GET, query parameters are added to the URL.
     * If the method is not GET, query parameters are added to the body
     * (if the body is null).
     */
    public CalloutBuilder withQueryParameter(String key, String value) {
        if (String.isBlank(key)) {
            throw new CalloutBuilderException('Query parameter key must be provided');
        }
        this.queryParameters.put(key, value);
        return this;
    }

    public CalloutBuilder withQueryParameters(Map<String, String> queryParameters) {
        for (String key : queryParameters.keySet()) {
            this.withQueryParameter(key, queryParameters.get(key));
        }
        return this;
    }

    /**
    * @description It allows to extract error message from any error object
    * @param  errorType class must implement CalloutErrorResponse interface
    */
    public CalloutBuilder withErrorType(System.Type errorType) {
        this.validateErrorType(errorType);
        this.errorResponseImplType = errorType;
        return this;
    }

    public CalloutBuilder withTimeout(Integer timeout) {
        this.timeout = timeout;
        return this;
    }

    // execution variants

    /**
     * @description It makes a callout, validates response,
     * retries if needed and returns HttpResponse as is
     * @return plain HttpResponse
     */
    public virtual HttpResponse getHttpResponse() {
        this.validateBeforeCall();
        this.constructRequest();
        this.setMockIfTest();
        this.debugRequest();

        do {
            this.attempt++;
            this.response = new Http().send(this.request);
        } while (this.canRetry() && this.retrier?.shouldRetry(this.response));
        this.attempt = 0;

        this.validateResponse();
        this.sanitizeResponse();
        return this.response;
    }

    /**
    * @description It makes a callout, validates response
    * and converts its body JSON into Map<String, Object>
    * @return response body as Map<String, Object>
    */
    public Map<String, Object> getResponseBodyMap() {
        this.getHttpResponse();
        return (Map<String, Object>) JSON.deserializeUntyped(this.response.getBody());
    }

    /**
     * @description It makes a callout, validates response
     * and converts its body into an object specified in .withSuccessType() method
     * @return success type instance
     */
    public Object getTypedResponseBody() {
        if (this.successType == null) {
            throw new CalloutBuilderException('getTypedResponseBody expects this.successType to be set');
        }
        this.getHttpResponse();
        return JSON.deserialize(this.response.getBody(), this.successType);
    }

    /**
    * @description It makes a callout, validates response
    * @return response body as Blob
    */
    public Blob getResponseBodyAsBlob() {
        this.getHttpResponse();
        return this.response.getBodyAsBlob();
    }

    /**
     * @description constructFullEndpoint returns full URL for the callout
     * @return base URL + endpoint + query parameters (if any and if GET method)
     */
    public String constructFullEndpoint() {
        String fullEndpoint = String.isNotBlank(this.endpoint) ? this.ncOrBaseUrl + this.endpoint : this.ncOrBaseUrl;

        if (this.method == 'GET' && !this.queryParameters.isEmpty()) {
            String separator = fullEndpoint?.contains('?') == true ? '&' : '?';
            fullEndpoint += separator + this.getEncodedQueryParameters();
        }

        return fullEndpoint;
    }

    @SuppressWarnings('PMD.ApexDoc')
    public String getMethod() {
        return this.method;
    }

    @SuppressWarnings('PMD.ApexDoc')
    public String getNcOrBaseUrl() {
        return this.ncOrBaseUrl;
    }

    @SuppressWarnings('PMD.ApexDoc')
    public String getEndpoint() {
        return this.endpoint;
    }

    @SuppressWarnings('PMD.ApexDoc')
    public Map<String, String> getHeaders() {
        return new Map<String, String>(this.headersMap);
    }

    @SuppressWarnings('PMD.ApexDoc')
    public Map<String, String> getQueryParameters() {
        return new Map<String, String>(this.queryParameters);
    }

    @SuppressWarnings('PMD.ApexDoc')
    public CalloutErrorResponse getError() {
        return this.error;
    }

    // implementation details

    /**
    * @description it checks if required fields are set.
    */
    private void validateBeforeCall() {
        // not in sanitizeResponse(): re-entry must be rejected before the request is sent
        if (this.sanitizingResponse) {
            throw new CalloutBuilderException('A response sanitizer must not execute the callout it is sanitizing.');
        }
        if (String.isBlank(this.ncOrBaseUrl)) {
            throw new CalloutBuilderException('NC or base URL must be provided');
        }
        if (String.isBlank(this.method)) {
            throw new CalloutBuilderException('HTTP method must be provided');
        }
        this.enforceGuardrails();
    }

    private void enforceGuardrails() {
        if (this.enforcingGuardrails) {
            throw new CalloutBuilderException('A guardrail must not execute the callout it is guarding.');
        }
        this.enforcingGuardrails = true;
        try {
            for (CalloutGuardrail guardrail : this.guardrails) {
                guardrail.enforce(this);
            }
        } finally {
            this.enforcingGuardrails = false;
        }
    }

    private void sanitizeResponse() {
        this.sanitizingResponse = true;
        try {
            for (CalloutResponseSanitizer sanitizer : this.responseSanitizers) {
                sanitizer.sanitize(this.response);
            }
        } finally {
            this.sanitizingResponse = false;
        }
    }

    private void constructRequest() {
        this.request = new HttpRequest();
        this.request.setEndpoint(this.constructFullEndpoint());
        this.request.setMethod(this.method);
        if (this.timeout != null) {
            this.request.setTimeout(this.timeout);
        }
        this.attachBody();
        this.attachHeaders();
    }

    private static final String ENCODING = 'UTF-8';
    private String getEncodedQueryParameters() {
        if (this.queryParameters.isEmpty()) {
            return '';
        }
        List<String> encodedPairs = new List<String>();
        for (String key : this.queryParameters.keySet()) {
            String encodedKey = EncodingUtil.urlEncode(key, ENCODING);
            String encodedValue = EncodingUtil.urlEncode(this.queryParameters.get(key), ENCODING);
            encodedPairs.add(encodedKey + '=' + encodedValue);
        }
        return String.join(encodedPairs, '&');
    }

    /**
     * @description attachBody sets body of the request, in precedence order:
     * 1. blob
     * 2. JSON (a body always wins over query parameters)
     * 3. query parameters (if any and if method is not GET)
     */
    private void attachBody() {
        if (this.hasBlobBody && this.body != null) {
            this.request.setBodyAsBlob((Blob) this.body);
        } else if (this.body != null) {
            this.request.setBody(JSON.serialize(this.body, this.suppressApexObjectNulls));
        } else if (!this.queryParameters.isEmpty() && this.method != 'GET') {
            this.request.setBody(this.getEncodedQueryParameters());
        }
    }

    private void attachHeaders() {
        for (String header : headersMap.keySet()) {
            this.request.setHeader(header, headersMap.get(header));
        }
    }

    private void setMockIfTest() {
        if (!Test.isRunningTest()) return;
        HttpCalloutMock effectiveMock = this.getEffectiveMock();
        if (effectiveMock != null) {
            Test.setMock(HttpCalloutMock.class, effectiveMock);
        }
    }

    private HttpCalloutMock getEffectiveMock() {
        for (CalloutBuilder builder : BUILDER_TO_MOCK_OVERRIDE.keySet()) {
            if (hasSameScope(builder)) {
                return BUILDER_TO_MOCK_OVERRIDE.get(builder);
            }
        }
        return this.mock;
    }

    private Boolean hasSameScope(CalloutBuilder builder) {
        return builder.constructFullEndpoint() == this.constructFullEndpoint() && builder.getMethod() == this.getMethod();
    }

    private void validateErrorType(System.Type errorType) {
        if (errorType == null) {
            throw new CalloutBuilderException('Callout error cannot be set to null');
        }
        try {
            CalloutErrorResponse errorImpl = (CalloutErrorResponse) errorType.newInstance();
        } catch (Exception e) {
            throw new CalloutBuilderException('Callout error must implement CalloutErrorResponse');
        }
    }

    private void validateResponse() {
        this.debugResponse();
        if (this.bypassResponseValidation) {
            return;
        }
        if (this.response.getStatusCode() >= 400) {
            CalloutBuilderException ex = new CalloutBuilderException(this.response, this.errorResponseImplType);
            this.error = ex.getParsedError();
            throw ex;
        }
    }

    private Boolean canRetry() {
        return this.retrier != null && this.maxRetries >= this.attempt;
    }

    private void debugRequest() {
        if (!this.debugMode) {
            return;
        }
        debug('-- Request debug start --');
        debug('Request endpoint: ' + this.request.getEndpoint());
        debug('Request method: ' + this.request.getMethod());
        if (this.isDebugableBody(this.request.getHeader('Content-Type'))) {
            debug('Request body: \n' + this.request.getBody());
        } else {
            debug('Skip verbose request body debugging. Content-Type: ' + this.request.getHeader('Content-Type'));
        }

        debug('Request headers size: ' + this.headersMap.size());
        for (String header : this.headersMap.keySet()) {
            debug('Request header: ' + header + ': ' + this.headersMap.get(header));
        }
        debug('-- Request debug end --');
    }

    private void debugResponse() {
        if (!this.debugMode) {
            return;
        }
        debug('-- Response debug start --');
        debug('Response status code: ' + this.response.getStatusCode());
        debug('Response status: ' + this.response.getStatus());

        if (this.isDebugableBody(this.response.getHeader('Content-Type'))) {
            debug('Response body: \n' + this.response.getBody());
        } else {
            debug('Skip verbose response body debugging. Content-Type: ' + this.response.getHeader('Content-Type'));
        }

        List<String> responseHeaderKeys = this.response.getHeaderKeys();
        debug('Response headers size: ' + responseHeaderKeys.size());
        for (String header : responseHeaderKeys) {
            debug('Response header: ' + header + ': ' + this.response.getHeader(header));
        }
        debug('-- Response debug end --');
    }

    /**
     * @description Set of content types that should be debugged.
     * There is no point in debugging binary or cryptic content types.
     */
    private final Set<String> debugableContentTypes = new Set<String>{
        'application/json',
        'application/xml',
        'text/xml',
        'text/plain',
        'text/html'
    };

    private Boolean isDebugableBody(String contentType) {
        if (contentType == null) {
            return true;
        }
        if (debugableContentTypes.contains(contentType.toLowerCase())) {
            return true;
        }
        for (String debugableContentType : debugableContentTypes) {
            if (contentType.toLowerCase().contains(debugableContentType)) {
                return true;
            }
        }
        return false;
    }

    private void debug(String log) {
        log = 'CalloutBuilder: ' + log;
        System.debug(LoggingLevel.DEBUG, log);
    }

    @SuppressWarnings('PMD.ApexDoc')
    public class CalloutBuilderException extends Exception {
        // null when the exception is not caused by an HTTP response
        public final Integer code;
        public final String status;
        private CalloutErrorResponse error;

        public CalloutBuilderException(HttpResponse response, System.Type errorType) {
            this.code = response.getStatusCode();
            this.status = response.getStatus();
            this.setMessage(this.extractMessage(response, errorType));
        }

        private CalloutErrorResponse getParsedError() {
            return this.error;
        }

        /**
         * @description message is the error body by default;
         * a blank body falls back to the HTTP status text,
         * a parsed error object overrides it when getErrorMessage() is non-blank
         */
        private String extractMessage(HttpResponse response, System.Type errorType) {
            String body = response.getBody();
            if (String.isBlank(body)) {
                return response.getStatus();
            }
            if (errorType != null) {
                try {
                    this.error = (CalloutErrorResponse) JSON.deserialize(body, errorType);
                    String errorMessage = this.error.getErrorMessage();
                    if (String.isNotBlank(errorMessage)) {
                        return errorMessage;
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.DEBUG, 'CalloutBuilder: Could not get error message: ' + e.getMessage());
                }
            }
            return body;
        }
    }
}