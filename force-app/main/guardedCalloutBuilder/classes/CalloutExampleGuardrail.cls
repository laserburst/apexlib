/**
 * @description Reference implementation of a custom CalloutGuardrail. To activate
 * it, add "CalloutExampleGuardrail" to the "guardrails" list in a Named Credentials
 * Configuration record. It blocks any request whose body appears to contain a
 * credential, keeping a caller from forwarding secrets to an external API — a
 * check that cannot be expressed with the declarative method/endpoint rules.
 * Copy this class as a starting point for your own guardrails.
 * @team Laserburst
 */
public with sharing class CalloutExampleGuardrail implements CalloutGuardrail {
    private static final Set<String> SENSITIVE_TOKENS = new Set<String>{ 'password', 'secret', 'session_id' };

    public void enforce(GuardedCalloutBuilder builder) {
        if (String.isBlank(builder.getBody())) {
            return;
        }
        String body = builder.getBody().toLowerCase();
        for (String token : SENSITIVE_TOKENS) {
            if (body.contains(token)) {
                throw new GuardedCalloutException(
                    'Request blocked by CalloutExampleGuardrail: the request body appears to contain a credential ("' +
                        token +
                        '").'
                );
            }
        }
    }
}