/**
* @description Builds the guardrail chain for one Named Credential: the three
* built-in checks in fixed order — authentication, allowed method, allowed
* endpoint — then the custom CalloutGuardrail classes named in the
* configuration, in listed order.
* @team Laserburst
*/
public with sharing class GuardrailsFactory {
    private final GuardedCalloutConfig config;

    public GuardrailsFactory(GuardedCalloutConfig config) {
        this.config = config;
    }

    public List<CalloutGuardrail> create() {
        List<CalloutGuardrail> guardrails =
            new List<CalloutGuardrail>{
                new CalloutAuthenticationGuardrail(),
                new CalloutMethodGuardrail(),
                new CalloutEndpointGuardrail()
            };
        for (String className : this.config.guardrails) {
            guardrails.add(this.instantiate(className));
        }
        return guardrails;
    }

    private CalloutGuardrail instantiate(String className) {
        System.Type guardrailType = System.Type.forName(className);
        if (guardrailType == null) {
            throw new GuardedCalloutException(
                'Custom guardrail class "'
                + className
                + '" was not found. Check the "guardrails" list in the configuration for "'
                + this.config.namedCredential
                + '".'
            );
        }
        Object instance;
        try {
            instance = guardrailType.newInstance();
        } catch (Exception e) {
            throw new GuardedCalloutException(
                'Custom guardrail class "' + className + '" could not be instantiated: ' + e.getMessage()
            );
        }
        if (!(instance instanceof CalloutGuardrail)) {
            throw new GuardedCalloutException(
                'Custom guardrail class "' + className + '" must implement CalloutGuardrail.'
            );
        }
        return (CalloutGuardrail) instance;
    }
}