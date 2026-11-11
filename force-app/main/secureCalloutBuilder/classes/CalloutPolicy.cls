/**
 * @description CalloutPolicy states which callouts to one API it applies to, and what it grants and checks there.
 * A policy that names a method allows those callouts on its endpoint; a policy without a method only adds rules.
 * Every collection setter appends.
 * @team Laserburst
 */
public class CalloutPolicy implements Comparable {
    private static final Map<String, Pattern> PATTERN_BY_REGEX = new Map<String, Pattern>();

    private final String ncOrBaseUrl;
    private final Set<String> methods = new Set<String>();
    private CalloutEndpointPattern endpoint;
    private final List<CalloutCondition> conditions = new List<CalloutCondition>();
    private final CalloutGrants grants = new CalloutGrants();
    private final Map<String, String> regexByPathParameter = new Map<String, String>();
    private final List<CalloutGuardrail> guardrails = new List<CalloutGuardrail>();
    private final List<CalloutResponseSanitizer> sanitizers = new List<CalloutResponseSanitizer>();

    /**
     * @param ncOrBaseUrl compared with the callout's by equals() after a trailing "/" is removed from both
     */
    public CalloutPolicy(String ncOrBaseUrl) {
        if (String.isBlank(ncOrBaseUrl) || ncOrBaseUrl.containsAny('?#') || ncOrBaseUrl.containsWhitespace()) {
            throw new CalloutBuilder.CalloutBuilderException(
                'Policy scope must be a base URL without "?", "#" or whitespace'
            );
        }
        this.ncOrBaseUrl = ncOrBaseUrl;
    }

    /**
     * @description withMethod makes the policy allow callouts with this method on its endpoint
     * @param method compared in upper case
     */
    public CalloutPolicy withMethod(String method) {
        this.methods.add(method.toUpperCase());
        return this;
    }

    /**
     * @param methods each added as by withMethod()
     */
    public CalloutPolicy withMethods(Set<String> methods) {
        for (String method : methods) {
            this.withMethod(method);
        }
        return this;
    }

    /**
     * @description withEndpoint sets the CalloutEndpointPattern; a second call throws, because path parameter
     * patterns refer to its placeholders
     */
    public CalloutPolicy withEndpoint(String endpoint) {
        if (this.endpoint != null) {
            throw new CalloutBuilder.CalloutBuilderException('Policy endpoint is already set');
        }
        this.endpoint = new CalloutEndpointPattern(endpoint);
        return this;
    }

    /**
     * @description withCondition narrows where the policy applies, and every condition must be met. On a policy
     * without a method, a condition that isn't met also skips the policy's checks.
     */
    public CalloutPolicy withCondition(CalloutCondition condition) {
        this.conditions.add(condition);
        return this;
    }

    /**
     * @param names compared without case
     */
    public CalloutPolicy withAllowedHeaders(Set<String> names) {
        this.grants.addHeaders(names);
        return this;
    }

    /**
     * @description withAllowedResponseHeaders lets these response headers come back with their values; any other
     * header whose name contains cookie, token, secret, session, password, credential, authorization, api-key or
     * apikey comes back blank
     * @param names compared without case
     */
    public CalloutPolicy withAllowedResponseHeaders(Set<String> names) {
        this.grants.addResponseHeaders(names);
        return this;
    }

    /**
     * @param names compared exactly, so expand doesn't grant Expand
     */
    public CalloutPolicy withAllowedQueryParameters(Set<String> names) {
        this.grants.addQueryParameters(names);
        return this;
    }

    /**
     * @description withHeaderFormula grants the header with this exact value only, such as {!$Credential.Token}
     */
    public CalloutPolicy withHeaderFormula(String name, String formula) {
        this.grants.addHeaderFormula(name, formula);
        return this;
    }

    /**
     * @description withBlobBodies grants a Blob body, which no check can read
     */
    public CalloutPolicy withBlobBodies() {
        this.grants.allowBlobBodies();
        return this;
    }

    /**
     * @description withErrorBodies lets an error body reach the caller; an applicable policy with sanitizers
     * that doesn't call it still withholds the body
     */
    public CalloutPolicy withErrorBodies() {
        this.grants.allowErrorBodies();
        return this;
    }

    /**
     * @param regex must match the whole value that {name} captures
     */
    public CalloutPolicy withPathParameterPattern(String name, String regex) {
        if (this.endpoint?.hasParameter(name) != true) {
            throw new CalloutBuilder.CalloutBuilderException('Policy endpoint has no {' + name + '} placeholder');
        }
        this.toPattern(regex); // an invalid regex throws here, not at the callout
        this.regexByPathParameter.put(name, regex);
        return this;
    }

    /**
     * @description withGuardrail adds a check for every callout the policy applies to, run before the fixed
     * rules and the grant checks; it blocks by throwing
     */
    public CalloutPolicy withGuardrail(CalloutGuardrail guardrail) {
        this.guardrails.add(guardrail);
        return this;
    }

    /**
     * @param guardrails each added as by withGuardrail()
     */
    public CalloutPolicy withGuardrails(List<CalloutGuardrail> guardrails) {
        this.guardrails.addAll(guardrails);
        return this;
    }

    /**
     * @description withResponseSanitizer adds a sanitizer for the response to every callout the policy
     * applies to; an error body reaches its sanitizeError() only if the policy calls withErrorBodies()
     */
    public CalloutPolicy withResponseSanitizer(CalloutResponseSanitizer sanitizer) {
        this.sanitizers.add(sanitizer);
        return this;
    }

    /**
     * @param sanitizers each added as by withResponseSanitizer()
     */
    public CalloutPolicy withResponseSanitizers(List<CalloutResponseSanitizer> sanitizers) {
        this.sanitizers.addAll(sanitizers);
        return this;
    }

    /**
     * @return the scope as written
     */
    public String getNcOrBaseUrl() {
        return this.ncOrBaseUrl;
    }

    /**
     * @return a copy, in upper case; empty for a policy that only adds rules
     */
    public Set<String> getMethods() {
        return new Set<String>(this.methods);
    }

    /**
     * @return the endpoint pattern as written, or null when the policy has none
     */
    public String getEndpoint() {
        return this.endpoint?.getEndpoint();
    }

    /**
     * @return a copy, so the policy's grants can't change through it
     */
    public CalloutGrants getGrants() {
        CalloutGrants copy = new CalloutGrants();
        copy.addAll(this.grants);
        return copy;
    }

    /**
     * @return a copy, in the order added
     */
    public List<CalloutResponseSanitizer> getResponseSanitizers() {
        return new List<CalloutResponseSanitizer>(this.sanitizers);
    }

    /**
     * @description isAllowing is true when the policy names a method; a policy without one only adds rules
     */
    public Boolean isAllowing() {
        return !this.methods.isEmpty();
    }

    /**
     * @description isApplicable is true when the base URL, the method, the endpoint and every condition match;
     * it throws CalloutPolicyException (PATH) for a path the path rule blocks
     */
    public Boolean isApplicable(CalloutBuilder callout) {
        return this.isApplicable(callout, new CalloutRequestSnapshot(callout));
    }

    /**
     * @description isApplicable reads the request from the snapshot, so many policies share one decoded path
     */
    public Boolean isApplicable(CalloutBuilder callout, CalloutRequestSnapshot snapshot) {
        return this.isMethodNamed(snapshot.getMethod()) && this.isInScope(snapshot) && this.areConditionsMet(callout);
    }

    /**
     * @description isInScope is true when the base URL and the endpoint match, whatever the method and conditions
     */
    public Boolean isInScope(CalloutRequestSnapshot snapshot) {
        return this.ncOrBaseUrl.removeEnd('/').equals(snapshot.getBaseUrl())
            && (this.endpoint == null || this.endpoint.matches(snapshot.getPath()));
    }

    /**
     * @description compareTo is negative when this policy's endpoint is more specific, so a sorted list starts
     * with the route that wins; a policy without an endpoint ranks last
     */
    public Integer compareTo(Object other) {
        CalloutEndpointPattern otherEndpoint = ((CalloutPolicy) other).endpoint;
        if (this.endpoint != null) {
            return this.endpoint.compareTo(otherEndpoint);
        }
        if (otherEndpoint != null) {
            return 1;
        }
        return 0;
    }

    /**
     * @description enforce runs the policy's guardrails, then its path parameter patterns
     */
    public void enforce(CalloutBuilder callout, CalloutRequestSnapshot snapshot) {
        for (CalloutGuardrail guardrail : this.guardrails) {
            guardrail.enforce(callout);
        }
        if (this.regexByPathParameter.isEmpty()) {
            return;
        }
        Map<String, String> values = this.endpoint.toParameters(snapshot.getPath());
        for (String name : this.regexByPathParameter.keySet()) {
            if (!this.toPattern(this.regexByPathParameter.get(name)).matcher(values.get(name)).matches()) {
                throw snapshot.toException(
                    CalloutPolicyRule.PATH_PARAMETER,
                    'path parameter ' + name + ' does not match its pattern'
                );
            }
        }
    }

    private Boolean isMethodNamed(String method) {
        return this.methods.isEmpty() || this.methods.contains(method);
    }

    private Boolean areConditionsMet(CalloutBuilder callout) {
        for (CalloutCondition condition : this.conditions) {
            if (!condition.isMet(callout)) {
                return false;
            }
        }
        return true;
    }

    private Pattern toPattern(String regex) {
        Pattern compiled = PATTERN_BY_REGEX.get(regex);
        if (compiled == null) {
            compiled = Pattern.compile(regex);
            PATTERN_BY_REGEX.put(regex, compiled);
        }
        return compiled;
    }
}