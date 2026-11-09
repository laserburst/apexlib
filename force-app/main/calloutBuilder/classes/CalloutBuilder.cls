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
    private CalloutEndpoint endpoint = new CalloutEndpoint();
    private String method = 'GET';
    private Object body;

    private System.Type successType;
    private Integer timeout; // 120000 is the max timeout
    private String clientCertificateName;
    private Boolean compressed = false;
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

    private final CalloutResponseSanitizerChain responseSanitizers = new CalloutResponseSanitizerChain();
    private Boolean parsingResponseBody = false;
    private CalloutResponseParser customParser;

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
     * @description withEndpoint sets the URL part after the base URL, stored with exactly one
     * leading '/' unless blank or starting with '?'. It must not contain '#'; its path must not
     * contain '\' nor a '.' or '..' segment, also as %2e. Concatenated values are sent unencoded:
     * use {name} placeholders with withPathParameter().
     */
    public virtual CalloutBuilder withEndpoint(String endpoint) {
        this.endpoint.setTemplate(endpoint);
        return this;
    }

    /**
     * @description withPathParameter replaces every {name} in the endpoint with value
     * percent-encoded as one path segment; pass value unencoded.
     * Every placeholder needs a parameter and every parameter a placeholder.
     */
    public CalloutBuilder withPathParameter(String name, String value) {
        this.endpoint.putParameter(name, value);
        return this;
    }

    public CalloutBuilder withPathParameters(Map<String, String> pathParameters) {
        for (String name : pathParameters.keySet()) {
            this.withPathParameter(name, pathParameters.get(name));
        }
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
     * (if the body is null). A null value leaves the parameter out.
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

    /**
     * @description withResponseParser sets how getTypedResponseBody(), getResponseBodyMap() and the withErrorType()
     * error read the body; without one, an XML Content-Type selects CalloutXmlParser and any other CalloutJsonParser
     */
    public CalloutBuilder withResponseParser(CalloutResponseParser parser) {
        this.customParser = parser;
        return this;
    }

    public CalloutBuilder withTimeout(Integer timeout) {
        this.timeout = timeout;
        return this;
    }

    /**
     * @description withClientCertificate presents a client certificate for mutual TLS.
     * The certificate must exist in the org, also for a mocked callout in a test,
     * or the callout throws CalloutException before it is sent.
     * @param certificateName the certificate's Unique Name in Certificate and Key Management, not its label
     */
    public CalloutBuilder withClientCertificate(String certificateName) {
        this.clientCertificateName = certificateName;
        return this;
    }

    /**
     * @description withCompression sends the body gzip-compressed; the API must accept a compressed body
     */
    public CalloutBuilder withCompression(Boolean compressed) {
        this.compressed = compressed;
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
        if (this.debugMode) {
            CalloutDebug.log(this.request, this.headersMap);
        }

        do {
            this.attempt++;
            this.response = new Http().send(this.request);
        } while (this.canRetry() && this.retrier?.shouldRetry(this.response));
        this.attempt = 0;

        this.validateResponse();
        if (!this.parsingResponseBody) {
            this.responseSanitizers.sanitize(this.response);
        }
        return this.response;
    }

    /**
    * @description It makes a callout, validates response
    * and parses its body into Map<String, Object>
    * @return response body as Map<String, Object>
    */
    public Map<String, Object> getResponseBodyMap() {
        HttpResponse response = this.getRawHttpResponse();
        Map<String, Object> body = this.getParser(response).deserializeUntyped(response.getBody());
        this.responseSanitizers.sanitize(body);
        return body;
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
        HttpResponse response = this.getRawHttpResponse();
        Object body = this.getParser(response).deserialize(response.getBody(), this.successType);
        this.responseSanitizers.sanitize(body, this.successType);
        return body;
    }

    /**
     * @description It makes a callout, validates response
     * and parses its body as XML
     * @return response body as Dom.Document
     */
    public Dom.Document getXmlResponseBody() {
        HttpResponse response = this.getRawHttpResponse();
        Dom.Document body = CalloutXmlParser.load(response.getBody()); // not getBodyDocument(): it drops CDATA content
        this.responseSanitizers.sanitize(body);
        return body;
    }

    /**
    * @description It makes a callout, validates response
    * @return response body as Blob
    */
    public Blob getResponseBodyAsBlob() {
        return this.getHttpResponse().getBodyAsBlob();
    }

    /**
     * @description constructFullEndpoint returns full URL for the callout
     * @return base URL + endpoint + query parameters (if any and if GET method)
     */
    public String constructFullEndpoint() {
        String fullEndpoint = this.endpoint.joinTo(this.ncOrBaseUrl);
        if (this.method != 'GET') {
            return fullEndpoint;
        }
        String query = this.getEncodedQueryParameters();
        if (String.isNotEmpty(query)) {
            String separator = fullEndpoint?.contains('?') == true ? '&' : '?';
            fullEndpoint += separator + query;
        }
        return fullEndpoint;
    }

    public String getMethod() {
        return this.method;
    }

    public String getNcOrBaseUrl() {
        return this.ncOrBaseUrl;
    }

    /**
     * @description getEndpoint returns the endpoint as sent: placeholders resolved,
     * without the base URL and withQueryParameter() parameters
     */
    public String getEndpoint() {
        return this.endpoint.resolve();
    }

    public Map<String, String> getHeaders() {
        return new Map<String, String>(this.headersMap);
    }

    public Map<String, String> getQueryParameters() {
        return new Map<String, String>(this.queryParameters);
    }

    public Map<String, String> getPathParameters() {
        return this.endpoint.getParameters();
    }

    public CalloutErrorResponse getError() {
        return this.error;
    }

    // implementation details

    /**
    * @description it checks if required fields are set.
    */
    private void validateBeforeCall() {
        // not in the chain: re-entry must be rejected before the request is sent
        if (this.responseSanitizers.isRunning()) {
            throw new CalloutBuilderException('A response sanitizer must not execute the callout it is sanitizing.');
        }
        if (String.isBlank(this.ncOrBaseUrl)) {
            throw new CalloutBuilderException('NC or base URL must be provided');
        }
        if (String.isBlank(this.method)) {
            throw new CalloutBuilderException('HTTP method must be provided');
        }
        this.endpoint.resolve(); // placeholders must resolve before guardrails read the endpoint
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

    private HttpResponse getRawHttpResponse() {
        this.parsingResponseBody = true;
        try {
            return this.getHttpResponse();
        } finally {
            this.parsingResponseBody = false;
        }
    }

    private CalloutResponseParser getParser(HttpResponse response) {
        if (this.customParser != null) {
            return this.customParser;
        }
        return CalloutResponseParser.forResponse(response);
    }

    private void constructRequest() {
        this.request = new HttpRequest();
        this.request.setEndpoint(this.constructFullEndpoint());
        this.request.setMethod(this.method);
        if (this.timeout != null) {
            this.request.setTimeout(this.timeout);
        }
        if (this.clientCertificateName != null) {
            this.request.setClientCertificateName(this.clientCertificateName);
        }
        this.request.setCompressed(this.compressed);
        this.attachBody();
        this.attachHeaders();
    }

    private String getEncodedQueryParameters() {
        if (this.queryParameters.isEmpty()) {
            return '';
        }
        return new CalloutUrlEncodedForm(this.queryParameters).toString();
    }

    /**
     * @description attachBody sets body of the request, in precedence order:
     * 1. blob
     * 2. XML (Dom.Document or CalloutXmlSerializable)
     * 3. any other body, by Content-Type: a String as-is, form fields or JSON
     *    (a body always wins over query parameters)
     * 4. query parameters (if any and if method is not GET)
     */
    private void attachBody() {
        if (this.hasBlobBody && this.body != null) {
            this.request.setBodyAsBlob((Blob) this.body);
            this.defaultContentType('application/octet-stream');
        } else if (this.body instanceof Dom.Document) {
            // not setBodyDocument(): getBody() would then return an empty string
            this.request.setBody(((Dom.Document) this.body).toXmlString());
            this.defaultContentType('application/xml');
        } else if (this.body instanceof CalloutXmlSerializable) {
            CalloutXmlSerializable xmlBody = (CalloutXmlSerializable) this.body;
            this.request.setBody(xmlBody.toXmlBuilder().toXmlString());
            this.defaultContentType('application/xml');
        } else if (this.body != null) {
            this.request.setBody(this.toTextBody());
            this.defaultContentType('application/json');
        } else if (!this.queryParameters.isEmpty() && this.method != 'GET') {
            this.request.setBody(this.getEncodedQueryParameters());
        }
    }

    private String toTextBody() {
        if (this.body instanceof String && !this.hasJsonContentType()) {
            return (String) this.body;
        }
        if (this.hasFormContentType()) {
            return new CalloutUrlEncodedForm(this.body).toString();
        }
        return JSON.serialize(this.body, this.suppressApexObjectNulls);
    }

    // without a Content-Type, Salesforce sends application/x-www-form-urlencoded
    private void defaultContentType(String mediaType) {
        if (this.getContentType() == null) {
            this.request.setHeader('Content-Type', mediaType);
        }
    }

    // no Content-Type means JSON
    private Boolean hasJsonContentType() {
        String mediaType = this.getMediaType();
        return mediaType == null || mediaType == 'application/json' || mediaType.endsWith('+json');
    }

    private Boolean hasFormContentType() {
        return this.getMediaType() == 'application/x-www-form-urlencoded';
    }

    private String getMediaType() {
        return this.getContentType()?.substringBefore(';').trim().toLowerCase();
    }

    private String getContentType() {
        for (String header : this.headersMap.keySet()) {
            if (header.equalsIgnoreCase('Content-Type')) {
                return this.headersMap.get(header);
            }
        }
        return null;
    }

    private void attachHeaders() {
        for (String header : headersMap.keySet()) {
            this.request.setHeader(header, headersMap.get(header));
        }
    }

    private void setMockIfTest() {
        if (!Test.isRunningTest()) {
            return;
        }
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
        if (!this.isErrorResponseType(errorType)) {
            throw new CalloutBuilderException('Callout error must implement CalloutErrorResponse');
        }
    }

    private Boolean isErrorResponseType(System.Type errorType) {
        try {
            return errorType.newInstance() instanceof CalloutErrorResponse;
        } catch (Exception e) {
            return false;
        }
    }

    private void validateResponse() {
        if (this.debugMode) {
            CalloutDebug.log(this.response);
        }
        if (this.bypassResponseValidation) {
            return;
        }
        if (this.response.getStatusCode() >= 400) {
            CalloutBuilderException ex = new CalloutBuilderException(
                this.response,
                this.errorResponseImplType,
                this.getParser(this.response)
            );
            this.error = ex.getError();
            throw ex;
        }
    }

    private Boolean canRetry() {
        return this.retrier != null && this.maxRetries >= this.attempt;
    }

    public class CalloutBuilderException extends Exception {
        // null when the exception is not caused by an HTTP response
        public final Integer code;
        public final String status;
        private CalloutErrorResponse error;

        public CalloutBuilderException(HttpResponse response, System.Type errorType) {
            this(response, errorType, CalloutResponseParser.forResponse(response));
        }

        public CalloutBuilderException(HttpResponse response, System.Type errorType, CalloutResponseParser parser) {
            this.code = response.getStatusCode();
            this.status = response.getStatus();
            this.setMessage(this.extractMessage(response, errorType, parser));
        }

        public CalloutErrorResponse getError() {
            return this.error;
        }

        /**
         * @description message is the error body by default;
         * a blank body falls back to the HTTP status text,
         * a parsed error object overrides it when getErrorMessage() is non-blank
         */
        private String extractMessage(HttpResponse response, System.Type errorType, CalloutResponseParser parser) {
            String body = response.getBody();
            if (String.isBlank(body)) {
                return response.getStatus();
            }
            if (errorType != null) {
                try {
                    this.error = (CalloutErrorResponse) parser.deserialize(body, errorType);
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