/**
 * @description ncMcp_CalloutPolicies supplies one API's policies to the Named Credentials MCP tools. The default
 * policy factory finds and applies every public implementation, in production too, including one inside a public
 * test class: declare test classes private. An implementation needs a public no-argument constructor. Rule-only
 * policies apply only when their class is found, so keep them in the same class as the API's routes.
 * @team Laserburst
 */
public interface ncMcp_CalloutPolicies {
    /**
     * @return policies scoped callout:<Named Credential>, without a path after the name
     */
    List<CalloutPolicy> getPolicies();
}