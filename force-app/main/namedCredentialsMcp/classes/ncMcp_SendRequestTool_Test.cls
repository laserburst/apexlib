@IsTest
private class ncMcp_SendRequestTool_Test {
    private class StubMock implements HttpCalloutMock {
        public HttpRequest capturedRequest;
        public Integer statusCode;
        public String body;

        public StubMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            this.capturedRequest = req;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setStatus(this.statusCode == 200 ? 'OK' : 'Error');
            res.setHeader('Content-Type', 'application/json');
            res.setBody(this.body);
            return res;
        }
    }

    private static void authenticate(String namedCredential) {
        CalloutAuthenticationGuardrail.stubAuthenticated(namedCredential, null, null);
    }

    private static void mockScope(String namedCredential, String endpoint, String method, HttpCalloutMock mock) {
        CalloutBuilder scope = new CalloutBuilder('callout:' + namedCredential).withEndpoint(endpoint).withMethod(method);
        CalloutBuilder.BUILDER_TO_MOCK_OVERRIDE.put(scope, mock);
    }

    private static ncMcp_SendRequestTool.Request input(String namedCredential, String path, String method) {
        ncMcp_SendRequestTool.Request request = new ncMcp_SendRequestTool.Request();
        request.namedCredential = namedCredential;
        request.path = path;
        request.method = method;
        return request;
    }

    private static List<ncMcp_HttpResponseFacade> send(ncMcp_SendRequestTool.Request request) {
        return ncMcp_SendRequestTool.sendRequest(new List<ncMcp_SendRequestTool.Request>{ request });
    }

    @IsTest
    static void happyPathParsesHeadersAndQuery() {
        authenticate('GuardedTest_Full');
        StubMock mock = new StubMock(200, '{"ok":true}');
        mockScope('GuardedTest_Full', '/v1/data?q=apex', 'GET', mock);

        ncMcp_SendRequestTool.Request request = input('GuardedTest_Full', '/v1/data', 'GET');
        request.headers = '{"Accept":"application/json"}';
        request.queryParameters = '{"q":"apex"}';

        Test.startTest();
            List<ncMcp_HttpResponseFacade> responses = send(request);
        Test.stopTest();

        Assert.areEqual(1, responses.size(), 'One response expected');
        Assert.areEqual(200, responses[0].statusCode, 'Unexpected status');
        Assert.areEqual('application/json', mock.capturedRequest.getHeader('Accept'), 'Header should be forwarded');
    }

    @IsTest
    static void throwsWithStatusAndBodyOnHttpError() {
        authenticate('GuardedTest_Full');
        mockScope('GuardedTest_Full', '/v1/missing', 'GET', new StubMock(404, '{"error":"not found here"}'));

        try {
            Test.startTest();
                send(input('GuardedTest_Full', '/v1/missing', 'GET'));
            Test.stopTest();
            Assert.fail('Expected GuardedCalloutException');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('HTTP 404'), 'HTTP status should be in the message: ' + e.getMessage());
            Assert.isTrue(e.getMessage().contains('not found here'), 'Error body should be in the message: ' + e.getMessage());
        }
    }

    @IsTest
    static void blocksDisallowedMethod() {
        authenticate('GuardedTest_Full'); // Full allows GET, POST only
        try {
            Test.startTest();
                send(input('GuardedTest_Full', '/v1/data', 'DELETE'));
            Test.stopTest();
            Assert.fail('Expected GuardedCalloutException');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('is not allowed'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void blocksUnauthenticatedCredential() {
        // no authenticate() call -> auth guardrail blocks
        try {
            Test.startTest();
                send(input('GuardedTest_Full', '/v1/data', 'GET'));
            Test.stopTest();
            Assert.fail('Expected GuardedCalloutException');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('not authenticated'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void rejectsMalformedHeaders() {
        authenticate('GuardedTest_Full');
        ncMcp_SendRequestTool.Request request = input('GuardedTest_Full', '/v1/data', 'GET');
        request.headers = '[1,2]'; // valid JSON, wrong shape

        try {
            Test.startTest();
                send(request);
            Test.stopTest();
            Assert.fail('Expected GuardedCalloutException');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('must be a JSON object string'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void toleratesNullHeadersAndValues() {
        authenticate('GuardedTest_Full');
        StubMock mock = new StubMock(200, '{"ok":true}');
        mockScope('GuardedTest_Full', '/v1/data', 'GET', mock);

        ncMcp_SendRequestTool.Request request = input('GuardedTest_Full', '/v1/data', 'GET');
        request.headers = '{"Accept":"application/json","X-Trace-Id":null}';
        request.queryParameters = 'null'; // the JSON literal, not an object

        Test.startTest();
            List<ncMcp_HttpResponseFacade> responses = send(request);
        Test.stopTest();

        Assert.areEqual(200, responses[0].statusCode, 'Null header values and null JSON should be ignored, not crash');
        Assert.areEqual('application/json', mock.capturedRequest.getHeader('Accept'), 'Non-null headers should be forwarded');
    }

    @IsTest
    static void runsCustomGuardrailFromConfig() {
        authenticate('GuardedTest_Guarded');
        ncMcp_SendRequestTool.Request request = input('GuardedTest_Guarded', '/v1/login', 'POST');
        request.body = '{"password":"hunter2"}';

        try {
            Test.startTest();
                send(request);
            Test.stopTest();
            Assert.fail('Expected the custom guardrail to block the request');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('CalloutExampleGuardrail'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void rejectsBlankNamedCredential() {
        try {
            send(input(null, '/v1/data', 'GET'));
            Assert.fail('Expected GuardedCalloutException');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('"namedCredential" is required'), 'Unexpected: ' + e.getMessage());
            Assert.isTrue(e.getMessage().contains('listCredentials'), 'Should point the agent to the listCredentials tool');
        }
    }

    @IsTest
    static void rejectsBlankPath() {
        try {
            send(input('GuardedTest_Full', null, 'GET'));
            Assert.fail('Expected GuardedCalloutException');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('"path" is required'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void processesRequestsInBulk() {
        authenticate('GuardedTest_Full');
        StubMock mock = new StubMock(200, '{"ok":true}');
        mockScope('GuardedTest_Full', '/v1/a', 'GET', mock);
        mockScope('GuardedTest_Full', '/v1/b', 'GET', mock);

        Test.startTest();
            List<ncMcp_HttpResponseFacade> responses = ncMcp_SendRequestTool.sendRequest(
                new List<ncMcp_SendRequestTool.Request>{
                    input('GuardedTest_Full', '/v1/a', 'GET'),
                    input('GuardedTest_Full', '/v1/b', 'GET')
                }
            );
        Test.stopTest();

        Assert.areEqual(2, responses.size(), 'Two responses expected, one per request');
    }
}
