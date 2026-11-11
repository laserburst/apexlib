@IsTest
private class ncMcp_CalloutRequest_Test {
    private static final String API = 'callout:Api';

    @TestSetup
    static void makeUsers() {
        ncMcp_TestFactory.insertUsers();
    }

    @IsTest
    static void testRequestFollowsInput() {
        ncMcp_PolicyCatalog.instance = new ncMcp_PolicyCatalog(toPolicies(new List<CalloutPolicy>()));
        ViciousMockery mock = ViciousMockery.cast(200);
        Map<String, RequestBuilder> builderByCase =
            new Map<String, RequestBuilder>{
                'JSON, no Content-Type' => new RequestBuilder().withMethod('PATCH').withBody('{"name":"A1"}'),
                'JSON subtype' => new RequestBuilder()
                    .withMethod('PATCH')
                    .withHeaders('{"Content-Type":"application/merge-patch+json"}')
                    .withBody('{"name":"A1"}'),
                'XML' => new RequestBuilder()
                    .withMethod('PATCH')
                    .withHeaders('{"Content-Type":"application/xml"}')
                    .withBody('<item name="A1"/>'),
                'query on DELETE' => new RequestBuilder()
                    .withMethod('delete')
                    .withQueryParameters('{"status":"archived","limit":null}'),
                'query in path' => new RequestBuilder()
                    .withPath('/items/5?expand=notes')
                    .withQueryParameters('{"status":"open"}'),
                'null headers' => new RequestBuilder().withHeaders('null'),
                'invalid JSON' => new RequestBuilder().withMethod('PATCH').withBody('{name'),
                'body on GET' => new RequestBuilder().withBody('{"name":"A1"}'),
                'list header value' => new RequestBuilder().withHeaders('{"Accept":["application/json"]}'),
                'header array' => new RequestBuilder().withHeaders('["Accept"]'),
                'timeout too short' => new RequestBuilder().withTimeout(0),
                'not exposed' => new RequestBuilder().withNamedCredential('Other'),
                'no path, left to the policies' => new RequestBuilder().withPath('')
            };
        Map<String, String> expectedByCase =
            new Map<String, String>{
                'JSON, no Content-Type' => '1 PATCH callout:Api/items/5 {"name":"A1"}',
                'JSON subtype' => '1 PATCH callout:Api/items/5 {"name":"A1"}',
                'XML' => '1 PATCH callout:Api/items/5 <item name="A1"/>',
                'query on DELETE' => '1 DELETE callout:Api/items/5?status=archived',
                'query in path' => '1 GET callout:Api/items/5?expand=notes&status=open',
                'null headers' => '1 GET callout:Api/items/5',
                'invalid JSON' => '0 Field "body" must be JSON when the Content-Type is JSON or not set',
                'body on GET' => '0 GET and HEAD requests can\'t have a body',
                'list header value' => '0 Field "headers" must have text, number or boolean values',
                'header array' => '0 Field "headers" must be a JSON object, such as {"name":"value"}',
                'timeout too short' => '0 Field "timeoutMilliseconds" must be from 1 to 120000',
                'not exposed' => '0 ' + ncMcp_PolicyCatalog.NOT_EXPOSED,
                'no path, left to the policies' => '0 NO_ROUTE'
            };

        Map<String, String> outcomeByCase = new Map<String, String>();
        System.runAs(ncMcp_TestFactory.getUser(ncMcp_TestFactory.MCP_USER)) {
            Test.startTest();
            for (String testCase : builderByCase.keySet()) {
                outcomeByCase.put(testCase, toSentOutcome(builderByCase.get(testCase).toRequest(), mock));
            }
            Test.stopTest();
        }

        Assert.areEqual(
            expectedByCase,
            outcomeByCase,
            'The request should be sent as given, or refused before sending'
        );
    }

    @IsTest
    static void testSendOutcomes() {
        CalloutPolicy failing = new CalloutPolicy(API).withResponseSanitizer(new FailingSanitizer());
        Map<String, String> expectedByCase =
            new Map<String, String>{
                'blocked' => 'METHOD',
                'withheld error body' => '400 Withheld by policy ',
                'sanitizer fails' => ncMcp_CalloutRequest.SENT_BUT_FAILED
            };

        Map<String, String> outcomeByCase = new Map<String, String>();
        System.runAs(ncMcp_TestFactory.getUser(ncMcp_TestFactory.MCP_USER)) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new ViciousMockery(400));
            outcomeByCase.put('blocked', toResponseOutcome('POST', new List<CalloutPolicy>()));
            outcomeByCase.put('withheld error body', toResponseOutcome('GET', new List<CalloutPolicy>()));
            Test.setMock(HttpCalloutMock.class, new ViciousMockery(200));
            outcomeByCase.put('sanitizer fails', toResponseOutcome('GET', new List<CalloutPolicy>{ failing }));
            Test.stopTest();
        }

        Assert.areEqual(
            expectedByCase,
            outcomeByCase,
            'A block should keep its rule, an error should come back, and a failure after sending should say so'
        );
    }

    private static List<CalloutPolicy> toPolicies(List<CalloutPolicy> extraPolicies) {
        List<CalloutPolicy> policies =
            new List<CalloutPolicy>{
                new CalloutPolicy(API)
                    .withAllowedHeaders(new Set<String>{ 'Accept', 'Content-Type' })
                    .withAllowedQueryParameters(new Set<String>{ 'status', 'expand' }),
                new CalloutPolicy(API).withMethods(new Set<String>{ 'GET', 'PATCH', 'DELETE' }).withEndpoint('/items/*')
            };
        policies.addAll(extraPolicies);
        return policies;
    }

    // how many requests were sent, then the last one or the error
    private static String toSentOutcome(ncMcp_CalloutRequest request, ViciousMockery mock) {
        Integer sentBefore = mock.getRequests().size();
        String detail;
        try {
            ncMcp_ToolSendRequest.sendRequest(new List<ncMcp_CalloutRequest>{ request });
            HttpRequest sent = mock.getLastRequest();
            detail = sent.getMethod() + ' ' + sent.getEndpoint() + ' ' + sent.getBody();
        } catch (CalloutPolicyException e) {
            detail = e.rule.name();
        } catch (ncMcp_ToolException e) {
            detail = e.getMessage();
        }
        return ((mock.getRequests().size() - sentBefore) + ' ' + detail).trim();
    }

    // the status code, status and body, the rule that blocked the callout, or the error
    private static String toResponseOutcome(String method, List<CalloutPolicy> extraPolicies) {
        ncMcp_PolicyCatalog.instance = new ncMcp_PolicyCatalog(toPolicies(extraPolicies));
        try {
            ncMcp_CalloutResponse response =
                ncMcp_ToolSendRequest.sendRequest(
                    new List<ncMcp_CalloutRequest>{ new RequestBuilder().withMethod(method).toRequest() }
                )[0];
            return response.statusCode + ' ' + response.status + ' ' + response.body;
        } catch (CalloutPolicyException e) {
            return e.rule.name();
        } catch (ncMcp_ToolException e) {
            return e.getMessage();
        }
    }

    // a GET of /items/5 through callout:Api until a setter says otherwise
    private class RequestBuilder {
        private final ncMcp_CalloutRequest request = new ncMcp_CalloutRequest();

        RequestBuilder() {
            this.request.namedCredential = 'Api';
            this.request.path = '/items/5';
        }

        RequestBuilder withNamedCredential(String namedCredential) {
            this.request.namedCredential = namedCredential;
            return this;
        }

        RequestBuilder withMethod(String method) {
            this.request.method = method;
            return this;
        }

        RequestBuilder withPath(String path) {
            this.request.path = path;
            return this;
        }

        RequestBuilder withHeaders(String headers) {
            this.request.headers = headers;
            return this;
        }

        RequestBuilder withQueryParameters(String queryParameters) {
            this.request.queryParameters = queryParameters;
            return this;
        }

        RequestBuilder withBody(String body) {
            this.request.body = body;
            return this;
        }

        RequestBuilder withTimeout(Integer timeoutMilliseconds) {
            this.request.timeoutMilliseconds = timeoutMilliseconds;
            return this;
        }

        ncMcp_CalloutRequest toRequest() {
            return this.request;
        }
    }

    private class FailingSanitizer extends CalloutResponseSanitizer {
        public override void sanitize(HttpResponse response) {
            throw new CalloutResponseSanitizerException('Response has a field the policy can\'t redact');
        }
    }
}