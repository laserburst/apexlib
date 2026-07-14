/**
 * @description Built-in guardrail: allows only the HTTP methods listed in the
 * configuration's allowedMethods (defaults to GET only).
 * @team Laserburst
 */
public with sharing class CalloutMethodGuardrail implements CalloutGuardrail {
    public void enforce(GuardedCalloutBuilder builder) {
        List<String> allowed = builder.getConfig().allowedMethods;
        if (!allowed.contains(builder.getMethod())) {
            throw new GuardedCalloutException(
                'HTTP method "' +
                    builder.getMethod() +
                    '" is not allowed for "' +
                    builder.getNamedCredential() +
                    '". Allowed methods: ' +
                    String.join(allowed, ', ') +
                    '.'
            );
        }
    }
}