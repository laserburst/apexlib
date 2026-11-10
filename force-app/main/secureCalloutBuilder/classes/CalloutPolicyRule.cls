/**
 * @description CalloutPolicyRule is the rule a CalloutPolicyException reports, for audit and for replies to an agent
 * @team Laserburst
 */
public enum CalloutPolicyRule {
    NO_ROUTE,
    METHOD,
    PATH,
    PATH_PARAMETER,
    HEADER,
    FORMULA,
    QUERY_PARAMETER,
    METHOD_OVERRIDE,
    BLOB_BODY
}