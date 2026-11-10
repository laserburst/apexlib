@IsTest
private class CalloutGrants_Test {
    private static final String ALLOWED = 'allowed';
    private static final String FORMULA = '{!$Credential.Token}';

    @IsTest
    static void testEnforce() {
        CalloutGrants grants = new CalloutGrants();
        grants.addHeaders(new Set<String>{ 'Accept' });
        grants.addHeaderFormula('Authorization', FORMULA);
        grants.addQueryParameters(new Set<String>{ 'expand' });
        CalloutGrants blobGrants = new CalloutGrants();
        blobGrants.allowBlobBodies();
        Map<String, CalloutBuilder> calloutByCase =
            new Map<String, CalloutBuilder>{
                'granted' => toCallout('GET')
                    .withHeader('ACCEPT', '*/*')
                    .withHeader('Authorization', FORMULA)
                    .withQueryParameter('expand', 'a'),
                'ungranted header' => toCallout('GET').withHeader('X-Trace', 'secret'),
                'formula in a granted header' => toCallout('GET').withHeader('Accept', FORMULA),
                'formula with another value' => toCallout('GET').withHeader('Authorization', '{!$Credential.X}'),
                'ungranted query parameter' => toCallout('GET').withQueryParameter('Expand', 'a'),
                'Blob body' => toCallout('POST').withBlobBody(Blob.valueOf('secret'))
            };
        Map<String, String> expectedByCase =
            new Map<String, String>{
                'granted' => ALLOWED,
                'ungranted header' => '[HEADER] GET /items: header X-Trace is not granted',
                'formula in a granted header' => '[FORMULA] GET /items: header Accept has a formula',
                'formula with another value' => '[HEADER] GET /items: header Authorization is not granted',
                'ungranted query parameter' => '[QUERY_PARAMETER] GET /items: query parameter Expand is not granted',
                'Blob body' => '[BLOB_BODY] POST /items: Blob body is not granted'
            };
        CalloutBuilder blobWithHeader = toCallout('POST').withHeader('Accept', 'a').withBlobBody(Blob.valueOf('x'));

        Test.startTest();
        Map<String, String> outcomeByCase = new Map<String, String>();
        for (String testCase : calloutByCase.keySet()) {
            outcomeByCase.put(testCase, toOutcome(grants, calloutByCase.get(testCase)));
        }
        CalloutGrants combined = new CalloutGrants();
        combined.addAll(grants);
        combined.addAll(blobGrants);
        String combinedOutcome = toOutcome(combined, blobWithHeader);
        Test.stopTest();

        Assert.areEqual(expectedByCase, outcomeByCase, 'Nothing should be allowed until it is granted');
        Assert.areEqual(ALLOWED, combinedOutcome, 'Grants should add up');
    }

    private static CalloutBuilder toCallout(String method) {
        return new CalloutBuilder('callout:Api').withMethod(method).withEndpoint('/items');
    }

    private static String toOutcome(CalloutGrants grants, CalloutBuilder callout) {
        try {
            grants.enforce(new CalloutRequestSnapshot(callout));
            return ALLOWED;
        } catch (CalloutPolicyException e) {
            return '[' + e.rule + '] ' + e.getMessage();
        }
    }
}