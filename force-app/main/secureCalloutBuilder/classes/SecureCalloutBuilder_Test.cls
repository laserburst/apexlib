@IsTest
private class SecureCalloutBuilder_Test {
    private static final String API = 'callout:Api';
    private static final String SENT = 'sent';
    private static Integer queuedStatusCode;

    @IsTest
    static void testBlocksWithoutAllowingPolicy() {
        JsonMock mock = new JsonMock();
        CalloutPolicy ruleOnly = new CalloutPolicy(API).withAllowedHeaders(new Set<String>{ 'Accept' });
        CalloutPolicy otherApi = new CalloutPolicy('callout:Other').withMethod('GET');
        Map<String, List<CalloutPolicy>> policiesByCase =
            new Map<String, List<CalloutPolicy>>{
                'no policies' => new List<CalloutPolicy>(),
                'only a policy without a method' => new List<CalloutPolicy>{ ruleOnly },
                'only a policy for another API' => new List<CalloutPolicy>{ otherApi }
            };
        Map<String, String> expectedByCase =
            new Map<String, String>{
                'no policies' => 'NO_ROUTE',
                'only a policy without a method' => 'NO_ROUTE',
                'only a policy for another API' => 'NO_ROUTE'
            };

        Test.startTest();
        Map<String, String> outcomeByCase = new Map<String, String>();
        for (String testCase : policiesByCase.keySet()) {
            CalloutBuilder callout = toCallout(mock);
            new SecureCalloutBuilder(callout).withPolicies(policiesByCase.get(testCase));
            outcomeByCase.put(testCase, toOutcome(callout));
        }
        Test.stopTest();

        Assert.areEqual(
            expectedByCase,
            outcomeByCase,
            'The wrapped builder should be blocked even when executed directly'
        );
        Assert.isTrue(mock.getRequests().isEmpty(), 'A blocked callout should send nothing');
    }

    @IsTest
    static void testSecuredCallout() {
        RecordingSanitizer sanitizer = new RecordingSanitizer();
        CalloutBuilder callout = toCallout(new JsonMock()).withSuccessType(Item.class);
        SecureCalloutBuilder secured =
            new SecureCalloutBuilder(callout).withPolicy(
                new CalloutPolicy(API).withMethod('GET').withEndpoint('/items/{id}').withResponseSanitizer(sanitizer)
            );

        Test.startTest();
        HttpResponse response = secured.getHttpResponse();
        secured.getResponseBodyAsBlob();
        secured.getResponseBodyMap();
        secured.getTypedResponseBody();
        callout.withMockIfTest(new XmlMock());
        secured.getXmlResponseBody();
        callout.withMethod('DELETE');
        String reExecuted = toOutcome(callout);
        Test.stopTest();

        Assert.areEqual(
            new List<String>{ 'HttpResponse', 'HttpResponse', 'Map', 'typed', 'Dom.Document' },
            sanitizer.overloads,
            'Each getter should reach the policies\' sanitizers through its own overload'
        );
        Assert.areEqual('METHOD', reExecuted, 'A builder executed again should be checked again');
        Assert.areEqual('', response.getHeader('Set-Cookie'), 'A credential header should come back blank');
    }

    @IsTest
    static void testErrorBodies() {
        CalloutPolicy route = new CalloutPolicy(API).withMethod('GET').withEndpoint('/items/{id}');
        CalloutPolicy consentingRoute =
            new CalloutPolicy(API).withMethod('GET').withEndpoint('/items/{id}').withErrorBodies();
        CalloutPolicy consentingRedactor =
            new CalloutPolicy(API).withResponseSanitizer(new RedactingSanitizer()).withErrorBodies();
        Map<String, List<CalloutPolicy>> policiesByCase =
            new Map<String, List<CalloutPolicy>>{
                'no consent' => new List<CalloutPolicy>{ route },
                'consent' => new List<CalloutPolicy>{ consentingRoute, consentingRedactor }
            };
        Map<String, String> expectedByCase =
            new Map<String, String>{ 'no consent' => '400 Withheld by policy', 'consent' => '400 redacted' };

        Test.startTest();
        Map<String, String> errorByCase = new Map<String, String>();
        for (String testCase : policiesByCase.keySet()) {
            SecureCalloutBuilder secured =
                new SecureCalloutBuilder(toCallout(new ViciousMockery(400))).withPolicies(policiesByCase.get(testCase));
            try {
                secured.getHttpResponse();
            } catch (CalloutBuilder.CalloutBuilderException e) {
                errorByCase.put(testCase, e.code + ' ' + e.getMessage());
            }
        }
        HttpResponse bypassed =
            new SecureCalloutBuilder(toCallout(new ViciousMockery(400)).withBypassResponseValidation(true))
                .withPolicy(route)
                .getHttpResponse();
        Test.stopTest();

        Assert.areEqual(expectedByCase, errorByCase, 'An error body should reach the caller only with consent');
        Assert.areEqual('', bypassed.getBody(), 'A bypassed error body should still need consent');
    }

    @IsTest
    static void testQueued() {
        // not withMockIfTest(): ViciousMockery records HttpRequests, which a Queueable can't serialize
        ViciousMockery.cast(200);
        CalloutBuilder callout = new CalloutBuilder(API).withEndpoint('/items/5');
        new SecureCalloutBuilder(callout).withPolicy(
            new CalloutPolicy(API).withMethod('GET').withEndpoint('/items/{id}')
        );

        Test.startTest();
        CalloutBuilderQueueable.enqueue(new RecordingCollection(new List<CalloutBuilder>{ callout }));
        Test.stopTest();

        Assert.areEqual(200, queuedStatusCode, 'The guardrail and the sanitizer should stay one object in a Queueable');
    }

    private static CalloutBuilder toCallout(HttpCalloutMock mock) {
        return new CalloutBuilder(API).withEndpoint('/items/5').withMockIfTest(mock);
    }

    private static String toOutcome(CalloutBuilder callout) {
        try {
            callout.getHttpResponse();
            return SENT;
        } catch (CalloutPolicyException e) {
            return e.rule.name();
        }
    }

    private class JsonMock extends ViciousMockery {
        {
            this.headers.put('Set-Cookie', 'sid=abc');
        }

        public override String getBodyString() {
            return '{"id": 5}';
        }
    }

    private class Item {
        public Integer id;
    }

    private class XmlMock extends ViciousMockery {
        public override String getBodyString() {
            return '<item id="5"/>';
        }
    }

    private class RedactingSanitizer extends CalloutResponseSanitizer {
        public override void sanitizeError(HttpResponse response) {
            response.setBody('redacted');
        }
    }

    private class RecordingSanitizer extends CalloutResponseSanitizer {
        public final List<String> overloads = new List<String>();

        public override void sanitize(HttpResponse response) {
            this.overloads.add('HttpResponse');
        }

        public override void sanitize(Map<String, Object> body) {
            this.overloads.add('Map');
        }

        public override void sanitize(Object body, System.Type successType) {
            this.overloads.add('typed');
        }

        public override void sanitize(Dom.Document body) {
            this.overloads.add('Dom.Document');
        }
    }

    private class RecordingCollection extends CalloutCollection {
        RecordingCollection(List<CalloutBuilder> builders) {
            super(builders);
        }

        protected override void postProcess(HttpResponse response) {
            queuedStatusCode = response.getStatusCode();
        }
    }
}