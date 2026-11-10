@IsTest
private class CalloutEffectivePolicy_Test {
    private static final String API = 'callout:Api';
    private static final String ALLOWED = 'allowed';

    @IsTest
    static void testRouting() {
        RecordingGuardrail losingRouteChecks = new RecordingGuardrail();
        RecordingGuardrail adminChecks = new RecordingGuardrail();
        List<CalloutPolicy> policies =
            new List<CalloutPolicy>{
                new CalloutPolicy(API).withAllowedHeaders(new Set<String>{ 'Accept' }),
                new CalloutPolicy(API).withMethod('GET').withEndpoint('/users/me'),
                new CalloutPolicy(API)
                    .withMethods(new Set<String>{ 'GET', 'DELETE' })
                    .withEndpoint('/users/{id}')
                    .withAllowedHeaders(new Set<String>{ 'X-Route' })
                    .withGuardrail(losingRouteChecks),
                new CalloutPolicy(API).withMethod('GET').withEndpoint('/items/*'),
                new CalloutPolicy(API)
                    .withMethod('GET')
                    .withEndpoint('/items/{id}')
                    .withCondition(new FixedCondition(false)),
                new CalloutPolicy(API).withMethod('GET').withEndpoint('/v1/admin/*'),
                new CalloutPolicy(API).withEndpoint('/v1/admin/*').withGuardrail(adminChecks)
            };
        Map<String, String> expectedByRequest =
            new Map<String, String>{
                'GET /users/me with Accept' => ALLOWED,
                'GET /users/me with X-Route' => '[HEADER] GET /users/me: header X-Route is not granted',
                'DELETE /users/me' => '[METHOD] DELETE /users/me: method is not allowed on this path',
                'DELETE /users/5 with X-Route' => ALLOWED,
                'GET /orders' => '[NO_ROUTE] GET /orders: no policy allows this path',
                'GET /items/5' => '[METHOD] GET /items/5: method is not allowed on this path',
                'GET /items' => ALLOWED,
                'GET /items?a=1;b=2' => '[QUERY_PARAMETER] GET /items: query has ";"',
                'GET /v1/%61dmin/x' => ALLOWED
            };

        Test.startTest();
        Map<String, String> outcomeByRequest = new Map<String, String>();
        for (String request : expectedByRequest.keySet()) {
            outcomeByRequest.put(request, toOutcome(policies, toCallout(request)));
        }
        Test.stopTest();

        Assert.areEqual(expectedByRequest, outcomeByRequest, 'Each callout should route, or be blocked by its rule');
        Assert.isTrue(losingRouteChecks.endpoints.contains('/users/me'), 'Checks on a losing route should still run');
        Assert.isTrue(adminChecks.endpoints.contains('/v1/%61dmin/x'), 'A check should match the decoded path');
    }

    @IsTest
    static void testResponseSanitizer() {
        CalloutPolicy route = new CalloutPolicy(API).withMethod('GET').withEndpoint('/items/{id}');
        CalloutPolicy consentingRoute =
            new CalloutPolicy(API).withMethod('GET').withEndpoint('/items/{id}').withErrorBodies();
        CalloutPolicy redactor = new CalloutPolicy(API).withResponseSanitizer(new NamedSanitizer('redactor'));
        CalloutPolicy consentingRedactor =
            new CalloutPolicy(API)
                .withResponseSanitizers(new List<CalloutResponseSanitizer>{ new NamedSanitizer('redactor') })
                .withErrorBodies();
        CalloutPolicy otherApi = new CalloutPolicy('callout:Other').withResponseSanitizer(new NamedSanitizer('other'));
        Map<String, List<CalloutPolicy>> policiesByCase =
            new Map<String, List<CalloutPolicy>>{
                'no consent' => new List<CalloutPolicy>{ route },
                'route consents, redactor does not' => new List<CalloutPolicy>{ consentingRoute, redactor },
                'both consent' => new List<CalloutPolicy>{ consentingRoute, consentingRedactor }
            };
        Map<String, String> expectedByCase =
            new Map<String, String>{
                'no consent' => 'Withheld by policy',
                'route consents, redactor does not' => 'Withheld by policy',
                'both consent' => 'redactor'
            };
        CalloutBuilder callout = toCallout('GET /items/5');

        Test.startTest();
        Map<String, String> errorBodyByCase = new Map<String, String>();
        for (String testCase : policiesByCase.keySet()) {
            CalloutResponseSanitizer sanitizer =
                new CalloutEffectivePolicy(policiesByCase.get(testCase), callout).getResponseSanitizer();
            errorBodyByCase.put(testCase, toErrorOutcome(sanitizer));
        }
        Map<String, Object> body = new Map<String, Object>();
        new CalloutEffectivePolicy(new List<CalloutPolicy>{ route, redactor, otherApi }, callout)
            .getResponseSanitizer()
            .sanitize(body);
        Test.stopTest();

        Assert.areEqual(expectedByCase, errorBodyByCase, 'An error body should need every sanitizer owner to consent');
        Assert.areEqual(new Set<String>{ 'redactor' }, body.keySet(), 'Only applicable sanitizers should run');
    }

    // 'GET /items/5 with Accept' is a GET of callout:Api/items/5 with the header Accept
    private static CalloutBuilder toCallout(String request) {
        String endpoint = request.substringAfter(' ').substringBefore(' with ');
        CalloutBuilder callout =
            new CalloutBuilder(API).withMethod(request.substringBefore(' ')).withEndpoint(endpoint);
        if (request.contains(' with ')) {
            callout.withHeader(request.substringAfter(' with '), 'value');
        }
        return callout;
    }

    private static String toOutcome(List<CalloutPolicy> policies, CalloutBuilder callout) {
        try {
            new CalloutEffectivePolicy(policies, callout).enforce(callout);
            return ALLOWED;
        } catch (CalloutPolicyException e) {
            return '[' + e.rule + '] ' + e.getMessage();
        }
    }

    private static String toErrorOutcome(CalloutResponseSanitizer sanitizer) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(404);
        response.setBody('secret');
        try {
            sanitizer.sanitizeError(response);
            return response.getBody();
        } catch (CalloutResponseSanitizerException e) {
            return response.getStatus();
        }
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

    private class RecordingGuardrail implements CalloutGuardrail {
        public final Set<String> endpoints = new Set<String>();

        public void enforce(CalloutBuilder builder) {
            this.endpoints.add(builder.getEndpoint());
        }
    }

    private class NamedSanitizer extends CalloutResponseSanitizer {
        private final String name;

        NamedSanitizer(String name) {
            this.name = name;
        }

        public override void sanitizeError(HttpResponse response) {
            response.setBody(this.name);
        }

        public override void sanitize(Map<String, Object> body) {
            body.put(this.name, true);
        }
    }
}