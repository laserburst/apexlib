@IsTest
private class CalloutBuilder_Test {
    @IsTest
    static void testSuccessfulTypedResponse() {
        Test.startTest();
            CalloutBuilder cb =
                new CalloutBuilder('callout:Test')
                    .withEndpoint('/test')
                    .withHeader('key', 'value')
                    .withHeaders(new Map<String, String>{ 'key_2' => 'value_2' })
                    .withBody('test body')
                    .withTimeout(1000)
                    .withSuppressApexObjectNulls(false)
                    .withSuccessType(DummyResponse.class)
                    .withMockIfTest(new SuccessMock());

            DummyResponse res = (DummyResponse) cb.getTypedResponseBody();
        Test.stopTest();

        Assert.areEqual('Success', res.value, 'Unexpected res.value');
    }

    @IsTest
    static void testSuccessfulUntypedResponse() {
        Test.startTest();
            CalloutBuilder cb = new CalloutBuilder('callout:Test')
                .withEndpoint('/test')
                .withMockIfTest(new SuccessMock());
            Map<String, Object> resMap = cb.getResponseBodyMap();
        Test.stopTest();

        Assert.areEqual('Success', (String) resMap.get('value'), 'Unexpected res.value');
    }

    @IsTest
    static void testValidationFailsForMissingNC() {
        try {
            Test.startTest();
                new CalloutBuilder(null).getHttpResponse();
            Test.stopTest();

            Assert.fail('Expected exception not thrown');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.isTrue(e.getMessage().contains('NC or base URL must be provided'), 'Unexpected error message');
        }
    }

    @IsTest
    static void testErrorDeserialization() {
        CalloutBuilder builder = new CalloutBuilder('callout:ErrorTest')
            .withEndpoint('/fail')
            .withErrorType(DummyErrorResponse.class)
            .withMockIfTest(new ErrorMock());
        try {
            Test.startTest();
                builder.getHttpResponse();
            Test.stopTest();

            Assert.fail('Expected error not thrown');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.isTrue(e.getMessage().contains('Something went wrong'), 'Unexpected error message');
            Assert.isNotNull(builder.getError(), 'Expected deserialized error');
            Assert.isInstanceOfType(builder.getError(), DummyErrorResponse.class, 'Expected DummyErrorResponse instance');
        }
    }

    @IsTest
    static void testInvalidErrorType() {
        try {
            Test.startTest();
                new CalloutBuilder('callout:ErrorTest')
                    .withEndpoint('/fail')
                    .withErrorType(CalloutBuilder_Test.class)
                    .getHttpResponse();
            Test.stopTest();

            Assert.fail('Expected error not thrown');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.isTrue(
                e.getMessage().contains('Callout error must implement CalloutErrorResponse'),
                'Unexpected error message'
            );
        }
    }

    @IsTest
    static void testNullErrorType() {
        try {
            Test.startTest();
                new CalloutBuilder('callout:ErrorTest')
                    .withEndpoint('/fail')
                    .withErrorType(null)
                    .getHttpResponse();
            Test.stopTest();
            Assert.fail('Expected error not thrown');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.isTrue(e.getMessage().contains('Callout error cannot be set to null'), 'Unexpected error message');
        }
    }

    @IsTest
    static void testNullMethod() {
        try {
            Test.startTest();
                new CalloutBuilder('callout:ErrorTest').withMethod(null).getHttpResponse();
            Test.stopTest();

            Assert.fail('Expected error not thrown');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.isTrue(e.getMessage().contains('HTTP method must be provided'), 'Unexpected error message');
        }
    }

    @IsTest
    static void testGetTypedResponseBodyWithNoType() {
        try {
            Test.startTest();
                new CalloutBuilder('callout:ErrorTest').getTypedResponseBody();
            Test.stopTest();

            Assert.fail('Expected error not thrown');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.isTrue(
                e.getMessage().contains('getTypedResponseBody expects this.successType to be set'),
                'Unexpected error message'
            );
        }
    }

    @IsTest
    static void testWithBlobBody() {
        Test.startTest();
            Blob blobBody = Blob.valueOf('{"value":"Success"}');
            CalloutBuilder cb =
                new CalloutBuilder('callout:Test')
                    .withMethod('POST')
                    .withBlobBody(blobBody)
                    .withSuccessType(DummyResponse.class)
                    .withMockIfTest(new SuccessMock());

            DummyResponse res = (DummyResponse) cb.getTypedResponseBody();
        Test.stopTest();

        Assert.areEqual('Success', res.value, 'Unexpected res.value');
    }

    @IsTest
    static void testBypassResponseValidation() {
        Test.startTest();
            CalloutBuilder cb =
                new CalloutBuilder('callout:Test')
                    .withEndpoint('/test')
                    .withBypassResponseValidation(true)
                    .withMockIfTest(new ErrorMock());
            Map<String, Object> resMap = cb.getResponseBodyMap();
        Test.stopTest();
        Assert.areEqual('Something went wrong', (String) resMap.get('message'), 'Unexpected res.message');
    }

    @IsTest
    static void testRetrier() {
        Test.startTest();
            CalloutBuilder cb =
                new CalloutBuilder('callout:Test')
                    .withEndpoint('/test')
                    .withRetrier(new RetrierTest())
                    .withMaxRetries(2)
                    .withMockIfTest(new SuccessMock());
            Map<String, Object> resMap = cb.getResponseBodyMap();
        Test.stopTest();
        Assert.areEqual('Success', (String) resMap.get('value'), 'Unexpected res.value');
    }

    @isTest
    static void testWithQueryParametersGetSuccess() {
        Test.startTest();
            CalloutBuilder cb =
                new CalloutBuilder('https://example.com')
                    .withEndpoint('/test')
                    .withQueryParameters(new Map<String, String>{ 'param1' => 'value1', 'param2' => 'value2' })
                    .withQueryParameter('param3', 'value3')
                    .withMockIfTest(new SuccessMock());
            Map<String, Object> resMap = cb.getResponseBodyMap();
        Test.stopTest();
        String expectedUrl = 'https://example.com/test?param1=value1&param2=value2&param3=value3';
        Assert.areEqual(expectedUrl, cb.constructFullEndpoint(), 'Unexpected endpoint URL');
        Assert.areEqual('Success', (String) resMap.get('value'), 'Unexpected res.value');
    }

    @isTest
    static void testWithQueryParametersPostSuccess() {
        CaptureMock mock = new CaptureMock();
        Test.startTest();
            CalloutBuilder cb =
                new CalloutBuilder('https://example.com')
                    .withEndpoint('/test')
                    .withMethod('POST')
                    .withQueryParameters(new Map<String, String>{ 'param1' => 'value1', 'param2' => 'value2' })
                    .withQueryParameter('param3', 'value3')
                    .withMockIfTest(mock);
            Map<String, Object> resMap = cb.getResponseBodyMap();
        Test.stopTest();
        String expectedUrl = 'https://example.com/test'; // POST requests do not include query parameters in the URL
        Assert.areEqual(expectedUrl, cb.constructFullEndpoint(), 'Unexpected endpoint URL');
        Assert.areEqual(
            'param1=value1&param2=value2&param3=value3',
            mock.capturedRequest.getBody(),
            'Parameters should be the body instead'
        );
        Assert.areEqual('Success', (String) resMap.get('value'), 'Unexpected res.value');
    }

    @isTest
    static void testWithQueryParametersJoinEndpointQueryString() {
        Test.startTest();
            CalloutBuilder cb =
                new CalloutBuilder('https://example.com')
                    .withEndpoint('/test?a=1')
                    .withQueryParameter('b', '2');
        Test.stopTest();
        Assert.areEqual(
            'https://example.com/test?a=1&b=2',
            cb.constructFullEndpoint(),
            'Parameters should extend the existing query string, not start a second one'
        );
    }

    @isTest
    static void testBodyWinsOverQueryParametersForNonGet() {
        CaptureMock mock = new CaptureMock();
        DummyResponse body = new DummyResponse();
        body.value = 'kept';

        Test.startTest();
            new CalloutBuilder('https://example.com')
                .withEndpoint('/test')
                .withMethod('POST')
                .withBody(body)
                .withQueryParameter('param1', 'value1')
                .withMockIfTest(mock)
                .getHttpResponse();
        Test.stopTest();
        Assert.areEqual(
            '{"value":"kept"}',
            mock.capturedRequest.getBody(),
            'An object body should be serialized and win over query parameters'
        );
    }

    @isTest
    static void testWithQueryParameterError() {
        try {
            Test.startTest();
                new CalloutBuilder('callout:ErrorTest')
                    .withEndpoint('/fail')
                    .withQueryParameter(null, 'value');
            Test.stopTest();
            Assert.fail('Expected error not thrown');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.areEqual('Query parameter key must be provided', e.getMessage(), 'Unexpected error message');
        }
    }

    @isTest
    static void testWithQueryParametersError() {
        try {
            Test.startTest();
                new CalloutBuilder('callout:ErrorTest')
                    .withQueryParameters(new Map<String,String> {'' => 'value1'});
            Test.stopTest();
            Assert.fail('Expected error not thrown');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.areEqual('Query parameter key must be provided', e.getMessage(), 'Unexpected error message');
        }
    }

    @isTest
    static void testWithEndpointManySlashes() {
        Test.startTest();
            CalloutBuilder cb =
                new CalloutBuilder('https://example.com/')
                    .withEndpoint('/test');
        Test.stopTest();
        Assert.areEqual('https://example.com/test', cb.constructFullEndpoint(), 'Unexpected endpoint');
    }

    @isTest
    static void testWithFile() {
        Test.startTest();
            CalloutBuilder cb =
                new CalloutBuilder('https://example.com')
                    .withEndpoint('/test')
                    .withFile(CalloutHexFormBuilder.build().writeFile('file.txt', Blob.valueOf('Test file content')))
                    .withMockIfTest(new SuccessMock());
            Map<String, Object> resMap = cb.getResponseBodyMap();
        Test.stopTest();
        Assert.areEqual('Success', (String) resMap.get('value'), 'Unexpected res.value');
    }

    @isTest
    static void testWithFilePlainAndJsonParameters() {
        Test.startTest();
            CalloutBuilder cb =
                new CalloutBuilder('https://example.com')
                    .withEndpoint('/test')
                    .withFile(
                        CalloutHexFormBuilder.build()
                            .writeParameter('description', 'hello')
                            .writeJsonParameter('profile', '{"name":"test"}')
                            .writeFile('file.txt', Blob.valueOf('Test file content'))
                    )
                    .withMockIfTest(new SuccessMock());
            Map<String, Object> resMap = cb.getResponseBodyMap();
        Test.stopTest();
        Assert.areEqual('Success', (String) resMap.get('value'), 'Unexpected res.value');
    }

    @isTest
    static void testWithFilePlainOnlyParameters() {
        Test.startTest();
            CalloutBuilder cb =
                new CalloutBuilder('https://example.com')
                    .withEndpoint('/test')
                    .withFile(
                        CalloutHexFormBuilder.build()
                            .writeParameter('label', 'myfile')
                            .writeFile('file.txt', Blob.valueOf('Test file content'))
                    )
                    .withMockIfTest(new SuccessMock());
            Map<String, Object> resMap = cb.getResponseBodyMap();
        Test.stopTest();
        Assert.areEqual('Success', (String) resMap.get('value'), 'Unexpected res.value');
    }

    @isTest
    static void testGetResponseBodyAsBlob() {
        Test.startTest();
            CalloutBuilder cb =
                new CalloutBuilder('https://example.com')
                    .withEndpoint('/test')
                    .withMockIfTest(new SuccessMock());
            Blob responseBodyBlob = cb.getResponseBodyAsBlob();
        Test.stopTest();
        Assert.isNotNull(responseBodyBlob, 'responseBodyBlob should not be null');
    }

    @isTest
    static void testDebugMode() {
        Exception e;
        Test.startTest();
            try {
                CalloutBuilder cb =
                    new CalloutBuilder('callout:Test')
                        .withEndpoint('/test')
                        .withDebugMode(true)
                        .withMockIfTest(new SuccessMock());
                cb.getHttpResponse();
            } catch (Exception ex) {
                e = ex;
            }
        Test.stopTest();
        Assert.isNull(e, 'Debug mode enabled should not cause an exception');
    }

    @IsTest
    static void testBuilderToMockOverrideAppliesToMatchingScope() {
        CalloutBuilder keyBuilder = new CalloutBuilder('callout:Test').withEndpoint('/test');
        CalloutBuilder.BUILDER_TO_MOCK_OVERRIDE.put(keyBuilder, new ErrorMock());

        try {
            Test.startTest();
                new CalloutBuilder('callout:Test')
                    .withEndpoint('/test')
                    .withErrorType(DummyErrorResponse.class)
                    .withMockIfTest(new SuccessMock())
                    .getHttpResponse();
            Test.stopTest();

            Assert.fail('Expected exception not thrown');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.isTrue(e.getMessage().contains('Something went wrong'), 'Unexpected error message');
        }
    }

    @IsTest
    static void testBuilderToMockOverrideIgnoresDifferentScope() {
        CalloutBuilder keyBuilder = new CalloutBuilder('callout:Test').withEndpoint('/other');
        CalloutBuilder.BUILDER_TO_MOCK_OVERRIDE.put(keyBuilder, new ErrorMock());

        Test.startTest();
            DummyResponse res = (DummyResponse) new CalloutBuilder('callout:Test')
                .withEndpoint('/test')
                .withSuccessType(DummyResponse.class)
                .withMockIfTest(new SuccessMock())
                .getTypedResponseBody();
        Test.stopTest();

        Assert.areEqual('Success', res.value, 'Default mock should be used for different scope');
    }

    private class RetrierTest implements CalloutRetrier {
        public Boolean shouldRetry(HttpResponse response) {
            return response.getStatusCode() == 500;
        }
    }

    @IsTest
    static void testErrorDeserializationFallsBackOnBadJson() {
        CalloutBuilder builder = new CalloutBuilder('callout:ErrorTest')
            .withEndpoint('/fail')
            .withErrorType(DummyErrorResponse.class)
            .withMockIfTest(new MalformedErrorMock());
        try {
            Test.startTest();
                builder.getHttpResponse();
            Test.stopTest();

            Assert.fail('Expected error not thrown');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.isTrue(e.getMessage().contains('not valid json'), 'Expected raw body fallback');
            Assert.isNull(builder.getError(), 'Expected error to be null when deserialization fails');
        }
    }

    @IsTest
    static void testExceptionCarriesStatusCode() {
        CalloutBuilder.CalloutBuilderException caught;

        Test.startTest();
            try {
                new CalloutBuilder('callout:ErrorTest')
                    .withEndpoint('/fail')
                    .withMockIfTest(new ErrorMock())
                    .getHttpResponse();
            } catch (CalloutBuilder.CalloutBuilderException e) {
                caught = e;
            }
        Test.stopTest();

        Assert.isNotNull(caught, 'A >=400 response should throw');
        Assert.areEqual(400, caught.code, 'The exception should carry the HTTP status code');
    }

    @IsTest
    static void testGuardrailBlocksCalloutBeforeSending() {
        CaptureMock mock = new CaptureMock();
        CalloutBuilder.CalloutBuilderException caught;

        Test.startTest();
            try {
                new CalloutBuilder('https://example.com')
                    .withEndpoint('/test')
                    .withGuardrails(new List<CalloutGuardrail>{ new BlockingGuardrail() })
                    .withMockIfTest(mock)
                    .getHttpResponse();
            } catch (CalloutBuilder.CalloutBuilderException e) {
                caught = e;
            }
        Test.stopTest();

        Assert.areEqual('Blocked by test guardrail', caught?.getMessage(), 'A throwing guardrail should block');
        Assert.isNull(mock.capturedRequest, 'No request should be sent');
    }

    @IsTest
    static void testGuardrailsRunInAttachedOrder() {
        CaptureMock mock = new CaptureMock();

        Test.startTest();
            new CalloutBuilder('https://example.com')
                .withEndpoint('/test')
                .withGuardrails(new List<CalloutGuardrail>{ new RecordingGuardrail('first') })
                .withGuardrails(new List<CalloutGuardrail>{ new RecordingGuardrail('second') })
                .withMockIfTest(mock)
                .getHttpResponse();
        Test.stopTest();

        Assert.areEqual(
            new List<String>{ 'first', 'second' },
            guardrailLog,
            'Guardrails should run in the order attached, accumulating across calls'
        );
        Assert.isNotNull(mock.capturedRequest, 'A passing chain should let the callout through');
    }

    @IsTest
    static void testGuardrailCannotExecuteItsOwnBuilder() {
        CaptureMock mock = new CaptureMock();

        try {
            Test.startTest();
                new CalloutBuilder('https://example.com')
                    .withEndpoint('/test')
                    .withGuardrails(new List<CalloutGuardrail>{ new RecursiveGuardrail() })
                    .withMockIfTest(mock)
                    .getHttpResponse();
            Test.stopTest();
            Assert.fail('Expected error not thrown');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.isTrue(e.getMessage().contains('must not execute'), 'Unexpected message: ' + e.getMessage());
            Assert.isNull(mock.capturedRequest, 'No request should be sent');
        }
    }

    private static List<String> guardrailLog = new List<String>();

    private class RecordingGuardrail implements CalloutGuardrail {
        private final String name;

        private RecordingGuardrail(String name) {
            this.name = name;
        }

        public void enforce(CalloutBuilder builder) {
            guardrailLog.add(this.name);
        }
    }

    private class BlockingGuardrail implements CalloutGuardrail {
        public void enforce(CalloutBuilder builder) {
            throw new CalloutBuilder.CalloutBuilderException('Blocked by test guardrail');
        }
    }

    private class RecursiveGuardrail implements CalloutGuardrail {
        public void enforce(CalloutBuilder builder) {
            builder.getHttpResponse();
        }
    }

    // A mock class to simulate a successful callout
    class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"value": "Success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    // A mock class capturing the request it responded to
    class CaptureMock implements HttpCalloutMock {
        public HttpRequest capturedRequest;

        public HTTPResponse respond(HTTPRequest req) {
            this.capturedRequest = req;
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"value": "Success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    // A mock class to simulate a failed callout with JSON error
    class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "Something went wrong"}');
            res.setStatusCode(400);
            return res;
        }
    }

    // Dummy response class
    public class DummyResponse {
        public String value;
    }

    // Error response implementation
    public class DummyErrorResponse implements CalloutErrorResponse {
        public String message;
        public String getErrorMessage() {
            return message;
        }
    }

    // A mock that returns a 400 with a non-JSON body to trigger deserialization failure
    class MalformedErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('not valid json');
            res.setStatusCode(400);
            return res;
        }
    }
}