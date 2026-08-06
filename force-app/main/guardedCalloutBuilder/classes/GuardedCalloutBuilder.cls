/**
* @description A CalloutBuilder subclass that runs a guardrail chain before any
* callout leaves the org. A guardrail throws GuardedCalloutException to block
* the request, and inspects it through this class's read accessors.
* @team Laserburst
*/
public with sharing class GuardedCalloutBuilder extends CalloutBuilder {
    private static final Set<String> VALID_METHODS = new Set<String>{ 'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD' };

    private final String namedCredential;
    private String inspectableBody; // null for binary content
    @TestVisible
    private GuardedCalloutConfig config; // resolved on first read; @TestVisible so guardrail tests can inject one
    private Boolean chainRegistered = false;
    private List<CalloutGuardrail> guardrails;

    public GuardedCalloutBuilder(String namedCredential) {
        super('callout:' + namedCredential);
        if (String.isBlank(namedCredential)) {
            throw new GuardedCalloutException(
                'A Named Credential developer name is required to build a guarded callout.'
            );
        }
        this.namedCredential = namedCredential;
    }

    public override CalloutBuilder withEndpoint(String path) {
        if (String.isBlank(path)) {
            return this;
        }
        return super.withEndpoint(path.startsWith('/') ? path : '/' + path);
    }

    public override CalloutBuilder withMethod(String method) {
        if (String.isBlank(method)) {
            return this; // CalloutBuilder's GET default stands
        }
        String normalized = method.trim().toUpperCase();
        if (!VALID_METHODS.contains(normalized)) {
            throw new GuardedCalloutException('HTTP method "' + method + '" is not a valid method.');
        }
        return super.withMethod(normalized);
    }

    public override CalloutBuilder withBody(Object body) {
        if (body == null) {
            return this;
        }
        if (body instanceof String) {
            return this.withBlobBody(body); // verbatim: super.withBody would JSON-serialize it again
        }
        this.inspectableBody = JSON.serialize(body);
        return super.withBody(body);
    }

    public override CalloutBuilder withBlobBody(Object body) {
        if (body == null) {
            return this;
        }
        this.inspectableBody = stringForm(body);
        return super.withBlobBody(body instanceof String ? Blob.valueOf((String) body) : body);
    }

    public override HttpResponse getHttpResponse() {
        this.registerGuardrails();
        return super.getHttpResponse();
    }

    // Read accessors (the context guardrails inspect)

    public String getNamedCredential() {
        return this.namedCredential;
    }

    public String getPath() {
        return this.getEndpoint();
    }

    public String getBody() {
        return this.inspectableBody;
    }

    public GuardedCalloutConfig getConfig() {
        if (this.config == null) {
            this.config = GuardedCalloutConfig.forName(this.namedCredential);
        }
        return this.config;
    }

    private void registerGuardrails() {
        if (String.isBlank(this.getEndpoint())) {
            throw new GuardedCalloutException('An endpoint path is required, e.g. withEndpoint(\'/v1/resource\').');
        }
        if (this.chainRegistered) {
            return;
        }
        this.withGuardrails(this.getGuardrails());
        this.chainRegistered = true;
    }

    private List<CalloutGuardrail> getGuardrails() {
        if (this.guardrails == null) {
            this.guardrails = GuardrailsFactory.create(this.getConfig());
        }
        return this.guardrails;
    }

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
}