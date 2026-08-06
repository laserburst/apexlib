/**
* @description A CalloutBuilder subclass that runs a guardrail chain before any
* callout leaves the org. A guardrail throws GuardedCalloutException to block
* the request, and inspects it through this class's read accessors.
* @team Laserburst
*/
public with sharing class GuardedCalloutBuilder extends CalloutBuilder {
    private final String namedCredential;
    private String inspectableBody; // null for binary content
    @TestVisible
    private GuardedCalloutConfig config; // resolved on first read; @TestVisible so guardrail tests can inject one
    private Boolean chainRegistered = false;
    private List<CalloutGuardrail> guardrails;

    private static final String CALLOUT_PREFIX = 'callout:';

    public GuardedCalloutBuilder(String namedCredential) {
        super(validate(namedCredential));
        this.namedCredential = namedCredential.removeStart(CALLOUT_PREFIX);
    }

    private static String validate(String namedCredential) {
        if (String.isBlank(namedCredential)) {
            throw new GuardedCalloutException(
                'A Named Credential developer name is required to build a guarded callout.'
            );
        }
        if (namedCredential.startsWithIgnoreCase('http://') || namedCredential.startsWithIgnoreCase('https://')) {
            throw new GuardedCalloutException(
                'A guarded callout requires a Named Credential developer name, not a URL: "' + namedCredential + '".'
            );
        }
        return namedCredential.startsWith(CALLOUT_PREFIX) ? namedCredential : CALLOUT_PREFIX + namedCredential;
    }

    public override CalloutBuilder withEndpoint(String path) {
        if (String.isBlank(path)) {
            return this;
        }
        return super.withEndpoint(path.startsWith('/') ? path : '/' + path);
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

    public String getInspectableBody() {
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