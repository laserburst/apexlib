# CalloutBuilder

## Contents

- [Purpose](#purpose)
- [Structure](#structure)
- [Examples (illustrative)](#examples-illustrative)
  - [Concrete Type](#concrete-type)
  - [Path Parameters](#path-parameters)
  - [Response Body Map With Query Parameters](#response-body-map-with-query-parameters)
  - [Sending Files](#sending-files-openai-assistants-api-example)
  - [Guardrails](#guardrails)
  - [Response Sanitizers](#response-sanitizers)
  - [Error Handling](#error-handling)
  - [Mock Overrides](#mock-overrides)

## Purpose

Establishing unified callout approach with basic response handling backed in.

## Structure

1. [CalloutBuilder](CalloutBuilder.cls) - main class. `virtual`, so behavior can be added around a callout by subclassing it — every response variant funnels through `getHttpResponse()`. Under `getResponseBodyMap()`, `getTypedResponseBody()` and `getXmlResponseBody()` it returns the response unsanitized.
2. [CalloutErrorResponse](CalloutErrorResponse.cls) - interface enabling CalloutBuilder to extract error message from any error object.
3. [CalloutRetrier](CalloutRetrier.cls) - interface enabling CalloutBuilder to retry a callout and to change something before the new attempt.
4. [CalloutGuardrail](CalloutGuardrail.cls) - interface for a check that runs before a callout and can block it. Attach implementations with `withGuardrail()` or `withGuardrails()`. [CalloutGuardrailException](CalloutGuardrailException.cls) is the exception a guardrail throws to block.
5. [CalloutResponseSanitizer](CalloutResponseSanitizer.cls) - abstract class for a transformation applied to a validated response before the caller sees it. Attach subclasses with `withResponseSanitizer()` or `withResponseSanitizers()`. [CalloutResponseSanitizerException](CalloutResponseSanitizerException.cls) is the exception a sanitizer throws to block, and [CalloutResponseSanitizerChain](CalloutResponseSanitizerChain.cls) runs several sanitizers as one.
6. [CalloutBuilderQueueable](CalloutBuilderQueueable.cls) - virtual class to run one or many callouts asynchronously, for example, from a trigger.
7. [CalloutCollection](CalloutCollection.cls) - virtual class which is bundling many CalloutBuilder instances, callout preparation and post processing for [CalloutBuilderQueueable](CalloutCollection.cls).
8. [CalloutHexFormBuilder](CalloutHexFormBuilder.cls) - a class to build multipart requests to enable sending files. It's used in `withFile()` method of the CalloutBuilder, and may be used separately. **NOTE:** It's recommended to send files up to 5 Mb: the whole form must fit the callout request size limit, which is 10 Mb in synchronous Apex since Winter '27.
9. [MimeType](MimeType.cls) - a class to resolve popular mime types by file extension. It's used by [CalloutHexFormBuilder](CalloutHexFormBuilder.cls) and can be helpful by itself.
10. [CalloutResponseParser](CalloutResponseParser.cls) - abstract class for reading a response body into a `Map<String, Object>` or an Apex type. [CalloutJsonParser](CalloutJsonParser.cls) and [CalloutXmlParser](CalloutXmlParser.cls) extend it; `CalloutXmlParser` also loads XML into a `Dom.Document`. Pass one to `withResponseParser()`. A success or error type implements [CalloutXmlDeserializable](CalloutXmlDeserializable.cls) to name the XML elements that are Lists.

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

### Path Parameters

`withPathParameter()` fills a `{name}` placeholder with the value encoded as one path segment; pass it unencoded.

```Java (Apex)
new CalloutBuilder('callout:MyService')
    .withEndpoint('/items/{id}')
    .withPathParameter('id', itemId)
    .getHttpResponse();
```

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

A `String` body is sent as-is when a non-JSON Content-Type is set, and a `Dom.Document` body is sent as XML. `getXmlResponseBody()` returns an XML response as a `Dom.Document`, and `getTypedResponseBody()` reads it into an Apex type. Initialize its List fields, `public List<Item> item = new List<Item>();`, so that a single element still becomes a List:

```Java (Apex)
Dom.Document response = new CalloutBuilder('callout:OrdersApi')
    .withEndpoint('/orders')
    .withMethod('POST')
    .withHeader('Content-Type', 'application/xml')
    .withBody('<order><id>' + orderId.escapeXml() + '</id></order>')
    .getXmlResponseBody();
String status = response.getRootElement().getChildElement('status', null).getText();

OrderResponse order = (OrderResponse) new CalloutBuilder('callout:OrdersApi')
    .withEndpoint('/orders/{id}')
    .withPathParameter('id', orderId)
    .withSuccessType(OrderResponse.class)
    .getTypedResponseBody();
```

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

`withResponseSanitizer()` attaches one transformation applied to the response before the caller sees it, `withResponseSanitizers()` a list of them. A sanitizer extends `CalloutResponseSanitizer` and overrides a `sanitize()` overload for each form it handles: `HttpResponse` for `getHttpResponse()` and `getResponseBodyAsBlob()`, `Map<String, Object>` for `getResponseBodyMap()`, `(Object, System.Type)` for `getTypedResponseBody()`, `Dom.Document` for `getXmlResponseBody()`. An override mutates its argument in place, or blocks the response by throwing; a form not overridden is blocked. Repeated calls append, and the chain runs in the order attached on one shared instance, so the body is parsed once and each sanitizer sees the previous one's output.

```Java (Apex)
public with sharing class RestrictedFolderSanitizer extends CalloutResponseSanitizer {
    public override void sanitize(Map<String, Object> body) {
        body.put('results', this.withoutRestrictedFolders((List<Object>) body.get('results')));
    }
}

new CalloutBuilder('callout:MyService')
    .withEndpoint('/v1/search')
    .withResponseSanitizer(new RestrictedFolderSanitizer())
    .getResponseBodyMap();
```

Sanitizers run after validation, so the retrier, the `>= 400` error path, and `withDebugMode(true)` all see the raw response — sanitizing is not log redaction. Error responses are therefore never sanitized, unless `withBypassResponseValidation(true)` lets them through. Throw rather than return quietly on a body the sanitizer cannot handle. A binary response needs `setBodyAsBlob()` in the `HttpResponse` overload, and a sanitizer must not execute the builder it is sanitizing; doing so throws `CalloutBuilderException`.

---

### Error Handling

When the response status is ≥ 400, `CalloutBuilderException` is thrown. The exception carries the HTTP context of the failed response — `code` (status code, e.g. `404`) and `status` (status text, e.g. `'Not Found'`). If `.withErrorType()` is set and the body parses, the deserialized error object is also accessible via `builder.getError()` after the exception is caught:

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
    // err is null when the body is blank or doesn't parse
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
