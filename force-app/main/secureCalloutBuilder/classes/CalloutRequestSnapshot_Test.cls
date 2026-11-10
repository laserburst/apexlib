@IsTest
private class CalloutRequestSnapshot_Test {
    private static final String API = 'callout:Api';
    private static final String ALLOWED = 'allowed';

    @IsTest
    static void testConstructor() {
        Map<String, String> expectedByEndpoint =
            new Map<String, String>{
                '/v1/%61dmin/x' => '/v1/admin/x',
                '/a+b%20c' => '/a+b c',
                '/items/' => '/items',
                '?q=1' => '/'
            };
        CalloutBuilder patch = new CalloutBuilder(API + '/').withMethod('patch');

        Test.startTest();
        Map<String, String> pathByEndpoint = new Map<String, String>();
        for (String endpoint : expectedByEndpoint.keySet()) {
            pathByEndpoint.put(endpoint, new CalloutRequestSnapshot(toCallout('GET', endpoint)).getPath());
        }
        CalloutRequestSnapshot snapshot = new CalloutRequestSnapshot(patch);
        Test.stopTest();

        Assert.areEqual(expectedByEndpoint, pathByEndpoint, 'The path should be decoded once, with "+" kept');
        Assert.areEqual('PATCH', snapshot.getMethod(), 'The method should be in upper case');
        Assert.areEqual(API, snapshot.getBaseUrl(), 'The base URL should lose its trailing "/"');
    }

    @IsTest
    static void testPathRule() {
        List<String> endpoints =
            new List<String>{
                '/items//5',
                '/items/a;b',
                '/items/5%2Fpurge',
                '/items/%252e%252e',
                '/items/%zz',
                '/items/%C3'
            };
        Map<String, String> expectedByEndpoint = new Map<String, String>();
        for (String endpoint : endpoints) {
            expectedByEndpoint.put(endpoint, '[PATH] GET ' + endpoint + ': path is not allowed');
        }

        Test.startTest();
        Map<String, String> outcomeByEndpoint = new Map<String, String>();
        for (String endpoint : endpoints) {
            outcomeByEndpoint.put(endpoint, toOutcome(toCallout('GET', endpoint)));
        }
        Test.stopTest();

        Assert.areEqual(expectedByEndpoint, outcomeByEndpoint, 'Each path should break the path rule');
    }

    @IsTest
    static void testGetQueryParameterNames() {
        CalloutBuilder inUrl = toCallout('GET', '/items?a=1').withQueryParameter('b c', '2');
        CalloutBuilder inBody = toCallout('POST', '/items').withQueryParameter('x', '1');

        Test.startTest();
        List<String> urlNames = new CalloutRequestSnapshot(inUrl).getQueryParameterNames();
        List<String> bodyNames = new CalloutRequestSnapshot(inBody).getQueryParameterNames();
        Test.stopTest();

        Assert.areEqual(new List<String>{ 'a', 'b c' }, urlNames, 'The URL names should be decoded');
        Assert.areEqual(new List<String>{ 'x' }, bodyNames, 'Query parameters sent as the body should count');
    }

    @IsTest
    static void testEnforce() {
        Map<String, CalloutBuilder> calloutByCase =
            new Map<String, CalloutBuilder>{
                'allowed' => toCallout('GET', '/items?a=1').withHeader('Accept', '*/*'),
                'header in two cases' => new CalloutBuilder(API).withHeader('Accept', 'a').withHeader('accept', 'b'),
                'query with ;' => toCallout('GET', '/items?a=1;b'),
                'repeated query parameter' => toCallout('GET', '/items?a=1').withQueryParameter('A', '2'),
                'formula in the body' => toCallout('POST', '/items')
                    .withHeader('Content-Type', 'text/plain')
                    .withBody('{!$Credential.Token}'),
                'method override in a form' => toCallout('POST', '/items')
                    .withHeader('Content-Type', 'application/x-www-form-urlencoded')
                    .withBody(new Map<String, Object>{ '_Method' => 'DELETE' }),
                'method override as the query' => toCallout('POST', '/items')
                    .withQueryParameter('X-HTTP-Method-Override', 'DELETE')
            };
        Map<String, String> expectedByCase =
            new Map<String, String>{
                'allowed' => ALLOWED,
                'header in two cases' => '[HEADER] GET /: header accept is set in two cases',
                'query with ;' => '[QUERY_PARAMETER] GET /items: query has ";"',
                'repeated query parameter' => '[QUERY_PARAMETER] GET /items: query parameter A appears twice',
                'formula in the body' => '[FORMULA] POST /items: body has a formula',
                'method override in a form' => '[METHOD_OVERRIDE] POST /items: form field _Method overrides the method',
                'method override as the query' => '[METHOD_OVERRIDE] POST /items: form field X-HTTP-Method-Override overrides the method'
            };

        Test.startTest();
        Map<String, String> outcomeByCase = new Map<String, String>();
        for (String testCase : calloutByCase.keySet()) {
            outcomeByCase.put(testCase, toOutcome(calloutByCase.get(testCase)));
        }
        Test.stopTest();

        Assert.areEqual(expectedByCase, outcomeByCase, 'Each fixed rule should block with its rule and no values');
    }

    private static CalloutBuilder toCallout(String method, String endpoint) {
        return new CalloutBuilder(API).withMethod(method).withEndpoint(endpoint);
    }

    private static String toOutcome(CalloutBuilder callout) {
        try {
            new CalloutRequestSnapshot(callout).enforceFixedRules();
            return ALLOWED;
        } catch (CalloutPolicyException e) {
            return '[' + e.rule + '] ' + e.getMessage();
        }
    }
}