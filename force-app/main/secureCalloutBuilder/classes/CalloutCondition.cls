/**
 * @description Specification for where a CalloutPolicy applies. Attach subclasses with CalloutPolicy.withCondition().
 * Do not execute or change the builder.
 * @team Laserburst
 */
public abstract class CalloutCondition {
    public abstract Boolean isMet(CalloutBuilder callout);
}