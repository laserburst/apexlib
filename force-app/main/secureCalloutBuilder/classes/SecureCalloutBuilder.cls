/**
 * @description SecureCalloutBuilder makes every callout of a CalloutBuilder obey its policies: a callout that no
 * policy allows is blocked before anything is sent, a response goes through the sanitizers of the policies that
 * applied to its request, and an error body is withheld unless those policies consent. The builder itself runs the
 * policies, so the getters only pass through, and executing the builder directly is just as secure.
 * @team Laserburst
 */
public class SecureCalloutBuilder {
    private final CalloutBuilder callout;
    private final PolicyEnforcer enforcer = new PolicyEnforcer();

    /**
     * @param callout configured fully first: a guardrail added afterwards runs after the policies, once the request
     * has passed them
     */
    public SecureCalloutBuilder(CalloutBuilder callout) {
        if (callout == null) {
            throw new CalloutBuilder.CalloutBuilderException('A CalloutBuilder must be provided');
        }
        this.enforcer.attachTo(callout);
        this.callout = callout;
    }

    /**
     * @description withPolicy appends a policy; the policies are read again at every execution
     */
    public SecureCalloutBuilder withPolicy(CalloutPolicy policy) {
        this.enforcer.add(policy);
        return this;
    }

    /**
     * @param policies each added as by withPolicy()
     */
    public SecureCalloutBuilder withPolicies(List<CalloutPolicy> policies) {
        this.enforcer.addAll(policies);
        return this;
    }

    /**
     * @description getHttpResponse is CalloutBuilder.getHttpResponse() under the policies; a
     * CalloutPolicyException means nothing was sent
     */
    public HttpResponse getHttpResponse() {
        return this.callout.getHttpResponse();
    }

    /**
     * @description getResponseBodyAsBlob is CalloutBuilder.getResponseBodyAsBlob() under the policies
     */
    public Blob getResponseBodyAsBlob() {
        return this.callout.getResponseBodyAsBlob();
    }

    /**
     * @description getResponseBodyMap is CalloutBuilder.getResponseBodyMap() under the policies
     */
    public Map<String, Object> getResponseBodyMap() {
        return this.callout.getResponseBodyMap();
    }

    /**
     * @description getTypedResponseBody is CalloutBuilder.getTypedResponseBody() under the policies
     */
    public Object getTypedResponseBody() {
        return this.callout.getTypedResponseBody();
    }

    /**
     * @description getXmlResponseBody is CalloutBuilder.getXmlResponseBody() under the policies
     */
    public Dom.Document getXmlResponseBody() {
        return this.callout.getXmlResponseBody();
    }

    /**
     * @description PolicyEnforcer is both the guardrail and the sanitizer, so a response meets the sanitizers of the
     * policies that applied to its own request. Queueable serialization keeps it one object.
     */
    private class PolicyEnforcer extends CalloutResponseSanitizer implements CalloutGuardrail {
        private final List<CalloutPolicy> policies = new List<CalloutPolicy>();
        private CalloutResponseSanitizer sanitizer;

        /**
         * @description attachTo makes CB run the enforcer before every request and on every response
         */
        public void attachTo(CalloutBuilder callout) {
            callout.withGuardrail(this).withResponseSanitizer(this);
        }

        public void add(CalloutPolicy policy) {
            this.policies.add(policy);
        }

        public void addAll(List<CalloutPolicy> policies) {
            this.policies.addAll(policies);
        }

        // keeps only the sanitizer: the effective policy holds the request body, which CB frees from the heap
        public void enforce(CalloutBuilder builder) {
            this.sanitizer = null;
            CalloutEffectivePolicy candidate = new CalloutEffectivePolicy(this.policies, builder);
            candidate.enforce(builder);
            this.sanitizer = candidate.getResponseSanitizer();
        }

        public override void sanitizeError(HttpResponse response) {
            this.toSanitizer().sanitizeError(response);
        }

        public override void sanitize(HttpResponse response) {
            this.toSanitizer().sanitize(response);
        }

        public override void sanitize(Map<String, Object> body) {
            this.toSanitizer().sanitize(body);
        }

        public override void sanitize(Object body, System.Type successType) {
            this.toSanitizer().sanitize(body, successType);
        }

        public override void sanitize(Dom.Document body) {
            this.toSanitizer().sanitize(body);
        }

        // fails closed: nothing is kept unless enforce() passed
        private CalloutResponseSanitizer toSanitizer() {
            if (this.sanitizer == null) {
                throw new CalloutResponseSanitizerException('No policy let this callout through');
            }
            return this.sanitizer;
        }
    }
}