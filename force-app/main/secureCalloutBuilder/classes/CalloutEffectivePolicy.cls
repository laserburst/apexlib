/**
 * @description CalloutEffectivePolicy is the access a list of policies gives one callout, like UserRecordAccess:
 * the route its path takes, the policies that apply to it, and the grants of those that may grant.
 * @team Laserburst
 */
public class CalloutEffectivePolicy {
    private static final String WITHHELD = 'Withheld by policy';

    private final CalloutRequestSnapshot snapshot;
    private final List<CalloutPolicy> applicablePolicies = new List<CalloutPolicy>();
    private final CalloutGrants grants = new CalloutGrants();
    private final EffectiveSanitizer sanitizer;

    /**
     * @description throws CalloutPolicyException with PATH, NO_ROUTE or METHOD when the callout isn't allowed
     */
    public CalloutEffectivePolicy(List<CalloutPolicy> policies, CalloutBuilder callout) {
        this.snapshot = new CalloutRequestSnapshot(callout);
        CalloutPolicy route = this.toRoute(policies);
        if (route == null) {
            throw this.snapshot.toException(CalloutPolicyRule.NO_ROUTE, 'no policy allows this path');
        }
        Boolean allowed = false;
        for (CalloutPolicy policy : policies) {
            if (policy.isApplicable(callout, this.snapshot)) {
                this.applicablePolicies.add(policy);
                if (this.isGranting(policy, route)) {
                    this.grants.addAll(policy.getGrants());
                    allowed |= policy.isAllowing();
                }
            }
        }
        if (!allowed) {
            throw this.snapshot.toException(CalloutPolicyRule.METHOD, 'method is not allowed on this path');
        }
        this.sanitizer = new EffectiveSanitizer(this);
    }

    /**
     * @description enforce runs each applicable policy's checks, then the fixed rules, then the grants
     */
    public void enforce(CalloutBuilder callout) {
        for (CalloutPolicy policy : this.applicablePolicies) {
            policy.enforce(callout, this.snapshot);
        }
        this.snapshot.enforceFixedRules();
        this.grants.enforce(this.snapshot);
    }

    /**
     * @description getResponseSanitizer chains the applicable policies' sanitizers in the order the policies were
     * added. Its sanitizeError() withholds the body unless a granting policy calls withErrorBodies() and every
     * applicable policy with sanitizers does too.
     */
    public CalloutResponseSanitizer getResponseSanitizer() {
        return this.sanitizer;
    }

    // the most specific allowing policy whose base URL and endpoint match; the method plays no part
    private CalloutPolicy toRoute(List<CalloutPolicy> policies) {
        CalloutPolicy route;
        for (CalloutPolicy policy : policies) {
            if (policy.isAllowing() && policy.isInScope(this.snapshot) && this.isMoreSpecific(policy, route)) {
                route = policy;
            }
        }
        return route;
    }

    private Boolean isMoreSpecific(CalloutPolicy policy, CalloutPolicy route) {
        return route == null || policy.compareTo(route) < 0;
    }

    // of the applicable policies, every one without a method grants, but an allowing one only on the route
    private Boolean isGranting(CalloutPolicy policy, CalloutPolicy route) {
        return !policy.isAllowing() || policy.compareTo(route) == 0;
    }

    private Boolean isWithholdingErrorBodies() {
        if (!this.grants.allowsErrorBodies()) {
            return true;
        }
        for (CalloutPolicy policy : this.applicablePolicies) {
            if (!policy.getResponseSanitizers().isEmpty() && !policy.getGrants().allowsErrorBodies()) {
                return true;
            }
        }
        return false;
    }

    private class EffectiveSanitizer extends CalloutResponseSanitizer {
        private final CalloutResponseSanitizerChain chain = new CalloutResponseSanitizerChain();
        private final CalloutGrants grants;
        private final Boolean withholdsErrorBodies;

        // copies what it needs: holding the effective policy would keep its request snapshot alive with the response
        public EffectiveSanitizer(CalloutEffectivePolicy effectivePolicy) {
            for (CalloutPolicy policy : effectivePolicy.applicablePolicies) {
                this.chain.addAll(policy.getResponseSanitizers());
            }
            this.grants = effectivePolicy.grants;
            this.withholdsErrorBodies = effectivePolicy.isWithholdingErrorBodies();
        }

        // CB blanks a withheld body and throws CalloutBuilderException with the code and this status
        public override void sanitizeError(HttpResponse response) {
            this.grants.blankCredentialHeaders(response);
            if (this.withholdsErrorBodies) {
                response.setStatus(WITHHELD);
                throw new CalloutResponseSanitizerException(WITHHELD);
            }
            this.chain.sanitizeError(response);
        }

        public override void sanitize(HttpResponse response) {
            this.grants.blankCredentialHeaders(response);
            this.chain.sanitize(response);
        }

        public override void sanitize(Map<String, Object> body) {
            this.chain.sanitize(body);
        }

        public override void sanitize(Object body, System.Type successType) {
            this.chain.sanitize(body, successType);
        }

        public override void sanitize(Dom.Document body) {
            this.chain.sanitize(body);
        }
    }
}