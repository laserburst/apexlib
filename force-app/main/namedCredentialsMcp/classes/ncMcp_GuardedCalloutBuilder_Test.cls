@IsTest
private class ncMcp_GuardedCalloutBuilder_Test {
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

    /**
     * @description Referenced by name from recursionIsBlocked's injected config;
     * proves a custom guardrail cannot execute the callout it is guarding.
     */
    public class RecursiveGuardrail implements ncMcp_Guardrail {
        public void enforce(ncMcp_GuardedCalloutBuilder builder) {
            builder.getHttpResponse();
        }
    }

    public class OkDto {
        public Boolean ok;
    }

    private static void authenticate(String namedCredential, String baseUrl) {
        ncMcp_AuthenticationGuardrail.stubAuthenticated(namedCredential, baseUrl, 'NamedPrincipal');
    }

    private static void mockScope(String endpoint, String method, HttpCalloutMock mock) {
        CalloutBuilder scope = new CalloutBuilder('callout:ncMcpTest_Full').withEndpoint(endpoint).withMethod(method);
        CalloutBuilder.BUILDER_TO_MOCK_OVERRIDE.put(scope, mock);
    }

    private static ncMcp_GuardedCalloutBuilder guarded(String path, String method) {
        return new ncMcp_GuardedCalloutBuilder('ncMcpTest_Full').withEndpoint(path).withMethod(method);
    }

    @IsTest
    static void getHttpResponseRunsChainAndDelegates() {
        authenticate('ncMcpTest_Full', 'https://example.com');
        mockScope('/v1/data', 'GET', new CapturingMock());

        Test.startTest();
            HttpResponse response = guarded('/v1/data', 'GET').getHttpResponse();
        Test.stopTest();

        Assert.areEqual(200, response.getStatusCode(), 'Unexpected status code');
        Assert.areEqual('{"ok":true}', response.getBody(), 'Unexpected body');
    }

    @IsTest
    static void appendsEncodedQueryParametersForEveryMethod() {
        authenticate('ncMcpTest_Full', 'https://example.com');
        CapturingMock mock = new CapturingMock();
        mockScope('/v1/data?q=a+b', 'POST', mock);

        Test.startTest();
            guarded('/v1/data', 'POST').withQueryParameter('q', 'a b').getHttpResponse();
        Test.stopTest();

        Assert.areEqual(
            'callout:ncMcpTest_Full/v1/data?q=a+b',
            mock.capturedRequest.getEndpoint(),
            'Query string should be URL-encoded and appended to the path even for POST'
        );
    }

    @IsTest
    static void passesBodyVerbatimAndDefaultsContentType() {
        authenticate('ncMcpTest_Full', 'https://example.com');
        CapturingMock mock = new CapturingMock();
        mockScope('/v1/data', 'POST', mock);

        ncMcp_GuardedCalloutBuilder builder = guarded('/v1/data', 'POST')
            .withBody('{"name":"widget"}');

        Test.startTest();
            builder.getHttpResponse();
        Test.stopTest();

        Assert.areEqual('{"name":"widget"}', mock.capturedRequest.getBody(), 'String body should be sent verbatim (no double-encoding)');
        Assert.areEqual('{"name":"widget"}', builder.getBody(), 'Body should be readable as a string by guardrails');
        Assert.areEqual('application/json', mock.capturedRequest.getHeader('Content-Type'), 'Content-Type should default to JSON');
    }

    @IsTest
    static void keepsExplicitContentType() {
        authenticate('ncMcpTest_Full', 'https://example.com');
        CapturingMock mock = new CapturingMock();
        mockScope('/v1/data', 'POST', mock);

        Test.startTest();
            guarded('/v1/data', 'POST')
                .withHeader('Content-Type', 'text/plain')
                .withBlobBody(Blob.valueOf('plain text'))
                .getHttpResponse();
        Test.stopTest();

        Assert.areEqual('text/plain', mock.capturedRequest.getHeader('Content-Type'), 'Explicit Content-Type should not be overridden');
    }

    @IsTest
    static void normalizesPathAndMethod() {
        authenticate('ncMcpTest_Full', 'https://example.com');
        CapturingMock mock = new CapturingMock();
        mockScope('/v1/data', 'GET', mock);

        Test.startTest();
            guarded('v1/data', 'get').getHttpResponse(); // no leading slash, lowercase method
        Test.stopTest();

        Assert.areEqual('callout:ncMcpTest_Full/v1/data', mock.capturedRequest.getEndpoint(), 'Leading slash should be added');
        Assert.areEqual('GET', mock.capturedRequest.getMethod(), 'Method should be uppercased');
    }

    @IsTest
    static void clampsOutOfRangeTimeout() {
        authenticate('ncMcpTest_Full', 'https://example.com');
        CapturingMock mock = new CapturingMock();
        mockScope('/v1/data', 'GET', mock);

        Test.startTest();
            guarded('/v1/data', 'GET').withTimeout(999999).getHttpResponse(); // over the 120000 platform max
        Test.stopTest();

        // If the timeout were not clamped, HttpRequest.setTimeout would reject it and no callout would occur
        Assert.isNotNull(mock.capturedRequest, 'Callout should occur with the timeout clamped into range');
    }

    @IsTest
    static void throwsForBlankNamedCredential() {
        try {
            new ncMcp_GuardedCalloutBuilder(' ');
            Assert.fail('Expected exception');
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('Named Credential'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void throwsForMissingEndpoint() {
        try {
            new ncMcp_GuardedCalloutBuilder('ncMcpTest_Full').getHttpResponse();
            Assert.fail('Expected exception');
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('endpoint path'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void throwsForInvalidMethodImmediately() {
        try {
            guarded('/v1/x', 'FETCH');
            Assert.fail('Expected exception');
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('not a valid method'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void throwsForMissingConfig() {
        try {
            new ncMcp_GuardedCalloutBuilder('ncMcpTest_Nonexistent').withEndpoint('/v1/x').getHttpResponse();
            Assert.fail('Expected exception');
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('No active configuration found'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void blocksMethodNotAllowedByConfig() {
        authenticate('ncMcpTest_Full', 'https://example.com'); // Full allows GET, POST only
        try {
            Test.startTest();
                guarded('/v1/data', 'DELETE').getHttpResponse();
            Test.stopTest();
            Assert.fail('Expected exception');
        } catch (ncMcp_Exception e) {
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
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('not authenticated'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void httpErrorThrowsCalloutBuilderException() {
        authenticate('ncMcpTest_Full', 'https://example.com');
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
        authenticate('ncMcpTest_Full', 'https://example.com');
        mockScope('/v1/data', 'GET', new CapturingMock());

        Test.startTest();
            Map<String, Object> parsed = guarded('/v1/data', 'GET').getResponseBodyMap();
            try {
                guarded('/v1/data', 'DELETE').getResponseBodyMap();
                Assert.fail('Expected the guardrail chain to run for getResponseBodyMap');
            } catch (ncMcp_Exception e) {
                Assert.isTrue(e.getMessage().contains('is not allowed'), 'Unexpected: ' + e.getMessage());
            }
        Test.stopTest();

        Assert.areEqual(true, parsed.get('ok'), 'Response body should be parsed into a map');
    }

    @IsTest
    static void getTypedResponseBodyIsGuardedAndDelegates() {
        authenticate('ncMcpTest_Full', 'https://example.com');
        mockScope('/v1/data', 'GET', new CapturingMock());

        Test.startTest();
            OkDto parsed = (OkDto) guarded('/v1/data', 'GET').withSuccessType(OkDto.class).getTypedResponseBody();
        Test.stopTest();

        Assert.areEqual(true, parsed.ok, 'Response body should be deserialized into the success type');
    }

    @IsTest
    static void accessorsReflectRecordedState() {
        ncMcp_GuardedCalloutBuilder builder = new ncMcp_GuardedCalloutBuilder('ncMcpTest_Full')
            .withEndpoint('v1/data')
            .withMethod('post')
            .withHeader('Accept', 'application/json')
            .withQueryParameter('limit', '10')
            .withBody('{"name":"widget"}');

        Assert.areEqual('ncMcpTest_Full', builder.getNamedCredential(), 'Unexpected named credential');
        Assert.areEqual('/v1/data', builder.getPath(), 'Path should be normalized with a leading slash');
        Assert.areEqual('POST', builder.getMethod(), 'Method should be read back from the wrapped builder');
        Assert.areEqual('application/json', builder.getHeaders().get('Accept'), 'Headers should be readable');
        Assert.areEqual('10', builder.getQueryParameters().get('limit'), 'Query parameters should be readable');
        Assert.areEqual('{"name":"widget"}', builder.getBody(), 'Body should be readable as a string');
        Assert.isNull(builder.getConfig(), 'Config is loaded only on execution');
    }

    @IsTest
    static void constructFullEndpointBakesQueryString() {
        String fullEndpoint = guarded('/v1/data', 'GET').withQueryParameter('limit', '10').constructFullEndpoint();
        Assert.areEqual('callout:ncMcpTest_Full/v1/data?limit=10', fullEndpoint, 'Unexpected full endpoint');
    }

    @IsTest
    static void recursionFromCustomGuardrailIsBlocked() {
        authenticate('ncMcpTest_Full', 'https://example.com');
        ncMcp_Config config = new ncMcp_Config();
        config.namedCredential = 'ncMcpTest_Full';
        config.allowedMethods = new List<String>{ 'GET' };
        config.allowedEndpointPatterns = new List<String>{ '*' };
        config.guardrails = new List<String>{ 'ncMcp_GuardedCalloutBuilder_Test.RecursiveGuardrail' };

        ncMcp_GuardedCalloutBuilder builder = guarded('/v1/data', 'GET');
        builder.config = config;

        try {
            Test.startTest();
                builder.getHttpResponse();
            Test.stopTest();
            Assert.fail('Expected exception');
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('must not execute'), 'Unexpected: ' + e.getMessage());
        }
    }
}
