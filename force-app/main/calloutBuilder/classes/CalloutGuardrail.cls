/**
* @description Strategy for a single check applied to a callout before the
* request is constructed. Attach implementations with
* CalloutBuilder.withGuardrails().
* @team Laserburst
*/
public interface CalloutGuardrail {
    /**
    * @description Throw to block the callout, return to allow it.
    * Do not execute the builder.
    * @param builder the callout about to be sent
    */
    void enforce(CalloutBuilder builder);
}