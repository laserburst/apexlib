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
            Assert.isInstanceOfType(e.getError(), DummyErrorResponse.class, 'Expected the exception to carry the parsed error');
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

    @IsTest
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

    @IsTest
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

    @IsTest
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

    @IsTest
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

    @IsTest
    static void testBodyFollowsContentType() {
        CaptureMock xmlMock = new CaptureMock();
        CaptureMock jsonMock = new CaptureMock();
        CaptureMock defaultMock = new CaptureMock();
        CaptureMock documentMock = new CaptureMock();
        CaptureMock serializableMock = new CaptureMock();
        CaptureMock blobMock = new CaptureMock();
        Dom.Document document = new Dom.Document();
        document.createRootElement('item', null, null).addTextNode('kept');

        Test.startTest();
            new CalloutBuilder('https://example.com')
                .withEndpoint('/test')
                .withMethod('POST')
                .withHeader('content-type', 'text/xml; charset=utf-8')
                .withBody('<a/>')
                .withMockIfTest(xmlMock)
                .getHttpResponse();
            new CalloutBuilder('https://example.com')
                .withEndpoint('/test')
                .withMethod('POST')
                .withHeader('Content-Type', 'application/vnd.api+json')
                .withBody('x')
                .withMockIfTest(jsonMock)
                .getHttpResponse();
            new CalloutBuilder('https://example.com')
                .withEndpoint('/test')
                .withMethod('POST')
                .withBody(new Map<String, Object>{ 'a' => 1 })
                .withMockIfTest(defaultMock)
                .getHttpResponse();
            new CalloutBuilder('https://example.com')
                .withEndpoint('/test')
                .withMethod('POST')
                .withBody(document)
                .withMockIfTest(documentMock)
                .getHttpResponse();
            new CalloutBuilder('https://example.com')
                .withEndpoint('/test')
                .withMethod('POST')
                .withBody(new DummyXmlBody())
                .withMockIfTest(serializableMock)
                .getHttpResponse();
            new CalloutBuilder('https://example.com')
                .withEndpoint('/test')
                .withMethod('POST')
                .withBlobBody(Blob.valueOf('x'))
                .withMockIfTest(blobMock)
                .getHttpResponse();
        Test.stopTest();
        Assert.areEqual('<a/>', xmlMock.capturedRequest.getBody(), 'A String body with a non-JSON Content-Type should be sent as-is');
        Assert.areEqual('"x"', jsonMock.capturedRequest.getBody(), 'A String body with a +json Content-Type should be serialized');
        Assert.areEqual(
            'application/json',
            defaultMock.capturedRequest.getHeader('Content-Type'),
            'A serialized body without a Content-Type should default to JSON'
        );
        Assert.areEqual(document.toXmlString(), documentMock.capturedRequest.getBody(), 'A Dom.Document body should be sent as XML');
        Assert.areEqual(
            'application/xml',
            documentMock.capturedRequest.getHeader('Content-Type'),
            'A Dom.Document body without a Content-Type should default to XML'
        );
        Assert.areEqual('<item>kept</item>', serializableMock.capturedRequest.getBody(), 'A CalloutXmlSerializable body should be sent as XML');
        Assert.areEqual(
            'application/xml',
            serializableMock.capturedRequest.getHeader('Content-Type'),
            'A CalloutXmlSerializable body without a Content-Type should default to XML'
        );
        Assert.areEqual(
            'application/octet-stream',
            blobMock.capturedRequest.getHeader('Content-Type'),
            'A blob body without a Content-Type should default to binary'
        );
    }

    @IsTest
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

    @IsTest
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

    @IsTest
    static void testWithEndpointManySlashes() {
        Test.startTest();
            CalloutBuilder cb =
                new CalloutBuilder('https://example.com/')
                    .withEndpoint('/test');
        Test.stopTest();
        Assert.areEqual('https://example.com/test', cb.constructFullEndpoint(), 'Unexpected endpoint');
        Assert.areEqual('/test', cb.getEndpoint(), 'The endpoint should keep its leading slash');
    }

    @IsTest
    static void testUnfilledPlaceholderThrowsBeforeGuardrails() {
        CaptureMock mock = new CaptureMock();
        String message;
        try {
            new CalloutBuilder('callout:Test')
                .withEndpoint('/items/{id}')
                .withGuardrail(new BlockingGuardrail())
                .withMockIfTest(mock)
                .getHttpResponse();
        } catch (CalloutBuilder.CalloutBuilderException e) {
            message = e.getMessage();
        }
        Assert.areEqual(
            'Endpoint has a placeholder without a path parameter: /items/{id}',
            message,
            'Placeholders should resolve before guardrails run'
        );
        Assert.isNull(mock.capturedRequest, 'No request should be sent');
    }

    @IsTest
    static void testPathParametersBeforeQueryParameters() {
        CalloutBuilder search = new CalloutBuilder('callout:Test')
            .withEndpoint('/search?q={term}')
            .withPathParameters(new Map<String, String>{ 'term' => 'a b&c' })
            .withQueryParameter('page', '2');
        Assert.areEqual(
            'callout:Test/search?q=a%20b%26c&page=2',
            search.constructFullEndpoint(),
            'A placeholder in the query should resolve before query parameters are appended'
        );
        Assert.areEqual('a b&c', search.getPathParameters().get('term'), 'getPathParameters should return raw values');
    }

    @IsTest
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

    @IsTest
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

    @IsTest
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

    @IsTest
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

    @IsTest
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
        CalloutGuardrailException caught;

        Test.startTest();
            try {
                new CalloutBuilder('https://example.com')
                    .withEndpoint('/test')
                    .withGuardrails(new List<CalloutGuardrail>{ new BlockingGuardrail() })
                    .withMockIfTest(mock)
                    .getHttpResponse();
            } catch (CalloutGuardrailException e) {
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
                .withGuardrail(new RecordingGuardrail('second'))
                .withMockIfTest(mock)
                .getHttpResponse();
        Test.stopTest();

        Assert.areEqual(
            new List<String>{ 'first', 'second' },
            guardrailLog,
            'Guardrails should run in the order attached, accumulating across calls and across both overloads'
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
            throw new CalloutGuardrailException('Blocked by test guardrail');
        }
    }

    private class RecursiveGuardrail implements CalloutGuardrail {
        public void enforce(CalloutBuilder builder) {
            builder.getHttpResponse();
        }
    }

    @IsTest
    static void testSanitizerMutatesTypedBody() {
        Test.startTest();
            DummyResponse res = (DummyResponse) new CalloutBuilder('callout:Test')
                .withEndpoint('/test')
                .withSuccessType(DummyResponse.class)
                .withResponseSanitizer(new ScrubbingSanitizer())
                .withMockIfTest(new SuccessMock())
                .getTypedResponseBody();
        Test.stopTest();

        Assert.areEqual('Sanitized', res.value, 'A sanitized body should reach the typed response');
        Assert.areEqual(1, sanitized.size(), 'Only the parsed body should be sanitized, not the HttpResponse');
    }

    @IsTest
    static void testSanitizerMutatesDocumentBody() {
        Test.startTest();
            Dom.Document res = new CalloutBuilder('callout:Test')
                .withEndpoint('/test')
                .withResponseSanitizer(new ScrubbingSanitizer())
                .withMockIfTest(new XmlMock())
                .getXmlResponseBody();
        Test.stopTest();

        Assert.areEqual(1, sanitized.size(), 'Only the parsed body should be sanitized, not the HttpResponse');
        Assert.isNotNull(res.getRootElement().getChildElement('scrubbed', null), 'A sanitized body should reach the caller');
        Assert.areEqual('a <b> & c', res.getRootElement().getChildElement('note', null).getText(), 'CDATA content should be kept');
    }

    @IsTest
    static void testXmlResponsesAndErrors() {
        String message;
        Test.startTest();
            DummyResponse typed = (DummyResponse) new CalloutBuilder('callout:Test')
                .withEndpoint('/test')
                .withSuccessType(DummyResponse.class)
                .withMockIfTest(new XmlMock())
                .getTypedResponseBody();
            Map<String, Object> custom = new CalloutBuilder('callout:Test')
                .withEndpoint('/test')
                .withResponseParser(new CalloutXmlParser().withListElements(new Set<String>{ 'value' }))
                .withMockIfTest(new XmlMock())
                .getResponseBodyMap();
            try {
                new CalloutBuilder('callout:Test')
                    .withEndpoint('/test')
                    .withErrorType(DummyErrorResponse.class)
                    .withMockIfTest(new XmlErrorMock())
                    .getHttpResponse();
            } catch (CalloutBuilder.CalloutBuilderException e) {
                message = e.getMessage();
            }
        Test.stopTest();

        Assert.areEqual('Success', typed.value, 'An XML Content-Type should select the default parser');
        Assert.areEqual(new List<Object>{ 'Success' }, custom.get('value'), 'A custom parser should be used');
        Assert.areEqual(
            'Something went wrong',
            message,
            'A lowercase XML Content-Type with parameters should parse the error into the error type'
        );
    }

    @IsTest
    static void testSanitizersRunInAttachedOrderAndChain() {
        Test.startTest();
            HttpResponse response = new CalloutBuilder('callout:Test')
                .withEndpoint('/test')
                .withResponseSanitizers(new List<CalloutResponseSanitizer>{ new AppendingSanitizer('first') })
                .withResponseSanitizer(new AppendingSanitizer('second'))
                .withMockIfTest(new SuccessMock())
                .getHttpResponse();
        Test.stopTest();

        Assert.isTrue(
            response.getBody().endsWith('firstsecond'),
            'Sanitizers should run in the order attached across both overloads, each seeing the previous one output, got: '
                + response.getBody()
        );
    }

    @IsTest
    static void testSanitizerBlocksResponse() {
        CaptureMock mock = new CaptureMock();
        CalloutResponseSanitizerException caught;

        Test.startTest();
            try {
                new CalloutBuilder('https://example.com')
                    .withEndpoint('/test')
                    .withResponseSanitizer(new BlockingSanitizer())
                    .withMockIfTest(mock)
                    .getHttpResponse();
            } catch (CalloutResponseSanitizerException e) {
                caught = e;
            }
        Test.stopTest();

        Assert.areEqual('Blocked by test sanitizer', caught?.getMessage(), 'A throwing sanitizer should block');
        Assert.isNotNull(mock.capturedRequest, 'The request is sent; only the response is blocked');
    }

    @IsTest
    static void testSanitizerCannotExecuteItsOwnBuilder() {
        CaptureMock mock = new CaptureMock();
        RecursiveSanitizer sanitizer = new RecursiveSanitizer();
        CalloutBuilder cb = new CalloutBuilder('https://example.com')
            .withEndpoint('/test')
            .withResponseSanitizer(sanitizer)
            .withMockIfTest(mock);
        sanitizer.builder = cb;

        try {
            Test.startTest();
                cb.getHttpResponse();
            Test.stopTest();
            Assert.fail('Expected error not thrown');
        } catch (CalloutBuilder.CalloutBuilderException e) {
            Assert.isTrue(e.getMessage().contains('must not execute'), 'Unexpected message: ' + e.getMessage());
            Assert.areEqual(1, mock.callCount, 'The re-entered callout should be rejected before it is sent');
        }
    }

    @IsTest
    static void testSanitizerBlocksFormItDoesNotOverride() {
        CalloutResponseSanitizer sanitizer = new UnsupportingSanitizer();
        Integer blocked = 0;

        try {
            sanitizer.sanitize(new HttpResponse());
        } catch (CalloutResponseSanitizerException e) {
            blocked++;
        }
        try {
            sanitizer.sanitize(new Map<String, Object>());
        } catch (CalloutResponseSanitizerException e) {
            blocked++;
        }
        try {
            sanitizer.sanitize(new DummyResponse(), DummyResponse.class);
        } catch (CalloutResponseSanitizerException e) {
            blocked++;
        }
        try {
            sanitizer.sanitize(new Dom.Document());
        } catch (CalloutResponseSanitizerException e) {
            blocked++;
        }

        Assert.areEqual(4, blocked, 'Every overload not overridden should block');
    }

    @IsTest
    static void testErrorResponseIsNotSanitized() {
        Test.startTest();
            try {
                new CalloutBuilder('callout:ErrorTest')
                    .withEndpoint('/fail')
                    .withResponseSanitizer(new ScrubbingSanitizer())
                    .withMockIfTest(new ErrorMock())
                    .getHttpResponse();
                Assert.fail('Expected error not thrown');
            } catch (CalloutBuilder.CalloutBuilderException e) {
                Assert.isTrue(e.getMessage().contains('Something went wrong'), 'The error path should see the raw body');
            }
        Test.stopTest();

        Assert.isTrue(sanitized.isEmpty(), 'Sanitizers should not run on a response that fails validation');
    }

    @IsTest
    static void testSanitizerRunsWhenValidationBypassed() {
        Test.startTest();
            Map<String, Object> resMap = new CalloutBuilder('callout:ErrorTest')
                .withEndpoint('/fail')
                .withBypassResponseValidation(true)
                .withResponseSanitizer(new ScrubbingSanitizer())
                .withMockIfTest(new ErrorMock())
                .getResponseBodyMap();
        Test.stopTest();

        Assert.areEqual(
            'scrubbed',
            (String) resMap.get('message'),
            'Every response the caller sees passes sanitization, including a bypassed error response'
        );
    }

    private static List<Object> sanitized = new List<Object>();

    private class AppendingSanitizer extends CalloutResponseSanitizer {
        private final String name;

        private AppendingSanitizer(String name) {
            this.name = name;
        }

        public override void sanitize(HttpResponse response) {
            response.setBody(response.getBody() + this.name);
        }
    }

    private class ScrubbingSanitizer extends CalloutResponseSanitizer {
        public override void sanitize(HttpResponse response) {
            sanitized.add(response);
        }

        public override void sanitize(Map<String, Object> body) {
            sanitized.add(body);
            body.put('message', 'scrubbed');
        }

        public override void sanitize(Object body, System.Type successType) {
            Assert.areEqual(DummyResponse.class, successType, 'The success type should be passed along');
            sanitized.add(body);
            ((DummyResponse) body).value = 'Sanitized';
        }

        public override void sanitize(Dom.Document body) {
            sanitized.add(body);
            body.getRootElement().addChildElement('scrubbed', null, null);
        }
    }

    private class UnsupportingSanitizer extends CalloutResponseSanitizer {
    }

    private class BlockingSanitizer extends CalloutResponseSanitizer {
        public override void sanitize(HttpResponse response) {
            throw new CalloutResponseSanitizerException('Blocked by test sanitizer');
        }
    }

    private class RecursiveSanitizer extends CalloutResponseSanitizer {
        public CalloutBuilder builder;

        public override void sanitize(HttpResponse response) {
            this.builder.getHttpResponse();
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

    // A mock class to simulate a successful callout with an XML body
    class XmlMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/xml');
            res.setBody('<item><value>Success</value><note>a <![CDATA[<b> & c]]></note></item>');
            res.setStatusCode(200);
            return res;
        }
    }

    // A mock class to simulate a failed callout with an XML error
    class XmlErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('content-type', 'text/xml; charset=utf-8');
            res.setBody('<error><message>Something went wrong</message></error>');
            res.setStatusCode(400);
            return res;
        }
    }

    // A mock class capturing the request it responded to
    class CaptureMock implements HttpCalloutMock {
        public HttpRequest capturedRequest;
        public Integer callCount = 0;

        public HTTPResponse respond(HTTPRequest req) {
            this.capturedRequest = req;
            this.callCount++;
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

    private class DummyXmlBody implements CalloutXmlSerializable {
        public CalloutXmlBuilder toXmlBuilder() {
            return new CalloutXmlBuilder('item').withText('kept');
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