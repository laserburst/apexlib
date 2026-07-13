/**
 * @description Built-in guardrail: allows only the HTTP methods listed in the
 * configuration's allowedMethods (defaults to GET only).
 * @team Laserburst
 */
public with sharing class ncMcp_MethodGuardrail implements ncMcp_Guardrail {
    public void enforce(ncMcp_GuardedCalloutBuilder builder) {
        List<String> allowed = builder.getConfig().allowedMethods;
        if (!allowed.contains(builder.getMethod())) {
            throw new ncMcp_Exception(
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
