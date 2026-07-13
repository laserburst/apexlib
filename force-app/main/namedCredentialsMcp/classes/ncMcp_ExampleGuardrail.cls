/**
 * @description Reference implementation of a custom ncMcp_Guardrail. To activate
 * it, add "ncMcp_ExampleGuardrail" to the "guardrails" list in a Named Credentials
 * Configuration record. It blocks any request whose body appears to contain a
 * credential, keeping an agent from forwarding secrets to an external API — a
 * check that cannot be expressed with the declarative method/endpoint rules.
 * Copy this class as a starting point for your own guardrails.
 * @team Laserburst
 */
public with sharing class ncMcp_ExampleGuardrail implements ncMcp_Guardrail {
    private static final Set<String> SENSITIVE_TOKENS = new Set<String>{ 'password', 'secret', 'session_id' };

    public void enforce(ncMcp_GuardedCalloutBuilder builder) {
        if (String.isBlank(builder.getBody())) {
            return;
        }
        String body = builder.getBody().toLowerCase();
        for (String token : SENSITIVE_TOKENS) {
            if (body.contains(token)) {
                throw new ncMcp_Exception(
                    'Request blocked by ncMcp_ExampleGuardrail: the request body appears to contain a credential ("' +
                        token +
                        '").'
                );
            }
        }
    }
}
