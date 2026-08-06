/**
* @description Strategy for a single check applied to a callout before the
* request is constructed. Attach implementations with
* CalloutBuilder.withGuardrails().
* @team Laserburst
*/
public interface CalloutGuardrail {
    /**
    * @description Inspect the builder and throw to block the callout. Return
    * normally to allow it. The builder exposes the request through its read
    * accessors (getMethod, getEndpoint, getHeaders, getQueryParameters, ...);
    * do not execute it. The thrown message is surfaced to the caller, so make
    * it actionable.
    * @param builder the callout about to be sent
    */
    void enforce(CalloutBuilder builder);
}