/**
* @description Builds the guardrail chain for one Named Credential: the three
* built-in checks in fixed order — authentication, allowed method, allowed
* endpoint — then the custom CalloutGuardrail classes named in the
* configuration, in listed order.
* @team Laserburst
*/
public with sharing class GuardrailsFactory {
    public static List<CalloutGuardrail> create(String namedCredential) {
        return create(GuardedCalloutConfig.forName(namedCredential));
    }

    public static List<CalloutGuardrail> create(GuardedCalloutConfig config) {
        List<CalloutGuardrail> guardrails =
            new List<CalloutGuardrail>{
                new CalloutAuthenticationGuardrail(),
                new CalloutMethodGuardrail(),
                new CalloutEndpointGuardrail()
            };
        for (String className : config.guardrails) {
            guardrails.add(instantiate(className, config.namedCredential));
        }
        return guardrails;
    }

    private static CalloutGuardrail instantiate(String className, String namedCredential) {
        System.Type guardrailType = System.Type.forName(className);
        if (guardrailType == null) {
            throw new GuardrailsFactoryException(
                'Custom guardrail class "'
                + className
                + '" was not found. Check the "guardrails" list in the configuration for "'
                + namedCredential
                + '".'
            );
        }
        Object instance;
        try {
            instance = guardrailType.newInstance();
        } catch (Exception e) {
            throw new GuardrailsFactoryException(
                'Custom guardrail class "' + className + '" could not be instantiated: ' + e.getMessage()
            );
        }
        if (!(instance instanceof CalloutGuardrail)) {
            throw new GuardrailsFactoryException(
                'Custom guardrail class "' + className + '" must implement CalloutGuardrail.'
            );
        }
        return (CalloutGuardrail) instance;
    }

    @SuppressWarnings('PMD.ApexDoc')
    public class GuardrailsFactoryException extends Exception {
    }
}