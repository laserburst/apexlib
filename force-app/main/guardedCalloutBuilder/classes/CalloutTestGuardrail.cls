/**
* @description Test fixture: a custom guardrail the "GuardedTest_Guarded"
* configuration record names, so tests can exercise config-driven guardrails.
* Must stay public and top-level — GuardrailsFactory resolves it by name.
* @team Laserburst
*/
@IsTest
public class CalloutTestGuardrail implements CalloutGuardrail {
    public void enforce(CalloutBuilder builder) {
        String body = ((GuardedCalloutBuilder) builder).getInspectableBody();
        if (String.isNotBlank(body) && body.containsIgnoreCase('password')) {
            throw new CalloutGuardrailException('Request blocked by CalloutTestGuardrail.');
        }
    }
}
