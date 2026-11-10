/**
 * @description CalloutGrants is what policies allow a callout to send. Nothing is allowed until it is granted,
 * and grants from several policies add up.
 * @team Laserburst
 */
public class CalloutGrants {
    private final Set<String> lowerCaseHeaders = new Set<String>();
    private final Set<String> queryParameters = new Set<String>();
    private final Set<String> formulaHeaderLines = new Set<String>();
    private Boolean blobBodies = false;
    private Boolean errorBodies = false;

    public void addHeaders(Set<String> names) {
        for (String name : names) {
            this.lowerCaseHeaders.add(name.toLowerCase());
        }
    }

    public void addQueryParameters(Set<String> names) {
        this.queryParameters.addAll(names);
    }

    public void addHeaderFormula(String name, String formula) {
        this.formulaHeaderLines.add(this.toHeaderLine(name, formula));
    }

    public void allowBlobBodies() {
        this.blobBodies = true;
    }

    public void allowErrorBodies() {
        this.errorBodies = true;
    }

    public void addAll(CalloutGrants other) {
        this.lowerCaseHeaders.addAll(other.lowerCaseHeaders);
        this.queryParameters.addAll(other.queryParameters);
        this.formulaHeaderLines.addAll(other.formulaHeaderLines);
        this.blobBodies |= other.blobBodies;
        this.errorBodies |= other.errorBodies;
    }

    public Boolean allowsErrorBodies() {
        return this.errorBodies;
    }

    /**
     * @description enforce throws CalloutPolicyException when the request sends a header, a query parameter or
     * a Blob body that isn't granted, or a header formula whose exact value isn't granted
     */
    public void enforce(CalloutRequestSnapshot snapshot) {
        Map<String, String> headers = snapshot.getHeaders();
        for (String name : headers.keySet()) {
            String value = headers.get(name);
            Boolean formulaGranted = this.formulaHeaderLines.contains(this.toHeaderLine(name, value));
            if (!formulaGranted && !this.lowerCaseHeaders.contains(name.toLowerCase())) {
                throw snapshot.toException(CalloutPolicyRule.HEADER, 'header ' + name + ' is not granted');
            }
            if (!formulaGranted && CalloutRequestSnapshot.isFormula(value)) {
                throw snapshot.toException(CalloutPolicyRule.FORMULA, 'header ' + name + ' has a formula');
            }
        }
        for (String name : snapshot.getQueryParameterNames()) {
            if (!this.queryParameters.contains(name)) {
                throw snapshot.toException(
                    CalloutPolicyRule.QUERY_PARAMETER,
                    'query parameter ' + name + ' is not granted'
                );
            }
        }
        if (snapshot.isBlobBody() && !this.blobBodies) {
            throw snapshot.toException(CalloutPolicyRule.BLOB_BODY, 'Blob body is not granted');
        }
    }

    // a header name can't contain ":", so the line is unambiguous
    private String toHeaderLine(String name, String value) {
        return name.toLowerCase() + ':' + value;
    }
}