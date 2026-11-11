/**
 * @description ncMcp_PolicyFactory supplies every policy the Named Credentials MCP tools apply. One public class that
 * implements it replaces ncMcp_DefaultPolicyFactory; a second one makes every tool throw. An implementation inside a
 * public test class counts too: declare test classes private.
 * @team Laserburst
 */
public interface ncMcp_PolicyFactory {
    /**
     * @return policies scoped callout:<Named Credential>, without a path after the name
     */
    List<CalloutPolicy> getPolicies();
}