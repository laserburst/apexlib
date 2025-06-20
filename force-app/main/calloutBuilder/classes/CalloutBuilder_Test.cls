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
        try {
            Test.startTest();
                new CalloutBuilder('callout:ErrorTest')
                    .withEndpoint('/fail')
                    .withErrorType(DummyErrorResponse.class)
                    .withMockIfTest(new ErrorMock())
                    .getHttpResponse();
            Test.stopTest();

            Assert.fail('Expected error not thrown');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.isTrue(e.getMessage().contains('Something went wrong'), 'Unexpected error message');
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
        Test.startTest();
            CalloutBuilder cb =
                new CalloutBuilder('https://example.com')
                    .withEndpoint('/test')
                    .withMethod('POST')
                    .withQueryParameters(new Map<String, String>{ 'param1' => 'value1', 'param2' => 'value2' })
                    .withQueryParameter('param3', 'value3')
                    .withMockIfTest(new SuccessMock());
            Map<String, Object> resMap = cb.getResponseBodyMap();
        Test.stopTest();
        String expectedUrl = 'https://example.com/test'; // POST requests do not include query parameters in the URL
        Assert.areEqual(expectedUrl, cb.constructFullEndpoint(), 'Unexpected endpoint URL');
        Assert.areEqual('Success', (String) resMap.get('value'), 'Unexpected res.value');
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
                    .withFile(Blob.valueOf('Test file content'), 'file.txt', null)
                    .withMockIfTest(new SuccessMock());
            Map<String, Object> resMap = cb.getResponseBodyMap();
        Test.stopTest();
        Assert.areEqual('Success', (String) resMap.get('value'), 'Unexpected res.value');
    }

    private class RetrierTest implements CalloutRetrier {
        public Boolean shouldRetry(HttpResponse response) {
            return response.getStatusCode() == 500;
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
}
