# CalloutBuilder

## Purpose

Establishing unified callout approach with basic response handling backed in.

## Structure

1. [CalloutBuilder](CalloutBuilder.cls) - main class. `virtual`, so behavior can be added around a callout by subclassing it — every response variant funnels through `getHttpResponse()`.
2. [CalloutErrorResponse](CalloutErrorResponse.cls) - interface enabling CalloutBuilder to extract error message from any error object.
3. [CalloutRetrier](CalloutRetrier.cls) - interface enabling CalloutBuilder to retry a callout and to change something before the new attempt.
4. [CalloutGuardrail](CalloutGuardrail.cls) - interface for a check that runs before a callout and can block it. Attach implementations with `withGuardrail()` or `withGuardrails()`. [CalloutGuardrailException](CalloutGuardrailException.cls) is the exception a guardrail throws to block.
5. [CalloutResponseSanitizer](CalloutResponseSanitizer.cls) - interface for a transformation applied to a validated response before the caller sees it. Attach implementations with `withResponseSanitizer()` or `withResponseSanitizers()`. [CalloutResponseSanitizerException](CalloutResponseSanitizerException.cls) is the exception a sanitizer throws to block.
6. [CalloutBuilderQueueable](CalloutBuilderQueueable.cls) - virtual class to run one or many callouts asynchronously, for example, from a trigger.
7. [CalloutCollection](CalloutCollection.cls) - virtual class which is bundling many CalloutBuilder instances, callout preparation and post processing for [CalloutBuilderQueueable](CalloutCollection.cls).
8. [CalloutHexFormBuilder](CalloutHexFormBuilder.cls) - a class to build multipart requests to enable sending files. It's used in `withFile()` method of the CalloutBuilder, and may be used separately. **NOTE:** It's resource-intensive and may reach heap limit when processing files of more than 2 Mb in size. It's recommended to send files up to 2 Mb.
9. [MimeType](MimeType.cls) - a class to resolve popular mime types by file extension. It's used by [CalloutHexFormBuilder](CalloutHexFormBuilder.cls) and can be helpful by itself.

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

- When the endpoint already carries a query string, parameters extend it with `&` rather than starting a second one: `withEndpoint('/test?a=1')` + `withQueryParameter('b', '2')` → `https://example.com/test?a=1&b=2`

#### Request Body Note

If you set a body using `.withBody()`, it _will not be overwritten_ by query parameters — whatever the body's type.

### Sending Files _(OpenAI Assistants API Example)_

Build the multipart form with `CalloutHexFormBuilder`, then pass it to `.withFile()`:

```Java (Apex)
CalloutHexFormBuilder formBuilder = CalloutHexFormBuilder.build()
    .writeParameter('purpose', 'assistants')
    .writeFile('test.txt', file); // file can be Blob or base64 String

HttpResponse response = new CalloutBuilder('callout:OpenAI_NC')
    .withEndpoint('/files')
    .withMethod('POST')
    .withFile(formBuilder)
    .getHttpResponse();
```

#### CalloutHexFormBuilder methods

| Method | Description |
| --- | --- |
| `writeParameter(key, value)` | Plain text form field |
| `writeJsonParameter(key, value)` | JSON form field (`Content-Type: application/json`) |
| `writeJsonParameters(Map<String,String>)` | Bulk JSON form fields |
| `writeFile(fileName, content)` | File part — `content` may be `Blob` or base64 `String` |

---

### Guardrails

`withGuardrail()` attaches one check that runs before the request is constructed, `withGuardrails()` a list of them. A guardrail blocks the callout by throwing; returning normally allows it. Repeated calls append, and the chain runs in the order attached.

```Java (Apex)
public with sharing class ProductionOnlyGuardrail implements CalloutGuardrail {
    public void enforce(CalloutBuilder builder) {
        if (builder.getEndpoint().startsWith('/debug')) {
            throw new CalloutGuardrailException('Debug endpoints are not callable.');
        }
    }
}

new CalloutBuilder('callout:MyService')
    .withEndpoint('/v1/resource')
    .withGuardrail(new ProductionOnlyGuardrail())
    .getHttpResponse();
```

A guardrail reads the request through the builder's accessors — `getEndpoint()`, `getMethod()`, `getHeaders()`, `getQueryParameters()`, `constructFullEndpoint()` — and must not execute the builder it is inspecting; doing so throws `CalloutBuilderException`.

---

### Response Sanitizers

`withResponseSanitizer()` attaches one transformation applied to the response before the caller sees it, `withResponseSanitizers()` a list of them. A sanitizer rewrites the body with `setBody()`, or blocks the response by throwing. Repeated calls append, the chain runs in the order attached, and each sanitizer sees the previous one's output.

```Java (Apex)
public with sharing class RestrictedFolderSanitizer implements CalloutResponseSanitizer {
    public void sanitize(HttpResponse response) {
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        body.put('results', this.withoutRestrictedFolders((List<Object>) body.get('results')));
        response.setBody(JSON.serialize(body));
    }
}

new CalloutBuilder('callout:MyService')
    .withEndpoint('/v1/search')
    .withResponseSanitizer(new RestrictedFolderSanitizer())
    .getResponseBodyMap();
```

Sanitizers run after validation, so the retrier, the `>= 400` error path, and `withDebugMode(true)` all see the raw response — sanitizing is not log redaction. Error responses are therefore never sanitized, unless `withBypassResponseValidation(true)` lets them through. Throw rather than return a body that could not be parsed. A binary response needs `setBodyAsBlob()`, and a sanitizer must not execute the builder it is sanitizing; doing so throws `CalloutBuilderException`.

---

### Error Handling

When the response status is ≥ 400, `CalloutBuilderException` is thrown. The exception carries the HTTP context of the failed response — `code` (status code, e.g. `404`) and `status` (status text, e.g. `'Not Found'`). If `.withErrorType()` is set and the body is valid JSON, the deserialized error object is also accessible via `builder.getError()` after the exception is caught:

```Java (Apex)
CalloutBuilder builder = new CalloutBuilder('callout:MyService')
    .withEndpoint('/resource')
    .withErrorType(MyErrorResponse.class);
try {
    builder.getHttpResponse();
} catch (CalloutBuilder.CalloutBuilderException e) {
    if (e.code == 429) {
        // e.g. schedule a later retry instead of failing
    }
    MyErrorResponse err = (MyErrorResponse) builder.getError();
    // err is null when the body is blank or not valid JSON
}
```

Both `code` and `status` are null when the exception is thrown before a callout is made — e.g. a validation error during builder configuration.

---

### Mock Overrides

`CalloutBuilder.BUILDER_TO_MOCK_OVERRIDE` lets a test override the mock for a specific endpoint and HTTP method, without touching the production code that creates the builder.

```Java (Apex)
// In a test — override the mock for POST /payments only
CalloutBuilder mockTarget = new CalloutBuilder('callout:PaymentsNC').withEndpoint('/payments').withMethod('POST');
CalloutBuilder.BUILDER_TO_MOCK_OVERRIDE.put(mockTarget, new PaymentErrorMock());

// Any CalloutBuilder targeting the same URL + method picks up PaymentErrorMock,
// even if it has its own .withMockIfTest() set.
```

The override is matched by `constructFullEndpoint()` and `getMethod()`. Builders targeting different URLs or methods are unaffected.
