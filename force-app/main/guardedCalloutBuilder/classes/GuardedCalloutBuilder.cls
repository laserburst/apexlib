/**
 * @description A decorator around CalloutBuilder (composition — CalloutBuilder is
 * not extendable) that mirrors its public API and enforces a guardrail chain
 * before any callout leaves the org. The chain is: authentication, allowed
 * method, allowed endpoint, then any custom guardrails named in the
 * configuration (in listed order). Any guardrail may throw
 * GuardedCalloutException to block the call; guardrails receive this decorator
 * and inspect the request through its read accessors.
 *
 * Differences from a bare CalloutBuilder, beyond guardrail enforcement:
 * query parameters are URL-encoded and appended to the endpoint for every
 * HTTP method (CalloutBuilder does that only for GET), String bodies are sent
 * verbatim (CalloutBuilder would JSON-serialize them a second time), the
 * timeout defaults to 30 seconds and is clamped to platform bounds, and
 * Content-Type defaults to application/json when a body is present.
 * @team Laserburst
 */
public with sharing class GuardedCalloutBuilder {
    private static final Integer DEFAULT_TIMEOUT = 30000;
    private static final Integer MIN_TIMEOUT = 1000;
    private static final Integer MAX_TIMEOUT = 120000;
    private static final Set<String> VALID_METHODS = new Set<String>{
        'GET',
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
        'HEAD'
    };

    private final CalloutBuilder builder;
    private final String namedCredential;
    // Own copies of state CalloutBuilder cannot echo back, kept for the guardrails and prepare()
    private String path;
    private final Map<String, String> headers = new Map<String, String>();
    private final Map<String, String> queryParameters = new Map<String, String>();
    private String body;
    private Integer timeoutMilliseconds;
    @TestVisible
    private GuardedCalloutConfig config; // loaded on execution; @TestVisible so guardrail tests can inject one
    private Boolean enforcing = false;

    public GuardedCalloutBuilder(String namedCredential) {
        if (String.isBlank(namedCredential)) {
            throw new GuardedCalloutException('A Named Credential developer name is required to build a guarded callout.');
        }
        this.namedCredential = namedCredential;
        this.builder = new CalloutBuilder('callout:' + namedCredential);
    }

    // --- Mirrored CalloutBuilder API ---

    public GuardedCalloutBuilder withEndpoint(String path) {
        if (String.isNotBlank(path)) {
            this.path = path.startsWith('/') ? path : '/' + path;
        }
        // builder.withEndpoint() is applied in prepare(), once the query string is baked in
        return this;
    }

    public GuardedCalloutBuilder withMethod(String method) {
        if (String.isBlank(method)) {
            return this; // CalloutBuilder's GET default stands
        }
        String normalized = method.trim().toUpperCase();
        if (!VALID_METHODS.contains(normalized)) {
            throw new GuardedCalloutException('HTTP method "' + method + '" is not a valid method.');
        }
        this.builder.withMethod(normalized);
        return this;
    }

    public GuardedCalloutBuilder withHeader(String key, String value) {
        if (String.isNotBlank(key)) {
            this.headers.put(key, value);
            this.builder.withHeader(key, value);
        }
        return this;
    }

    public GuardedCalloutBuilder withHeaders(Map<String, String> headers) {
        if (headers != null) {
            for (String key : headers.keySet()) {
                this.withHeader(key, headers.get(key));
            }
        }
        return this;
    }

    // Never delegated: CalloutBuilder appends query parameters to the URL only for GET;
    // prepare() bakes them into the endpoint for every method instead.
    public GuardedCalloutBuilder withQueryParameter(String key, String value) {
        if (String.isNotBlank(key)) {
            this.queryParameters.put(key, value);
        }
        return this;
    }

    public GuardedCalloutBuilder withQueryParameters(Map<String, String> queryParameters) {
        if (queryParameters != null) {
            for (String key : queryParameters.keySet()) {
                this.withQueryParameter(key, queryParameters.get(key));
            }
        }
        return this;
    }

    public GuardedCalloutBuilder withTimeout(Integer timeoutMilliseconds) {
        if (timeoutMilliseconds != null) {
            this.timeoutMilliseconds = Math.min(Math.max(timeoutMilliseconds, MIN_TIMEOUT), MAX_TIMEOUT);
            this.builder.withTimeout(this.timeoutMilliseconds);
        }
        return this;
    }

    // A String body is routed through withBlobBody so it goes over the wire verbatim;
    // CalloutBuilder.withBody would JSON-serialize it a second time, and guardrails
    // must inspect the body that is actually sent.
    public GuardedCalloutBuilder withBody(Object body) {
        if (body == null) {
            return this;
        }
        if (body instanceof String) {
            return this.withBlobBody(body);
        }
        this.body = JSON.serialize(body);
        this.builder.withBody(body);
        return this;
    }

    public GuardedCalloutBuilder withBlobBody(Object body) {
        if (body != null) {
            this.body = stringForm(body);
            this.builder.withBlobBody(body instanceof String ? Blob.valueOf((String) body) : body);
        }
        return this;
    }

    // withFile sets its own Content-Type and blob body; file parts are not guardrail-inspectable
    public GuardedCalloutBuilder withFile(CalloutHexFormBuilder formBuilder) {
        this.builder.withFile(formBuilder);
        return this;
    }

    public GuardedCalloutBuilder withMockIfTest(HttpCalloutMock mock) {
        this.builder.withMockIfTest(mock);
        return this;
    }

    public GuardedCalloutBuilder withSuccessType(System.Type successType) {
        this.builder.withSuccessType(successType);
        return this;
    }

    public GuardedCalloutBuilder withErrorType(System.Type errorType) {
        this.builder.withErrorType(errorType);
        return this;
    }

    public GuardedCalloutBuilder withRetrier(CalloutRetrier retrier) {
        this.builder.withRetrier(retrier);
        return this;
    }

    public GuardedCalloutBuilder withMaxRetries(Integer maxRetries) {
        this.builder.withMaxRetries(maxRetries);
        return this;
    }

    public GuardedCalloutBuilder withBypassResponseValidation(Boolean bypassResponseValidation) {
        this.builder.withBypassResponseValidation(bypassResponseValidation);
        return this;
    }

    public GuardedCalloutBuilder withDebugMode(Boolean debugMode) {
        this.builder.withDebugMode(debugMode);
        return this;
    }

    public GuardedCalloutBuilder withSuppressApexObjectNulls(Boolean suppressApexObjectNulls) {
        this.builder.withSuppressApexObjectNulls(suppressApexObjectNulls);
        return this;
    }

    // --- Guarded execution (each runs the guardrail chain, then delegates) ---

    public HttpResponse getHttpResponse() {
        this.prepare();
        return this.builder.getHttpResponse();
    }

    public Map<String, Object> getResponseBodyMap() {
        this.prepare();
        return this.builder.getResponseBodyMap();
    }

    public Object getTypedResponseBody() {
        this.prepare();
        return this.builder.getTypedResponseBody();
    }

    public Blob getResponseBodyAsBlob() {
        this.prepare();
        return this.builder.getResponseBodyAsBlob();
    }

    // --- Read accessors (the context guardrails inspect) ---

    public String getNamedCredential() {
        return this.namedCredential;
    }

    public String getPath() {
        return this.path;
    }

    public Map<String, String> getHeaders() {
        return new Map<String, String>(this.headers);
    }

    public Map<String, String> getQueryParameters() {
        return new Map<String, String>(this.queryParameters);
    }

    public String getBody() {
        return this.body;
    }

    public GuardedCalloutConfig getConfig() {
        return this.config;
    }

    public String getMethod() {
        return this.builder.getMethod();
    }

    public CalloutErrorResponse getError() {
        return this.builder.getError();
    }

    // Not a pure accessor: bakes the query string into the wrapped builder's endpoint
    public String constructFullEndpoint() {
        this.bakeEndpoint();
        return this.builder.constructFullEndpoint();
    }

    // --- Implementation details ---

    private void prepare() {
        if (this.enforcing) {
            throw new GuardedCalloutException('A guardrail must not execute the callout it is guarding.');
        }
        if (String.isBlank(this.path)) {
            throw new GuardedCalloutException('An endpoint path is required, e.g. withEndpoint(\'/v1/resource\').');
        }
        this.bakeEndpoint();
        if (this.timeoutMilliseconds == null) {
            this.withTimeout(DEFAULT_TIMEOUT);
        }
        if (String.isNotBlank(this.body) && !this.containsKeyIgnoreCase(this.headers, 'Content-Type')) {
            this.withHeader('Content-Type', 'application/json');
        }
        if (this.config == null) {
            this.config = GuardedCalloutConfig.forName(this.namedCredential);
        }
        this.enforcing = true;
        try {
            for (CalloutGuardrail guardrail : this.resolveGuardrails()) {
                guardrail.enforce(this);
            }
        } finally {
            this.enforcing = false;
        }
    }

    // Best-effort string form of a body for guardrail inspection; null for binary content
    private static String stringForm(Object body) {
        if (body instanceof String) {
            return (String) body;
        }
        if (body instanceof Blob) {
            try {
                return ((Blob) body).toString();
            } catch (Exception e) {
                return null;
            }
        }
        return JSON.serialize(body);
    }

    private void bakeEndpoint() {
        if (String.isNotBlank(this.path)) {
            this.builder.withEndpoint(this.buildPathWithQuery());
        }
    }

    private String buildPathWithQuery() {
        if (this.queryParameters.isEmpty()) {
            return this.path;
        }
        List<String> pairs = new List<String>();
        for (String key : this.queryParameters.keySet()) {
            String value = this.queryParameters.get(key);
            pairs.add(
                EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(value == null ? '' : value, 'UTF-8')
            );
        }
        String separator = this.path.contains('?') ? '&' : '?';
        return this.path + separator + String.join(pairs, '&');
    }

    private Boolean containsKeyIgnoreCase(Map<String, String> headers, String target) {
        for (String key : headers.keySet()) {
            if (key.equalsIgnoreCase(target)) {
                return true;
            }
        }
        return false;
    }

    @TestVisible
    private List<CalloutGuardrail> resolveGuardrails() {
        List<CalloutGuardrail> guardrails = new List<CalloutGuardrail>{
            new CalloutAuthenticationGuardrail(),
            new CalloutMethodGuardrail(),
            new CalloutEndpointGuardrail()
        };
        for (String className : this.config.guardrails) {
            guardrails.add(this.instantiate(className));
        }
        return guardrails;
    }

    private CalloutGuardrail instantiate(String className) {
        System.Type guardrailType = System.Type.forName(className);
        if (guardrailType == null) {
            throw new GuardedCalloutException(
                'Custom guardrail class "' +
                    className +
                    '" was not found. Check the "guardrails" list in the configuration for "' +
                    this.namedCredential +
                    '".'
            );
        }
        Object instance;
        try {
            instance = guardrailType.newInstance();
        } catch (Exception e) {
            throw new GuardedCalloutException(
                'Custom guardrail class "' + className + '" could not be instantiated: ' + e.getMessage()
            );
        }
        if (!(instance instanceof CalloutGuardrail)) {
            throw new GuardedCalloutException('Custom guardrail class "' + className + '" must implement CalloutGuardrail.');
        }
        return (CalloutGuardrail) instance;
    }
}