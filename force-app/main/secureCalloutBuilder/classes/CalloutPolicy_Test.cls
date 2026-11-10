@IsTest
private class CalloutPolicy_Test {
    private static final String API = 'callout:Api';
    private static final String ALLOWED = 'allowed';

    @IsTest
    static void testIsApplicable() {
        CalloutPolicy policy =
            new CalloutPolicy(API + '/')
                .withMethod('get')
                .withEndpoint('/items/{id}')
                .withCondition(new FixedCondition(true));
        CalloutPolicy unmet = new CalloutPolicy(API).withCondition(new FixedCondition(false));
        Map<String, Boolean> expectedByRequest =
            new Map<String, Boolean>{ 'GET /items/5' => true, 'POST /items/5' => false, 'GET /items' => false };
        CalloutBuilder otherApi = new CalloutBuilder('callout:Other').withEndpoint('/items/5');

        Test.startTest();
        Map<String, Boolean> applicableByRequest = new Map<String, Boolean>();
        for (String request : expectedByRequest.keySet()) {
            applicableByRequest.put(request, policy.isApplicable(toCallout(request)));
        }
        Boolean appliesToOtherApi = policy.isApplicable(otherApi);
        Boolean appliesWithUnmetCondition = unmet.isApplicable(toCallout('GET /items/5'));
        Test.stopTest();

        Assert.areEqual(expectedByRequest, applicableByRequest, 'The method and the endpoint should both match');
        Assert.isFalse(appliesToOtherApi, 'A policy should apply to its own base URL only');
        Assert.isFalse(appliesWithUnmetCondition, 'Every condition should be met');
        Assert.areEqual(new Set<String>{ 'GET' }, policy.getMethods(), 'Methods should be kept in upper case');
    }

    @IsTest
    static void testGetGrants() {
        CalloutPolicy policy =
            new CalloutPolicy(API)
                .withAllowedHeaders(new Set<String>{ 'Accept' })
                .withAllowedQueryParameters(new Set<String>{ 'expand' })
                .withHeaderFormula('Authorization', '{!$Credential.Token}')
                .withBlobBodies();
        CalloutBuilder callout =
            toCallout('PUT /files/5')
                .withHeader('Accept', '*/*')
                .withHeader('Authorization', '{!$Credential.Token}')
                .withQueryParameter('expand', 'a')
                .withBlobBody(Blob.valueOf('x'));

        Test.startTest();
        Exception error;
        try {
            policy.getGrants().enforce(new CalloutRequestSnapshot(callout));
        } catch (CalloutPolicyException e) {
            error = e;
        }
        Test.stopTest();

        Assert.isNull(error, 'Each grant setter should reach the grants');
    }

    @IsTest
    static void testRejectsInvalidSetup() {
        String scope = 'Policy scope must be a base URL without "?", "#" or whitespace';
        String placeholder = 'Policy endpoint has no {id} placeholder';
        Map<String, String> expectedBySetup =
            new Map<String, String>{
                'blank scope' => scope,
                'scope with a query' => scope,
                'scope with whitespace' => scope,
                'pattern for an unknown name' => placeholder,
                'pattern without an endpoint' => placeholder,
                'second endpoint' => 'Policy endpoint is already set'
            };

        Test.startTest();
        Map<String, String> errorBySetup = new Map<String, String>();
        for (String setup : expectedBySetup.keySet()) {
            errorBySetup.put(setup, toSetupError(setup));
        }
        Test.stopTest();

        Assert.areEqual(expectedBySetup, errorBySetup, 'Each invalid setup should throw its own message');
    }

    @IsTest
    static void testCompareTo() {
        List<CalloutPolicy> policies =
            new List<CalloutPolicy>{
                new CalloutPolicy(API).withMethod('GET'),
                new CalloutPolicy(API).withEndpoint('/items/*')
            };

        Test.startTest();
        policies.sort();
        Test.stopTest();

        List<String> endpoints = new List<String>();
        for (CalloutPolicy policy : policies) {
            endpoints.add(policy.getEndpoint());
        }
        Assert.areEqual(
            new List<String>{ '/items/*', null },
            endpoints,
            'A policy without an endpoint should rank last'
        );
    }

    @IsTest
    static void testEnforce() {
        CalloutPolicy policy =
            new CalloutPolicy(API)
                .withEndpoint('/items/{id}')
                .withPathParameterPattern('id', '[0-9]+')
                .withGuardrails(new List<CalloutGuardrail>{ new BlockingGuardrail('X-Block') });
        Map<String, CalloutBuilder> calloutByCase =
            new Map<String, CalloutBuilder>{
                'matching value' => toCallout('GET /items/5'),
                'value that does not match' => toCallout('GET /items/abc'),
                'guardrail first' => toCallout('GET /items/abc').withHeader('X-Block', 'yes')
            };
        Map<String, String> expectedByCase =
            new Map<String, String>{
                'matching value' => ALLOWED,
                'value that does not match' => '[PATH_PARAMETER] GET /items/abc: path parameter id does not match its pattern',
                'guardrail first' => 'X-Block is set'
            };

        Test.startTest();
        Map<String, String> outcomeByCase = new Map<String, String>();
        for (String testCase : calloutByCase.keySet()) {
            outcomeByCase.put(testCase, toOutcome(policy, calloutByCase.get(testCase)));
        }
        Test.stopTest();

        Assert.areEqual(expectedByCase, outcomeByCase, 'The guardrails should run before the path parameter patterns');
    }

    // 'GET /items/5' is a GET of callout:Api/items/5
    private static CalloutBuilder toCallout(String request) {
        return new CalloutBuilder(API)
            .withMethod(request.substringBefore(' '))
            .withEndpoint(request.substringAfter(' '));
    }

    private static String toOutcome(CalloutPolicy policy, CalloutBuilder callout) {
        try {
            policy.enforce(callout, new CalloutRequestSnapshot(callout));
            return ALLOWED;
        } catch (CalloutPolicyException e) {
            return '[' + e.rule + '] ' + e.getMessage();
        } catch (CalloutGuardrailException e) {
            return e.getMessage();
        }
    }

    private static String toSetupError(String setup) {
        try {
            switch on setup {
                when 'blank scope' {
                    new CalloutPolicy(' ');
                }
                when 'scope with a query' {
                    new CalloutPolicy(API + '?x=1');
                }
                when 'scope with whitespace' {
                    new CalloutPolicy(API + ' x');
                }
                when 'pattern for an unknown name' {
                    new CalloutPolicy(API).withEndpoint('/items/{key}').withPathParameterPattern('id', '.+');
                }
                when 'pattern without an endpoint' {
                    new CalloutPolicy(API).withPathParameterPattern('id', '.+');
                }
                when 'second endpoint' {
                    new CalloutPolicy(API).withEndpoint('/a').withEndpoint('/b');
                }
            }
        } catch (CalloutBuilder.CalloutBuilderException e) {
            return e.getMessage();
        }
        return null;
    }

    private class FixedCondition extends CalloutCondition {
        private final Boolean met;

        FixedCondition(Boolean met) {
            this.met = met;
        }

        public override Boolean isMet(CalloutBuilder callout) {
            return this.met;
        }
    }

    private class BlockingGuardrail implements CalloutGuardrail {
        private final String header;

        BlockingGuardrail(String header) {
            this.header = header;
        }

        public void enforce(CalloutBuilder builder) {
            if (builder.getHeaders().containsKey(this.header)) {
                throw new CalloutGuardrailException(this.header + ' is set');
            }
        }
    }
}