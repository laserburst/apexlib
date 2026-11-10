/**
 * @description CalloutPolicyRule is the rule a CalloutPolicyException reports, for audit and for replies to an agent
 * @team Laserburst
 */
public enum CalloutPolicyRule {
    /**
     * no allowing policy matches the path
     */
    NO_ROUTE,
    /**
     * the route's policies don't allow the method, or their conditions aren't met
     */
    METHOD,
    /**
     * the path breaks the path rule
     */
    PATH,
    /**
     * a {name} value doesn't match its path parameter pattern
     */
    PATH_PARAMETER,
    /**
     * a header isn't granted, or is set in two cases
     */
    HEADER,
    /**
     * a header or the body has a formula that isn't granted
     */
    FORMULA,
    /**
     * a query parameter isn't granted, appears twice, or the query has ";"
     */
    QUERY_PARAMETER,
    /**
     * a form field overrides the method
     */
    METHOD_OVERRIDE,
    /**
     * a Blob body isn't granted
     */
    BLOB_BODY
}