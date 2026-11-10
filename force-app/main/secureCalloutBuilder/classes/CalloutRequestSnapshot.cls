/**
 * @description CalloutRequestSnapshot is what a CalloutBuilder sends after its base URL, read once, so routing and
 * every check see the same request: the method, the path decoded once, the query, the headers and the body.
 * It applies the fixed rules, which no policy can lift.
 * @team Laserburst
 */
public class CalloutRequestSnapshot {
    private static final Set<String> METHOD_OVERRIDE_FIELDS =
        new Set<String>{ '_method', '_httpmethod', 'x-http-method-override' };
    private static final String FORM_MEDIA_TYPE = 'application/x-www-form-urlencoded';
    private static final String FORMULA_START = '{!';
    private static final String ENCODING = 'UTF-8';
    private static final String REPLACEMENT_CHARACTER = String.fromCharArray(new List<Integer>{ 65533 });

    private final String method;
    private final String baseUrl;
    private final String rawPath;
    private final String path;
    private final String query;
    private final List<String> urlQueryNames;
    private final Map<String, String> headers;
    private final String body;
    private final String mediaType;
    private final Boolean querySentAsBody;
    private final Boolean hasBlobBody;

    /**
     * @description throws CalloutPolicyException (PATH) when the path breaks the path rule
     */
    public CalloutRequestSnapshot(CalloutBuilder callout) {
        this.method = callout.getMethod()?.toUpperCase();
        this.baseUrl = (callout.getNcOrBaseUrl() ?? '').removeEnd('/');
        String afterBaseUrl = callout.constructFullEndpoint().substring(this.baseUrl.length());
        this.rawPath = afterBaseUrl.substringBefore('?');
        this.path = this.toDecodedPath();
        this.query = this.toQuery(afterBaseUrl);
        this.urlQueryNames = this.toFieldNames(this.query);
        this.headers = callout.getHeaders();
        this.body = callout.getBodyAsString();
        this.mediaType = callout.getContentType()?.substringBefore(';').trim().toLowerCase();
        this.querySentAsBody = callout.isQuerySentAsBody();
        this.hasBlobBody = callout.isBlobBody();
    }

    /**
     * @return the method in upper case
     */
    public String getMethod() {
        return this.method;
    }

    /**
     * @return the base URL without a trailing "/"
     */
    public String getBaseUrl() {
        return this.baseUrl;
    }

    /**
     * @return the path decoded once, with "+" kept; "/" for the empty path
     */
    public String getPath() {
        return this.path;
    }

    public Map<String, String> getHeaders() {
        return new Map<String, String>(this.headers);
    }

    /**
     * @return the decoded names in the URL query, and in the body when the query parameters are sent as the body
     */
    public List<String> getQueryParameterNames() {
        List<String> names = new List<String>(this.urlQueryNames);
        if (this.querySentAsBody) {
            names.addAll(this.toFieldNames(this.body));
        }
        return names;
    }

    public Boolean isBlobBody() {
        return this.hasBlobBody;
    }

    /**
     * @description enforceFixedRules throws CalloutPolicyException for what no policy can grant: a header set in two
     * cases, a ";" or a repeated name in the URL query, a method override field in a form body, or a body formula
     */
    public void enforceFixedRules() {
        this.enforceHeaders();
        this.enforceQuery();
        this.enforceBody();
    }

    /**
     * @return a CalloutPolicyException whose message names the method and the path as sent, never a value
     */
    public CalloutPolicyException toException(CalloutPolicyRule rule, String reason) {
        String shownPath = this.rawPath;
        if (String.isEmpty(shownPath)) {
            shownPath = '/';
        }
        return new CalloutPolicyException(rule, this.method + ' ' + shownPath + ': ' + reason);
    }

    /**
     * @description isFormula is true for text with a Named Credential formula, such as {!$Credential.Token}
     */
    public static Boolean isFormula(String text) {
        return text?.contains(FORMULA_START) == true;
    }

    // the path rule: split before decoding, so an encoded "/" stays in its segment and is blocked
    private String toDecodedPath() {
        List<String> segments = new List<String>();
        String trimmed = this.rawPath.removeEnd('/');
        if (String.isNotEmpty(trimmed)) {
            for (String rawSegment : trimmed.removeStart('/').split('/', -1)) {
                String segment = this.toDecodedSegment(rawSegment);
                if (segment == null || CalloutEndpointPattern.isBlockedSegment(segment)) {
                    throw this.toException(CalloutPolicyRule.PATH, 'path is not allowed');
                }
                segments.add(segment);
            }
        }
        return '/' + String.join(segments, '/');
    }

    // null when the segment has a bad escape or isn't UTF-8; urlDecode() reads "+" as a space
    private String toDecodedSegment(String rawSegment) {
        String segment;
        try {
            segment = EncodingUtil.urlDecode(rawSegment.replace('+', '%2B'), ENCODING);
        } catch (StringException e) {
            return null;
        }
        if (segment.contains(REPLACEMENT_CHARACTER)) {
            return null;
        }
        return segment;
    }

    private String toQuery(String afterBaseUrl) {
        if (!afterBaseUrl.contains('?')) {
            return null;
        }
        return afterBaseUrl.substringAfter('?');
    }

    // CB sends the first spelling it finds, and the server may read the other
    private void enforceHeaders() {
        Set<String> lowerCaseNames = new Set<String>();
        for (String name : this.headers.keySet()) {
            if (!lowerCaseNames.add(name.toLowerCase())) {
                throw this.toException(CalloutPolicyRule.HEADER, 'header ' + name + ' is set in two cases');
            }
        }
    }

    // a server may split the query at ";", or read either value of a repeated name
    private void enforceQuery() {
        if (this.query?.contains(';') == true) {
            throw this.toException(CalloutPolicyRule.QUERY_PARAMETER, 'query has ";"');
        }
        Set<String> lowerCaseNames = new Set<String>();
        for (String name : this.urlQueryNames) {
            if (!lowerCaseNames.add(name.toLowerCase())) {
                throw this.toException(CalloutPolicyRule.QUERY_PARAMETER, 'query parameter ' + name + ' appears twice');
            }
        }
    }

    // a Named Credential that allows formulas in the body would fill in a secret, and a server that reads a method
    // override field would run another method than the one routed
    private void enforceBody() {
        if (isFormula(this.body)) {
            throw this.toException(CalloutPolicyRule.FORMULA, 'body has a formula');
        }
        if (!this.isFormBody()) {
            return;
        }
        for (String name : this.toFieldNames(this.body)) {
            if (METHOD_OVERRIDE_FIELDS.contains(name.toLowerCase())) {
                throw this.toException(
                    CalloutPolicyRule.METHOD_OVERRIDE,
                    'form field ' + name + ' overrides the method'
                );
            }
        }
    }

    private Boolean isFormBody() {
        return this.querySentAsBody || this.mediaType == FORM_MEDIA_TYPE;
    }

    private List<String> toFieldNames(String form) {
        List<String> names = new List<String>();
        if (form == null) {
            return names;
        }
        for (String field : form.split('&')) {
            if (String.isNotEmpty(field)) {
                names.add(this.toDecodedName(field.substringBefore('=')));
            }
        }
        return names;
    }

    // an undecodable name is kept as sent, so no grant matches it
    private String toDecodedName(String name) {
        try {
            return EncodingUtil.urlDecode(name, ENCODING);
        } catch (StringException e) {
            return name;
        }
    }
}