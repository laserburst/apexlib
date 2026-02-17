# CalloutBuilder

## Purpose

Establishing unified callout approach with basic response handling backed in.

## Structure

1. [CalloutBuilder](CalloutBuilder.cls) - main class.
2. [CalloutErrorResponse](CalloutErrorResponse.cls) - interface enabling CalloutBuilder to extract error message from any error object.
3. [CalloutRetrier](CalloutRetrier.cls) - interface enabling CalloutBuilder to retry a callout and to change something before the new attempt.
4. [CalloutBuilderQueueable](CalloutBuilderQueueable.cls) - virtual class to run one or many callouts asynchronously, for example, from a trigger.
5. [CalloutCollection](CalloutCollection.cls) - virtual class which is bundling many CalloutBuilder instances, callout preparation and post processing for [CalloutBuilderQueueable](CalloutCollection.cls).
6. [CalloutHexFormBuilder](CalloutHexFormBuilder.cls) - a class to build multipart requests to enable sending files. It's used in `withFile()` method of the CalloutBuilder, and may be used separately. **NOTE:** It's resource-intensive and may reach heap limit when processing files of more than 2 Mb in size. It's recommended to send files up to 2 Mb.
7. [MimeType](MimeType.cls) - a class to resolve popular mime types by file extension. It's used by [CalloutHexFormBuilder](CalloutHexFormBuilder.cls) and can be helpful by itself.

## Examples (illustrative)

### Concrete Type

```Java (Apex)
CalloutBuilder cb = new CalloutBuilder(NC)
    .withEndpoint('api/dialog-tokens')
    .withMethod('POST')
    .withHeader('key', 'value')
    .withHeaders(new Map<String, String>{ 'key_2' => 'value_2' })
    .withTimeout(30000)
    .withSuccessType(ExampleResponse.DialogToken.class)
    .withErrorType(ExampleResponse.Error.class)
    .withMockIfTest(new DialogTokenMock())
    .withRetrier(new ExampleRetrier())
    .withMaxRetries(2)
    .withDebugMode(true);

ExampleResponse.DialogToken tokenResponse = (ExampleResponse.DialogToken)cb.getTypedResponseBody();
```

[Full Example](example/ExampleApi.cls)

### Response Body Map With Query Parameters

```Java (Apex)
CalloutBuilder cb = new CalloutBuilder('https://example.com')
    .withEndpoint('/test')
    .withMethod('GET')
    .withHeader('Content-Type', 'application/x-www-form-urlencoded')
    .withQueryParameter('param1', 'value1')
    .withQueryParameters(new Map<String, String>{
        'param2' => 'value2',
        'param3' => 'value3'
    });

Map<String, Object> responseBody = cb.getResponseBodyMap();
```

#### Debug Mode

We can enable debug mode by setting the `debugMode` flag to `true` in the `CalloutBuilder` instance.
It will print the request and response to the debug log including headers and body. Verbose bodies don't print by default.

```Java (Apex)
CalloutBuilder cb = new CalloutBuilder('https://example.com')
    .withEndpoint('/test')
    .withMethod('GET')
    .withDebugMode(true);

Map<String, Object> responseBody = cb.getResponseBodyMap();
```

#### URL Behavior

- For `GET` requests, query parameters _(UTF-8 encoded)_ are appended to the URL: `https://example.com/test?param1=value1&param2=value2&param3=value3`

- For other HTTP methods (e.g., `POST`), parameters are included in the body instead, and the URL remains: `https://example.com/test`

#### Request Body Note

If you set a body using `.withBody()`, it _will not be overwritten_ by query parameters.

### Sending Files _(OpenAI Assistants API Example)_

```Java (Apex)
HttpResponse response = new CalloutBuilder('callout:OpenAI_NC')
    .withEndpoint('/files')
    .withMethod('POST')
    .withFile(file, 'test.txt', new Map<String, String> { 'purpose' => 'assistants' })
    .getHttpResponse();
```
