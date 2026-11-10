/**
 * @description Specification for where a CalloutPolicy applies. Attach subclasses with CalloutPolicy.withCondition().
 * Do not execute or change the builder.
 * @team Laserburst
 */
public abstract class CalloutCondition {
    /**
     * @return true when the policy applies to this callout; must not execute or change the builder
     */
    public abstract Boolean isMet(CalloutBuilder callout);
}