---
name: apex-callout-builder
description: >-
  Generates and reviews Salesforce Apex HTTP callout code using the
  CalloutBuilder library. Use this skill whenever the user is
  writing, fixing, or reviewing any Apex code that makes HTTP callouts —
  including REST API integrations, named credential callouts, async callout
  jobs, file uploads, retry logic, error handling, and test mocks. Trigger on
  phrases like "callout", "HTTP request in Apex", "named credential", "API
  integration", "CalloutBuilder", "withMockIfTest", "CalloutBuilderQueueable",
  "withFile", "withGuardrail", "CalloutGuardrail", "withResponseSanitizer",
  "CalloutResponseSanitizer", "withPathParameter", "sanitize a response", or
  any question about how to call an external service from Apex.
  Do not wait for the user to name the library explicitly — if they are writing
  Apex that talks to an external API, this skill applies.
---

# ApexCalloutBuilder

Generate, explain, and review Apex HTTP callout code using the CalloutBuilder library.

---

## Step 1: Choose the right response strategy

Before writing any code, determine which execution method the user needs. This choice drives the shape of the entire callout method.

| Situation | Method to call |
|---|---|
| Response maps to a known Apex class | `getTypedResponseBody()` |
| Response structure is unknown or varies | `getResponseBodyMap()` |
| Need headers, status code, or raw body | `getHttpResponse()` |
| Response is XML | `getTypedResponseBody()` or `getResponseBodyMap()`; `getXmlResponseBody()` for the raw `Dom.Document` |
| Downloading binary content | `getResponseBodyAsBlob()` |
| Callout from a trigger or batch context | `CalloutBuilderQueueable` |

Prefer `getTypedResponseBody()` when the API contract is known — it gives compile-time safety and clean downstream code. `getResponseBodyMap()` loses type safety; only recommend it when the response shape genuinely cannot be modeled.

For XML, `getTypedResponseBody()`, `getResponseBodyMap()` and the `withErrorType()` error parse a response whose Content-Type is `application/xml`, `text/xml` or `+xml` with a default `CalloutXmlParser`. The header name and value are matched ignoring case and parameters. `withResponseParser(parser)` sets a custom parser, which is then used for every response, whatever its Content-Type; use one to name List elements for `getResponseBodyMap()` or to apply a subclass. Typed XML errors and the sanitizer's typed and Map forms work the same as for JSON. Without an XML Content-Type and without a custom parser, an XML body fails JSON parsing with `System.JSONException`. `getXmlResponseBody()` returns a `Dom.Document` and keeps CDATA text. For an XML string from elsewhere, use `CalloutXmlParser.load(xml)` rather than `Dom.Document.load()`, which drops CDATA content. `new CalloutXmlParser().deserializeUntyped(doc)` returns a `Map<String, Object>`, and `.deserialize(doc, MyType.class)` returns an Apex type. Both also accept a `Dom.XmlNode`, which is how to convert one deep subtree. The rules:

- XML has no array marker: a child element that occurs once becomes an object or a value, and `JSON.deserialize` rejects it for a List field. It becomes a List when either of these names it; attributes and `text` never become a List:
  - **An initialized field** of a new instance of the type: `public List<Item> item = new List<Item>();`. It applies at that field's path only, so a single `item` elsewhere stays an object. Best effort: it can't see inside List elements or uninitialized objects, and the initializer doesn't survive deserialization, so a missing list is still `null`.
  - **`withListElements()`** on the parser, with XML element names or, under `deserialize()`, Apex field names: `line-item` or `line_item`, matching case, at any depth. Use it for `getResponseBodyMap()` and for Lists inside List elements.
  Typed `deserialize()` creates a new instance of the type every time, which runs its no-argument constructor, field initializers and getters; keep those free of queries and DML. If that fails, for example without a no-argument constructor, with a getter that throws on an empty instance, or with `@JsonAccess(serializable='never')`, only `withListElements()` applies.
- Child elements win over attributes of the same name, and namespace prefixes are dropped. `xsi:` attributes such as `xsi:nil` and `xsi:type` don't become keys, so an `xsi:nil` element becomes null.
- `true` and `false` become Booleans, and blank text becomes null. Numbers and ISO dates convert from text into `Integer`, `Decimal` and `Date` fields.
- Text next to attributes or child elements goes under the key `text`.
- `deserialize()` turns keys into valid Apex names: `_Value` becomes `Value`, and `unit-price` becomes `unit_price`.
- Apex classes for `deserialize()` can't have `Object` or `List<Object>` fields, because `JSON.deserialize` rejects them. Type the parts you need and leave the rest out.
- `withResponseParser()` takes any `CalloutResponseParser`, the abstract class `CalloutJsonParser` and `CalloutXmlParser` extend. Extend it yourself for another format, or extend `CalloutJsonParser` for JSON that needs custom handling.
- For API-specific conventions, extend `CalloutXmlParser` and override `protected toValue(String name, String text)` to convert the text of named elements or attributes (for example, `Y`/`N` indicator fields into Booleans) or `protected toKey(String name)` to rename keys, which `deserialize()` then turns into Apex names. Call `super` for everything else, and pass the subclass to `withResponseParser()`.

---

## Step 2: Write the CalloutBuilder chain

### Basic structure

```Java (Apex)
CalloutBuilder cb = new CalloutBuilder('callout:MyNamedCredential')
    .withEndpoint('/v1/resource')
    .withMethod('POST')
    .withBody(requestPayload)
    .withSuccessType(ReturnType.class)
    .withErrorType(MyErrorResponse.class)
    .withMockIfTest(new MyMock());

ReturnType result = (ReturnType)cb.getTypedResponseBody();

```

### Named credential vs base URL

Pass either a named credential alias (`'callout:MyNC'`) or a full base URL (`'https://api.example.com'`). Named credentials are always preferred in production — they keep auth out of Apex.

### Endpoint and path parameters

`withEndpoint` stores exactly one leading slash, whatever the base URL ends with, so `withEndpoint('path')` and `withEndpoint('/path')` are equivalent; write the leading slash. It throws on `#`, and on `\` or a `.` / `..` segment in the path.

Never concatenate values into the endpoint — they are sent unencoded. Use a `{name}` placeholder and `withPathParameter`; the value is passed raw and encoded as one path segment:

```Java (Apex)
new CalloutBuilder('callout:MyNC')
    .withEndpoint('/customers/{customerId}/orders/{orderId}')
    .withPathParameter('customerId', customerId)
    .withPathParameter('orderId', orderId)    // withPathParameters(Map) for many
    .getResponseBodyMap();
```

Every placeholder needs a parameter and every parameter a placeholder; a mismatch, or a blank, `.` or `..` value, throws `CalloutBuilder.CalloutBuilderException` before the callout. A placeholder also works in the endpoint's own query string (`'/search?q={term}'`), which is the only encoded URL query for a non-GET request without a body.

### Body serialization

`withBody(Object)` serializes the object to JSON via `JSON.serialize` and, when no Content-Type is set, sends `Content-Type: application/json`. To omit null fields, chain `.withSuppressApexObjectNulls(true)`. A `String` body is serialized too, unless a non-JSON Content-Type is set: then it is sent as-is, so XML, CSV or form-encoded strings need `withHeader('Content-Type', ...)`. A `Dom.Document` or `CalloutXmlSerializable` body is sent as XML, with `Content-Type: application/xml` unless one is set. Use `withBlobBody(Blob)` for binary bodies; it sends `Content-Type: application/octet-stream` unless one is set. For file uploads expecting multipart/form-data, use `withFile()`.

With `withHeader('Content-Type', 'application/x-www-form-urlencoded')`, a Map or object body is sent as form fields instead of JSON: a nested field as `a[b]` and a List item as `a[0]`. Keys and values are URL-encoded, so don't encode them yourself. A null field or List item is left out; send `''` for an empty value. Field order isn't kept: when the API needs it, send flat fields with `withQueryParameter()` on a POST without a body, or a String body. Apex can't name a field after a reserved word such as `currency`, so put such a key in a Map. A body other than a Map, an object or a String throws `CalloutBuilderException`.

For an XML request, prefer `CalloutXmlBuilder` to string concatenation. A class implementing `CalloutXmlSerializable` builds and names its own element, and goes to `withBody()` as it is. `CalloutXmlBuilder` implements it too:

```Java (Apex)
public class OrderLine implements CalloutXmlSerializable {
    public String sku;
    public Integer quantity;

    public CalloutXmlBuilder toXmlBuilder() {
        return new CalloutXmlBuilder('line')
            .withAttribute('sku', this.sku)
            .addValue('quantity', this.quantity);
    }
}

public class NewOrder implements CalloutXmlSerializable {
    public String note;
    public Address shipTo;
    public Address billTo;
    public List<OrderLine> lines = new List<OrderLine>();

    public CalloutXmlBuilder toXmlBuilder() {
        return new CalloutXmlBuilder('order')
            .withAttribute('xmlns:acme', 'urn:acme')
            .addOptionalValue('acme:note', this.note)
            .addChild('shipTo', this.shipTo)
            .addChild('billTo', this.billTo)
            .addChildren(this.lines);
    }
}

new CalloutBuilder('callout:OrdersApi').withMethod('POST').withBody(newOrder).getXmlResponseBody();
```

- Elements keep the order they are added in, so an element can repeat with another between. `JSON.serialize` does not keep field order, so don't derive XML from it.
- Names are written as given: a prefix or an `xmlns` declaration goes in the name, and nothing validates them.
- Values and attributes take a String, a number or a Boolean. Format dates before adding them: the format belongs to the API.
- A null value gives an empty element or attribute. `addOptionalValue()` and `withOptionalAttribute()` skip a blank value, `addOptionalChild()` skips null content, and `addChildren()` skips a null list.
- `addChild(content)` and `addChildren()` keep the name the content gives itself, and `addChild(content)` throws on null content. `addChild(name, content)` replaces that name, for one class under several names, and gives an empty element for null content.
- Content is read when the XML is written, so one object reused for several children sends its last values in all of them. Create one object per child.
- Content that contains itself throws `CalloutBuilder.CalloutBuilderException` when the XML is written. Pass the object and not `object.toXmlBuilder()`: a builder made early hides the loop, which then ends in a stack limit error that can't be caught.
- Only `addChild(name)` returns the child, to add to it now or later; every other method returns the same builder.
- There is no XML declaration unless it is asked for: `.withBody(newOrder.toXmlBuilder().withXmlDeclaration())`.

### Query parameters

```Java (Apex)
// GET: params appended to URL as ?key=value
new CalloutBuilder('callout:MyNC')
    .withEndpoint('/search')
    .withQueryParameter('q', 'apex')
    .withQueryParameters(new Map<String, String>{ 'page' => '1' })
    .getResponseBodyMap();

// POST without withBody(): query params are the form-encoded body.
// POST + withBody(): query params go to the URL.
```

### Timeouts 
- `.withTimeout(milliseconds)` — default is 10 s; max is 120 000 ms.

### Client certificate
- `.withClientCertificate(certificateName)` — for an API that requires a client certificate (mutual TLS); pass the certificate's Unique Name. Don't build a raw `HttpRequest` for it.
- The certificate must exist in the org, even when `withMockIfTest()` answers the callout; otherwise it throws `CalloutException`. A null name sends no certificate, so read the name from configuration that is empty in test and scratch orgs.

### Compression
- `.withCompression(true)` — sends the body gzip-compressed whether or not the API accepts it; enable it only when the API documents gzip request bodies. Off by default.

### Debug Mode
- `.withDebugMode(true)` — logs full request/response to the debug log (skips binary content types). Safe to include during development; remove or control by custom metadata in production. False by default.

---

## Step 3: Error handling

CalloutBuilder throws `CalloutBuilder.CalloutBuilderException` on any HTTP status >= 400. Use `withErrorType()` to deserialize the error body so you can surface a structured message alongside the exception.

### Define an error DTO that implements CalloutErrorResponse

```Java (Apex)
// 1. Define an error DTO that implements CalloutErrorResponse
public class MyErrorResponse implements CalloutErrorResponse {
    public String error;
    public String description;

    public String getErrorMessage() {
        return String.isNotBlank(description) ? description : error;
    }
}

```

### Use error DTO in CalloutBuilder

```Java (Apex)

// 2. Wire it in and catch
CalloutBuilder builder = new CalloutBuilder('callout:MyNC')
    .withEndpoint('/resource')
    .withSuccessType(MyResponse.class)
    .withErrorType(MyErrorResponse.class)
    .withMockIfTest(new MyMock());
    MyResponse result = (MyResponse) builder.getTypedResponseBody();
```
### You can catch the exception and access the deserialized error object:

```Java (Apex)

try {
    MyResponse result = (MyResponse) builder.getTypedResponseBody();
} catch (CalloutBuilder.CalloutBuilderException e) {
    MyErrorResponse err = (MyErrorResponse) builder.getError();
    // e.code and e.status hold the HTTP status code and status text
}
```

`getError()` is only populated after an exception is thrown. The `getErrorMessage()` return value is included in the exception message automatically — implement it to surface the API's human-readable error.

The exception also carries `code` (HTTP status code) and `status` (HTTP status text); both are null when the exception is thrown before a callout is made, e.g. a builder configuration error.

`System.CalloutException` (read timeout, missing Remote Site Setting or Named Credential, uncommitted DML) skips both `catch (CalloutBuilder.CalloutBuilderException)` and the retrier.

Use `.withBypassResponseValidation(true)` only when you genuinely need to inspect error responses programmatically without an exception. This is rare — the `withErrorType` + `getError()` covers most cases.

---

## Step 4: Retry logic

Implement `CalloutRetrier` when an external API needs retry logic.

```Java (Apex)
private class TokenRefreshRetrier implements CalloutRetrier {
    public Boolean shouldRetry(HttpResponse response) {
        if (response.getStatusCode() == 401) {
            MyAuthService.refreshToken(); // you may do something here before retrying, e.g. refresh an auth token
            return true;
        }
        return false;
    }
}

new CalloutBuilder('callout:MyNC')
    .withEndpoint('/data')
    .withRetrier(new TokenRefreshRetrier())
    .withMaxRetries(2)   // total attempts = 1 original + 2 retries = 3
    .withSuccessType(MyResponse.class)
    .getTypedResponseBody();
```

`withMaxRetries(N)` sets N as the maximum number of additional attempts after the first. If `shouldRetry` returns `false`, retrying stops immediately regardless of remaining count.

---

## Step 5: Guardrails

Implement `CalloutGuardrail` for a policy check before sending — blocked endpoints, required header, kill switch. Throwing `CalloutGuardrailException` blocks; returning allows.

```Java (Apex)
public with sharing class InternalEndpointGuardrail implements CalloutGuardrail {
    public void enforce(CalloutBuilder builder) {
        if (builder.getEndpoint()?.startsWith('/internal') == true) {
            throw new CalloutGuardrailException('Internal endpoints are not callable from this context.');
        }
    }
}

new CalloutBuilder('callout:MyNC')
    .withEndpoint('/v1/resource')
    .withGuardrail(new InternalEndpointGuardrail())              // withGuardrails(List) for many
    .withSuccessType(MyResponse.class)
    .getTypedResponseBody();
```

- Both `with` methods append; the chain runs in attachment order and stops at the first throw. Chain position is irrelevant — guardrails run at execution time.
- One run per execution, inside every response variant, before the request is built and before retries. A guardrail reads builder state — `getNcOrBaseUrl()`, `getEndpoint()`, `getMethod()`, `getHeaders()`, `getQueryParameters()`, `getPathParameters()`, `constructFullEndpoint()` — never the `HttpRequest` or the body. `getEndpoint()` is the resolved endpoint, placeholders filled; the three map accessors return copies, `getPathParameters()` with raw values.
- A guardrail must not execute the builder it receives; doing so throws `CalloutBuilder.CalloutBuilderException`. Its own callout needs a separate `CalloutBuilder`.
- Blocking applies in tests too, before mocks are set — the mock is never reached.
- A block inside `CalloutBuilderQueueable` fails the job and strands the builders queued behind it. Filter blocked builders out while assembling the `CalloutCollection` when partial progress matters.

`CalloutGuardrailException` extends `Exception`, not `CalloutBuilder.CalloutBuilderException` — catch it separately:

```Java (Apex)
try {
    MyResponse result = (MyResponse) builder.getTypedResponseBody();
} catch (CalloutGuardrailException e) {
    // blocked before sending — no HTTP context, builder.getError() is null
} catch (CalloutBuilder.CalloutBuilderException e) {
    // sent and rejected, or a configuration error
}
```

Use a guardrail for a pass/fail check. Subclass instead when behavior wraps the callout — logging, rewriting the request, timing. `CalloutBuilder` is `virtual` with `withEndpoint`, `withMethod`, `withBody`, `withBlobBody`, and `getHttpResponse` overridable; every response variant funnels through `getHttpResponse()`. Under `getResponseBodyMap()`, `getTypedResponseBody()` and `getXmlResponseBody()` it returns the response unsanitized, so an override must not cache or log its return value as sanitized.

---

## Step 6: Response sanitizers

Guardrails police the request; `CalloutResponseSanitizer` polices the response. Extend it to strip content the caller must not receive — restricted search hits, PII. Override a `sanitize()` overload per form handled: `sanitize(HttpResponse)` for `getHttpResponse()` / `getResponseBodyAsBlob()`, `sanitize(Map<String, Object>)` for `getResponseBodyMap()`, `sanitize(Object, System.Type)` for `getTypedResponseBody()`, `sanitize(Dom.Document)` for `getXmlResponseBody()`. Mutate the argument in place, or throw `CalloutResponseSanitizerException` to block the response.

```Java (Apex)
public with sharing class RestrictedFolderSanitizer extends CalloutResponseSanitizer {
    public override void sanitize(Map<String, Object> body) {
        body.put('results', this.withoutRestrictedFolders((List<Object>) body.get('results')));
    }
}

new CalloutBuilder('callout:MyNC')
    .withEndpoint('/v1/search')
    .withResponseSanitizer(new RestrictedFolderSanitizer())   // withResponseSanitizers(List) for many
    .getResponseBodyMap();
```

- Both `with` methods append. The chain runs once per execution, after validation, in attachment order, and stops at the first throw. Every sanitizer works on the instance the caller receives; the map, typed and `Dom.Document` overloads get it already parsed, so never re-parse.
- To reuse a set of sanitizers, bundle them: `.withResponseSanitizer(new CalloutResponseSanitizerChain().add(new A()).add(new B()))`.
- `CalloutRetrier.shouldRetry()`, the `>= 400` error path, and `withDebugMode(true)` see the **raw** response. Sanitizing is not log redaction.
- Error responses are never sanitized, because validation throws first. Under `withBypassResponseValidation(true)` nothing throws, so non-2xx responses reach the chain too — only `sanitize(HttpResponse)` sees `getStatusCode()` to branch on.
- Fail closed: an overload not overridden blocks the response; inside an override, throw rather than return quietly on a body you cannot handle.
- A typed sanitizer casts `body` to the success type it was written for, checking `successType` first when it serves several.
- Binary responses need `setBodyAsBlob()` in `sanitize(HttpResponse)`.
- A sanitizer must not execute the builder it is sanitizing; doing so throws `CalloutBuilder.CalloutBuilderException` before the second request is sent. Its own callout needs a separate `CalloutBuilder`.
- `CalloutCollection.postProcess()` receives the sanitized response. Queued builders run `getHttpResponse()`, so only `sanitize(HttpResponse)` applies there. A throw inside `CalloutBuilderQueueable` fails the job and strands the builders queued behind it.
- `CalloutResponseSanitizerException` extends `Exception` — catch it beside `CalloutGuardrailException`, not under `CalloutBuilder.CalloutBuilderException`.

---

## Step 7: Test mocks

It's recommended to include `.withMockIfTest(new MyMock())`. This method is a no-op outside of test context. Omitting it means tests will fail with "Callout not allowed" errors unless mocks are set elsewhere. This apporch helps reducing test code clutter when the same mock applies across many tests. If the codebase has the `ViciousMockBase` class, you can also use derived classes here. They record the requests they answer: assert on `getLastRequest()` or `getRequests()` rather than hand-writing a capture mock.

### Inline mock

```Java (Apex)
// Production code
new CalloutBuilder('callout:MyNC')
    .withEndpoint('/orders')
    .withSuccessType(OrderResponse.class)
    .withMockIfTest(new OrderMock())
    .getTypedResponseBody();

// Mock class (private inner class or standalone)
private class OrderMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"id":"ORD-001","status":"created"}');
        return res;
    }
}
```

### Override mock in tests

Use `BUILDER_TO_MOCK_OVERRIDE` when you need a specific endpoint/method combination to behave differently in a test — for example, to simulate a 500 error while other callouts succeed:

```Java (Apex)
@IsTest
static void testPaymentError() {
    CalloutBuilder keyBuilder = new CalloutBuilder('callout:PaymentsNC')
        .withEndpoint('/charge')
        .withMethod('POST');
    CalloutBuilder.BUILDER_TO_MOCK_OVERRIDE.put(keyBuilder, new ChargeErrorMock());

    Test.startTest();
        MyService.chargeCustomer(100); // uses same endpoint/method — picks up ChargeErrorMock
    Test.stopTest();
}
```

The override matches by resolved full URL + HTTP method: a key built with `withEndpoint('/charge/ch_1')` matches `withEndpoint('/charge/{id}').withPathParameter('id', 'ch_1')`.

The override is installed with `Test.setMock()`, so it replaces the test's mock and stays installed after its callout; Apex can't restore the earlier mock. A later callout without its own `withMockIfTest()` or override is answered by the override, so give every callout in such a test a mock or an override.

---

## Step 8: File uploads (multipart/form-data)

Use `CalloutHexFormBuilder` for multipart/form-data uploads. Files should not exceed ~5 MB: the whole form must fit the callout request size limit (10 MB in synchronous Apex since Winter '27, 6 MB in orgs on older limits) — warn users about this.

```Java (Apex)
CalloutHexFormBuilder form = CalloutHexFormBuilder.build()
    .writeParameter('purpose', 'assistants')           // plain text field
    .writeJsonParameter('metadata', '{"tag":"doc"}')   // JSON field
    .writeFile('report.pdf', fileBlob);                // file (Blob or base64 String)

HttpResponse response = new CalloutBuilder('callout:StorageNC')
    .withEndpoint('/files')
    .withMethod('POST')
    .withFile(form)   // sets Content-Type and blob body automatically
    .withMockIfTest(new UploadMock())
    .getHttpResponse();
```

`writeFile(fileName, content)` resolves MIME type from the file extension via `MimeType`. The file form field key defaults to `'file'`; use the three-argument overload `writeFile(key, fileName, content)` to customize it.

**Do not** also call `withBody()` or `withHeader('Content-Type', ...)` when using `withFile()` — `withFile` handles both internally.

---

## Step 9: Async callouts (from triggers)

Apex forbids synchronous callouts from triggers. Use `CalloutBuilderQueueable`.

```Java (Apex)
// Simple case: pass a list directly
CalloutBuilderQueueable.enqueue(new CalloutCollection(new List<CalloutBuilder>{
    builder1, builder2
}));
```

Extend `CalloutCollection` when you need lifecycle hooks — preparation before the first callout or processing after each response:

```Java (Apex)
public class OrderSyncCollection extends CalloutCollection {
    private List<Order__c> orders;

    public OrderSyncCollection(List<Order__c> orders) {
        super(buildCallouts(orders));
        this.orders = orders;
    }

    public override void prepare() {
        // Runs once before any callout — use for token refresh, setup work
    }

    protected override void postProcess(HttpResponse response) {
        // Runs after each individual callout response
        // Update records, log results, handle errors per-record
    }

    private static List<CalloutBuilder> buildCallouts(List<Order__c> orders) {
        List<CalloutBuilder> builders = new List<CalloutBuilder>();
        for (Order__c o : orders) {
            builders.add(
                new CalloutBuilder('callout:OrdersNC')
                    .withEndpoint('/orders/{id}')
                    .withPathParameter('id', o.ExternalId__c)
                    .withMethod('PATCH')
                    .withBody(new OrderPayload(o))
                    .withMockIfTest(new OrderSyncMock())
            );
        }
        return builders;
    }
}

// In trigger handler:
CalloutBuilderQueueable.enqueue(new OrderSyncCollection(trigger.new));
```

`CalloutBuilderQueueable` automatically re-enqueues itself if it approaches the 2-minute CPU limit or the 100-callout per-transaction limit, so large collections process safely across multiple queueable jobs.

---

## Response DTO Considerations

When generating response types:
- Define DTOs as inner classes of a dedicated container (e.g., `OrderResponse` holding `OrderResponse.Data`, `OrderResponse.Error`)
- Inner classes can't contain other inner classes.
- Match JSON field names exactly — Apex JSON deserialization is case-sensitive. If name is a reserved word, suggest using a Map<String, Object> instead of a DTO.
- Apex does not support generics.
- Error DTOs must implement `CalloutErrorResponse`; `getErrorMessage()` must return a non-blank string — returning null causes the raw body to be used as the exception message.

---

## URL Behavior

- `withEndpoint()` stores exactly one leading `/` unless the endpoint is blank or starts with `?`, and the base URL's trailing `/` is not doubled: `callout:MyNC` + `items` → `callout:MyNC/items`.

- `withEndpoint()` throws on `#` anywhere, and on `\` or a `.` / `..` segment (also as `%2e`) in the path.

- For `GET` requests, query parameters _(UTF-8 encoded)_ are appended to the URL: `https://example.com/test?param1=value1&param2=value2&param3=value3`

- For other HTTP methods (e.g., `POST`), parameters are the body when no body is set, and the URL remains: `https://example.com/test`. With a body, they go to the URL as for `GET`.

- An endpoint that already carries a query string is extended with `&`, not a second `?`: `withEndpoint('/test?a=1')` + `withQueryParameter('b', '2')` → `https://example.com/test?a=1&b=2`

- A `null` value is left out, so a parameter that may be null, such as a page cursor, needs no guard.

---

## Common mistakes to catch and fix

- `getTypedResponseBody()` without `.withSuccessType()` set — throws immediately
- Passing a class that does not implement `CalloutErrorResponse` to `.withErrorType()` — throws at configuration time, not at callout time
- Using `withQueryParameters` on a POST that also has `.withBody()` — body wins
- Concatenating values into `withEndpoint()` (`'/orders/' + id`) — sent unencoded, so `/`, `?` or `&` in a value changes the request and `#`, `\` or `..` makes `withEndpoint()` throw; use `'/orders/{id}'` with `withPathParameter('id', id)`
- Encoding a path parameter value before passing it — it is encoded again (`%2F` becomes `%252F`)
- Concatenating a nested form body (`'items[0][sku]=' + sku`) — values go out unencoded; pass a Map to `withBody()` with the `application/x-www-form-urlencoded` Content-Type
- Omitting `.withMockIfTest()` — tests fail with "Callout not allowed"
- A guardrail executing the builder it was handed, or expecting the `HttpRequest` or body — only builder state is readable
- Catching only `CalloutBuilder.CalloutBuilderException` around a guarded callout — `CalloutGuardrailException` escapes it
