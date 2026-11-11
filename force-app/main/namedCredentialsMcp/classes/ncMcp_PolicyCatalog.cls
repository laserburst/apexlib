/**
 * @description ncMcp_PolicyCatalog is what the Named Credentials MCP tools expose: a Named Credential is exposed when
 * a policy scoped callout:<name> names a method
 * @team Laserburst
 */
public with sharing class ncMcp_PolicyCatalog {
    public static final String NOT_EXPOSED = 'namedCredential is not exposed. Call listCredentials.';

    private static final String PERMISSION = 'Named_Credentials_MCP';
    private static final String NC_PREFIX = 'callout:';
    private static final String ANY_ENDPOINT = '/*';

    @TestVisible
    private static ncMcp_PolicyCatalog instance;

    private final List<CalloutPolicy> policies;
    private final Map<String, List<CalloutPolicy>> routePoliciesByName = new Map<String, List<CalloutPolicy>>();

    /**
     * @description getInstance throws ncMcp_ToolException when the user lacks the Named_Credentials_MCP custom
     * permission; otherwise it builds the catalog from ncMcp_DefaultPolicyFactory.forOrg() once per transaction
     */
    public static ncMcp_PolicyCatalog getInstance() {
        if (!FeatureManagement.checkPermission(PERMISSION)) {
            throw new ncMcp_ToolException('Named Credentials MCP is not enabled for this user');
        }
        if (instance == null) {
            instance = new ncMcp_PolicyCatalog(ncMcp_DefaultPolicyFactory.forOrg().getPolicies());
        }
        return instance;
    }

    /**
     * @description throws ncMcp_ToolException for a callout: scope with a path after the name, which the tools'
     * callouts never match, so its checks would never run
     */
    public ncMcp_PolicyCatalog(List<CalloutPolicy> policies) {
        this.policies = new List<CalloutPolicy>(policies);
        for (CalloutPolicy policy : policies) {
            String name = this.toCredentialName(policy);
            if (name != null && policy.isAllowing()) {
                this.addRoutePolicy(name, policy);
            }
        }
    }

    /**
     * @return the exposed Named Credential names, sorted
     */
    public List<String> getCredentialNames() {
        List<String> names = new List<String>(this.routePoliciesByName.keySet());
        names.sort();
        return names;
    }

    /**
     * @description toScope throws ncMcp_ToolException with NOT_EXPOSED for a name that isn't exposed
     * @return the scope that the name's policies match, callout:<name>
     */
    public String toScope(String name) {
        this.enforceExposed(name);
        return NC_PREFIX + name;
    }

    /**
     * @description getMethodsByEndpoint throws ncMcp_ToolException with NOT_EXPOSED for a name that isn't exposed
     * @return the methods each endpoint pattern allows; a policy without an endpoint shows as /*
     */
    public Map<String, Set<String>> getMethodsByEndpoint(String name) {
        this.enforceExposed(name);
        Map<String, Set<String>> methodsByEndpoint = new Map<String, Set<String>>();
        for (CalloutPolicy policy : this.routePoliciesByName.get(name)) {
            String endpoint = policy.getEndpoint() ?? ANY_ENDPOINT;
            if (!methodsByEndpoint.containsKey(endpoint)) {
                methodsByEndpoint.put(endpoint, new Set<String>());
            }
            methodsByEndpoint.get(endpoint).addAll(policy.getMethods());
        }
        return methodsByEndpoint;
    }

    /**
     * @return a copy, in the order the factory supplied them
     */
    public List<CalloutPolicy> getPolicies() {
        return new List<CalloutPolicy>(this.policies);
    }

    private void enforceExposed(String name) {
        if (!this.routePoliciesByName.containsKey(name)) {
            throw new ncMcp_ToolException(NOT_EXPOSED);
        }
    }

    // null for a scope that isn't a Named Credential
    private String toCredentialName(CalloutPolicy policy) {
        String scope = policy.getNcOrBaseUrl().removeEnd('/');
        if (!scope.startsWith(NC_PREFIX)) {
            return null;
        }
        String name = scope.removeStart(NC_PREFIX);
        if (name.contains('/')) {
            throw new ncMcp_ToolException('Policy scope ' + scope + ' has a path; use callout:<name> and endpoints');
        }
        return name;
    }

    private void addRoutePolicy(String name, CalloutPolicy policy) {
        if (!this.routePoliciesByName.containsKey(name)) {
            this.routePoliciesByName.put(name, new List<CalloutPolicy>());
        }
        this.routePoliciesByName.get(name).add(policy);
    }
}