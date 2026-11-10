/**
 * @description Thrown when the policies block a callout, before anything is sent. The message names the method,
 * the path and the offending name, and never a header value, a body, a pattern or a granted list.
 * @team Laserburst
 */
public class CalloutPolicyException extends CalloutGuardrailException {
    /**
     * @description rule is the rule that blocked the callout
     */
    public final CalloutPolicyRule rule;

    /**
     * @param message names the method, the path and the offending name, never a value
     */
    public CalloutPolicyException(CalloutPolicyRule rule, String message) {
        this.rule = rule;
        this.setMessage(message);
    }
}