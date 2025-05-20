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
@SuppressWarnings('PMD.CognitiveComplexity, PMD.ExcessivePublicCount, PMD.CyclomaticComplexity, PMD.TooManyFields')
public with sharing class CalloutBuilder {
    private String ncOrBaseUrl;
    private String endpoint;
    private String method = 'GET';
    private Object body;

    private System.Type successType;
    private Integer timeout = 120000; // 120000 is the max timeout
    private Map<String, String> headersMap = new Map<String, String>();
    private Boolean hasBlobBody = false;
    private Map<String, String> queryParameters = new Map<String, String>();

    private HttpRequest request;
    private HttpResponse response;
    private HttpCalloutMock mock;
    private Boolean suppressApexObjectNulls = true;

    private CalloutRetrier retrier;
    private Integer maxRetries = 1;
    private Integer attempt = 0;

    // CalloutErrorResponse implementation
    private System.Type errorResponseImplType;
    private CalloutErrorResponse error;
    private Boolean bypassResponseValidation = false;

    public CalloutBuilder(String ncOrBaseUrl) {
        this.ncOrBaseUrl = ncOrBaseUrl;
    }

    // Optional setters
    public CalloutBuilder withEndpoint(String endpoint) {
        this.endpoint = endpoint;
        return this;
    }

    public CalloutBuilder withMethod(String method) {
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

    public CalloutBuilder withBody(Object body) {
        this.body = body;
        return this;
    }

    public CalloutBuilder withBlobBody(Object body) {
        this.hasBlobBody = true;
        this.withBody(body);
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

    public CalloutBuilder withMaxRetries(Integer maxRetries) {
        this.maxRetries = maxRetries;
        return this;
    }

    public CalloutBuilder withBypassResponseValidation(Boolean bypassResponseValidation) {
        this.bypassResponseValidation = bypassResponseValidation;
        return this;
    }

    /**
     * @description withSuppressApexObjectNulls affects request body serialization
     * @param  suppressApexObjectNulls if true (default), null values are not serialized
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
            String value = queryParameters.get(key);
            if (String.isBlank(key)) {
                throw new CalloutBuilderException('This query parameter value has empty key: ' + value);
            }
            this.withQueryParameter(key, value);
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
    */
    public HttpResponse getHttpResponse() {
        this.validateBeforeCall();
        this.constructRequest();
        this.setMockIfTest();

        do {
            this.attempt++;
            this.response = new Http().send(this.request);
        } while (this.canRetry() && this.retrier?.shouldRetry(this.response));
        this.attempt = 0;

        this.validateResponse();
        return this.response;
    }

    /**
    * @description It makes a callout, validates response
    * and converts its body JSON into Map<String, Object>
    */
    public Map<String, Object> getResponseBodyMap() {
        this.getHttpResponse();
        return (Map<String, Object>) JSON.deserializeUntyped(this.response.getBody());
    }

    /**
    * @description It makes a callout, validates response
    * and converts its body into an object specified in .withSuccessType() method
    */
    public Object getTypedResponseBody() {
        if (this.successType == null) {
            throw new CalloutBuilderException('getTypedResponseBody expects this.successType to be set');
        }
        this.getHttpResponse();
        return JSON.deserialize(this.response.getBody(), this.successType);
    }

    // implementation details

    /**
    * @description it checks if required fields are set.
    */
    private void validateBeforeCall() {
        if (String.isBlank(this.ncOrBaseUrl)) {
            throw new CalloutBuilderException('NC or base URL must be provided');
        }
        if (String.isBlank(this.method)) {
            throw new CalloutBuilderException('HTTP method must be provided');
        }
    }

    private void constructRequest() {
        this.request = new HttpRequest();
        this.request.setEndpoint(this.constructFullEndpoint());
        this.request.setMethod(this.method);
        this.request.setTimeout(this.timeout);
        this.attachBody();
        this.attachHeaders();
    }

    /**
     * @description constructFullEndpoint returns full URL for the callout
     * @return   return base URL + endpoint + query parameters (if any and if GET method)
     */
    @TestVisible
    private String constructFullEndpoint() {
        String fullEndpoint = String.isNotBlank(this.endpoint) ? this.ncOrBaseUrl + this.endpoint : this.ncOrBaseUrl;

        if (this.method == 'GET' && !this.queryParameters.isEmpty()) {
            fullEndpoint += '?' + this.getEncodedQueryParameters();
        }

        return fullEndpoint;
    }

    private final String encoding = 'UTF-8';
    private String getEncodedQueryParameters() {
        if (this.queryParameters.isEmpty()) {
            return '';
        }
        List<String> encodedPairs = new List<String>();
        for (String key : this.queryParameters.keySet()) {
            String encodedKey = EncodingUtil.urlEncode(key, this.encoding);
            String encodedValue = EncodingUtil.urlEncode(this.queryParameters.get(key), this.encoding);
            encodedPairs.add(encodedKey + '=' + encodedValue);
        }
        return String.join(encodedPairs, '&');
    }

    /**
     * @description attachBody sets body of the request:
     * 1. blob
     * 2. query parameters (if any and if method is not GET). 
     * 3. JSON (default)
     */
    private void attachBody() {
        if (this.body == null && this.queryParameters.isEmpty()) {
            return;
        }

        if (this.hasBlobBody && this.body != null) {
            this.request.setBodyAsBlob((Blob) body);
        } else if (!this.queryParameters.isEmpty() && this.method != 'GET') {
            String body = this.body != null ? (String) this.body : this.getEncodedQueryParameters();
            this.request.setBody(body);
        } else if (this.body != null) {
            this.request.setBody(JSON.serialize(this.body, this.suppressApexObjectNulls));
        }
    }

    private void attachHeaders() {
        for (String header : headersMap.keySet()) {
            this.request.setHeader(header, headersMap.get(header));
        }
    }

    private void setMockIfTest() {
        if (Test.isRunningTest() && this.mock != null) {
            Test.setMock(HttpCalloutMock.class, this.mock);
        }
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
        if (this.bypassResponseValidation) {
            return;
        }
        if (this.response.getStatusCode() >= 400) {
            CalloutErrorResponse errorBody;
            try {
                if (this.errorResponseImplType != null) {
                    errorBody =
                        (CalloutErrorResponse) JSON.deserialize(this.response.getBody(), this.errorResponseImplType);
                }
            } finally {
                String message = errorBody != null ? errorBody.getErrorMessage() : this.response.getBody();
                throw new CalloutBuilderException(
                    'Status code ' + this.response.getStatusCode() + ' with message: ' + message
                );
            }
        }
    }

    private Boolean canRetry() {
        return this.retrier != null && this.maxRetries >= this.attempt;
    }

    public class CalloutBuilderException extends Exception {
    }
}
