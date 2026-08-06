@IsTest
private class GuardedCalloutBuilder_Test {
    private class CapturingMock implements HttpCalloutMock {
        public HttpRequest capturedRequest;
        public Integer statusCode = 200;
        public String statusText = 'OK';
        public String responseBody = '{"ok":true}';

        public HttpResponse respond(HttpRequest req) {
            this.capturedRequest = req;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setStatus(this.statusText);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(this.responseBody);
            return res;
        }
    }

    public class OkDto {
        public Boolean ok;
    }

    private static void authenticate(String namedCredential, String baseUrl) {
        CalloutAuthenticationGuardrail.stubAuthenticated(namedCredential, baseUrl, 'NamedPrincipal');
    }

    private static void mockScope(String endpoint, String method, HttpCalloutMock mock) {
        CalloutBuilder scope = new CalloutBuilder('callout:GuardedTest_Full').withEndpoint(endpoint).withMethod(method);
        CalloutBuilder.BUILDER_TO_MOCK_OVERRIDE.put(scope, mock);
    }

    private static GuardedCalloutBuilder guarded(String path, String method) {
        GuardedCalloutBuilder builder = new GuardedCalloutBuilder('GuardedTest_Full');
        builder.withEndpoint(path).withMethod(method);
        return builder;
    }

    @IsTest
    static void getHttpResponseRunsChainAndDelegates() {
        authenticate('GuardedTest_Full', 'https://example.com');
        mockScope('/v1/data', 'GET', new CapturingMock());

        Test.startTest();
        HttpResponse response = guarded('/v1/data', 'GET').getHttpResponse();
        Test.stopTest();

        Assert.areEqual(200, response.getStatusCode(), 'Unexpected status code');
        Assert.areEqual('{"ok":true}', response.getBody(), 'Unexpected body');
    }

    @IsTest
    static void appendsEncodedQueryParametersToUrlForGet() {
        authenticate('GuardedTest_Full', 'https://example.com');
        CapturingMock mock = new CapturingMock();
        mockScope('/v1/data?q=a+b', 'GET', mock);

        Test.startTest();
        guarded('/v1/data', 'GET').withQueryParameter('q', 'a b').getHttpResponse();
        Test.stopTest();

        Assert.areEqual(
            'callout:GuardedTest_Full/v1/data?q=a+b',
            mock.capturedRequest.getEndpoint(),
            'Query string should be URL-encoded and appended to the path'
        );
    }

    @IsTest
    static void passesBodyVerbatimWithoutSettingContentType() {
        authenticate('GuardedTest_Full', 'https://example.com');
        CapturingMock mock = new CapturingMock();
        mockScope('/v1/data', 'POST', mock);

        GuardedCalloutBuilder builder = guarded('/v1/data', 'POST');
        builder.withBody('{"name":"widget"}');

        Test.startTest();
        builder.getHttpResponse();
        Test.stopTest();

        Assert.areEqual(
            '{"name":"widget"}',
            mock.capturedRequest.getBody(),
            'String body should be sent verbatim (no double-encoding)'
        );
        Assert.areEqual('{"name":"widget"}', builder.getBody(), 'Body should be readable as a string by guardrails');
        Assert.isNull(
            mock.capturedRequest.getHeader('Content-Type'),
            'Content-Type should be left to the caller, as with a bare CalloutBuilder'
        );
    }

    @IsTest
    static void keepsExplicitContentType() {
        authenticate('GuardedTest_Full', 'https://example.com');
        CapturingMock mock = new CapturingMock();
        mockScope('/v1/data', 'POST', mock);

        Test.startTest();
        guarded('/v1/data', 'POST')
            .withHeader('Content-Type', 'text/plain')
            .withBlobBody(Blob.valueOf('plain text'))
            .getHttpResponse();
        Test.stopTest();

        Assert.areEqual(
            'text/plain',
            mock.capturedRequest.getHeader('Content-Type'),
            'Explicit Content-Type should not be overridden'
        );
    }

    @IsTest
    static void normalizesPathAndMethod() {
        authenticate('GuardedTest_Full', 'https://example.com');
        CapturingMock mock = new CapturingMock();
        mockScope('/v1/data', 'GET', mock);

        Test.startTest();
        guarded('v1/data', 'get').getHttpResponse(); // no leading slash, lowercase method
        Test.stopTest();

        Assert.areEqual(
            'callout:GuardedTest_Full/v1/data',
            mock.capturedRequest.getEndpoint(),
            'Leading slash should be added'
        );
        Assert.areEqual('GET', mock.capturedRequest.getMethod(), 'Method should be uppercased');
    }

    @IsTest
    static void outOfRangeTimeoutFailsInsteadOfBeingClamped() {
        authenticate('GuardedTest_Full', 'https://example.com');
        CapturingMock mock = new CapturingMock();
        mockScope('/v1/data', 'GET', mock);

        Exception caught;
        Test.startTest();
        try {
            guarded('/v1/data', 'GET').withTimeout(999999).getHttpResponse(); // over the 120000 platform max
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'HttpRequest.setTimeout should reject the out-of-range timeout');
        Assert.isNull(mock.capturedRequest, 'No callout should be made');
    }

    @IsTest
    static void throwsForBlankNamedCredential() {
        try {
            new GuardedCalloutBuilder(' ');
            Assert.fail('Expected exception');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('Named Credential'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void throwsForMissingEndpoint() {
        try {
            new GuardedCalloutBuilder('GuardedTest_Full').getHttpResponse();
            Assert.fail('Expected exception');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('endpoint path'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void throwsForInvalidMethodImmediately() {
        try {
            guarded('/v1/x', 'FETCH');
            Assert.fail('Expected exception');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('not a valid method'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void throwsForMissingConfig() {
        try {
            new GuardedCalloutBuilder('GuardedTest_Nonexistent').withEndpoint('/v1/x').getHttpResponse();
            Assert.fail('Expected exception');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('No active configuration found'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void blocksMethodNotAllowedByConfig() {
        authenticate('GuardedTest_Full', 'https://example.com'); // Full allows GET, POST only
        try {
            Test.startTest();
            guarded('/v1/data', 'DELETE').getHttpResponse();
            Test.stopTest();
            Assert.fail('Expected exception');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('is not allowed'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void blocksUnauthenticatedCredential() {
        // no authenticate() call -> auth guardrail blocks
        try {
            Test.startTest();
            guarded('/v1/data', 'GET').getHttpResponse();
            Test.stopTest();
            Assert.fail('Expected exception');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('not authenticated'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void httpErrorThrowsCalloutBuilderException() {
        authenticate('GuardedTest_Full', 'https://example.com');
        CapturingMock mock = new CapturingMock();
        mock.statusCode = 404;
        mock.statusText = 'Not Found';
        mock.responseBody = '{"error":"not found here"}';
        mockScope('/v1/missing', 'GET', mock);

        try {
            Test.startTest();
            guarded('/v1/missing', 'GET').getHttpResponse();
            Test.stopTest();
            Assert.fail('Expected CalloutBuilderException');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.areEqual(404, e.code, 'Exception should carry the HTTP status code');
            Assert.isTrue(e.getMessage().contains('not found here'), 'Error body should be in the message');
        }
    }

    @IsTest
    static void getResponseBodyMapIsGuardedAndDelegates() {
        authenticate('GuardedTest_Full', 'https://example.com');
        mockScope('/v1/data', 'GET', new CapturingMock());

        Test.startTest();
        Map<String, Object> parsed = guarded('/v1/data', 'GET').getResponseBodyMap();
        try {
            guarded('/v1/data', 'DELETE').getResponseBodyMap();
            Assert.fail('Expected the guardrail chain to run for getResponseBodyMap');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('is not allowed'), 'Unexpected: ' + e.getMessage());
        }
        Test.stopTest();

        Assert.areEqual(true, parsed.get('ok'), 'Response body should be parsed into a map');
    }

    @IsTest
    static void getTypedResponseBodyIsGuardedAndDelegates() {
        authenticate('GuardedTest_Full', 'https://example.com');
        mockScope('/v1/data', 'GET', new CapturingMock());

        Test.startTest();
        OkDto parsed = (OkDto) guarded('/v1/data', 'GET').withSuccessType(OkDto.class).getTypedResponseBody();
        Test.stopTest();

        Assert.areEqual(true, parsed.ok, 'Response body should be deserialized into the success type');
    }

    @IsTest
    static void accessorsReflectRecordedState() {
        GuardedCalloutBuilder builder = new GuardedCalloutBuilder('GuardedTest_Full');
        builder
            .withEndpoint('v1/data')
            .withMethod('post')
            .withHeader('Accept', 'application/json')
            .withQueryParameter('limit', '10')
            .withBody('{"name":"widget"}');

        Assert.areEqual('GuardedTest_Full', builder.getNamedCredential(), 'Unexpected named credential');
        Assert.areEqual('/v1/data', builder.getEndpoint(), 'Path should be normalized with a leading slash');
        Assert.areEqual('POST', builder.getMethod(), 'Method should be read back from the wrapped builder');
        Assert.areEqual('application/json', builder.getHeaders().get('Accept'), 'Headers should be readable');
        Assert.areEqual('10', builder.getQueryParameters().get('limit'), 'Query parameters should be readable');
        Assert.areEqual('{"name":"widget"}', builder.getBody(), 'Body should be readable as a string');
    }
}