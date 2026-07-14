/**
* @description Strategy for a single guardrail check applied to an outgoing
* request before it leaves the org. Implement this interface and add the class
* name to the "guardrails" list in a Named Credentials Configuration record to
* enforce custom rules. See CalloutExampleGuardrail for a reference.
* @team Laserburst
*/
public interface CalloutGuardrail {
    /**
    * @description Inspect the guarded builder and throw GuardedCalloutException
    * to block the request. Return normally to allow it. The builder exposes the
    * request through read accessors (getMethod, getPath, getHeaders, getBody,
    * getConfig, ...); do not execute it. The thrown message is surfaced to the
    * caller, so make it actionable.
    * @param builder the guarded callout about to be sent, including its resolved config
    */
    void enforce(GuardedCalloutBuilder builder);
}