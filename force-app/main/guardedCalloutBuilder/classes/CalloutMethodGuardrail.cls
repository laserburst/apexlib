/**
* @description Built-in guardrail: allows only the HTTP methods listed in the
* configuration's allowedMethods (defaults to GET only).
* @team Laserburst
*/
public with sharing class CalloutMethodGuardrail implements CalloutGuardrail {
    public void enforce(CalloutBuilder builder) {
        GuardedCalloutBuilder guarded = (GuardedCalloutBuilder) builder;
        List<String> allowed = guarded.getConfig().allowedMethods;
        if (!allowed.contains(guarded.getMethod())) {
            throw new GuardedCalloutException(
                'HTTP method "'
                + guarded.getMethod()
                + '" is not allowed for "'
                + guarded.getConfig().namedCredential
                + '". Allowed methods: '
                + String.join(allowed, ', ')
                + '.'
            );
        }
    }
}