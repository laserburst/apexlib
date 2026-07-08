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
  "withFile", or any question about how to call an external service from Apex.
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
| Downloading binary content | `getResponseBodyAsBlob()` |
| Callout from a trigger or batch context | `CalloutBuilderQueueable` |

Prefer `getTypedResponseBody()` when the API contract is known — it gives compile-time safety and clean downstream code. `getResponseBodyMap()` loses type safety; only recommend it when the response shape genuinely cannot be modeled.

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

### Endpoint slash handling

`withEndpoint` strips one leading slash when the base URL already ends with a slash. Be explicit: use `'callout:MyNC'` (no trailing slash) with `withEndpoint('/path')` (leading slash).

### Body serialization

`withBody(Object)` serializes the object to JSON via `JSON.serialize`. To omit null fields, chain `.withSuppressApexObjectNulls(true)`. Pass a raw `String` to `withBody` only when you have already serialized the payload or it is not JSON (e.g., XML). Use `withBlobBody(Blob)` for binary bodies. For file uploads expecting multipart/form-data, use `withFile()`.

### Query parameters

```Java (Apex)
// GET: params appended to URL as ?key=value
new CalloutBuilder('callout:MyNC')
    .withEndpoint('/search')
    .withQueryParameter('q', 'apex')
    .withQueryParameters(new Map<String, String>{ 'page' => '1' })
    .getResponseBodyMap();

// POST + withBody() + withQueryParameters(): body wins, query params are silently
// dropped from the body. They still appear in the URL only for GET requests.
```

### Timeouts 
- `.withTimeout(milliseconds)` — default is 10 s; max is 120 000 ms.

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

## Step 5: Test mocks

It's recommended to include `.withMockIfTest(new MyMock())`. This method is a no-op outside of test context. Omitting it means tests will fail with "Callout not allowed" errors unless mocks are set elsewhere. This apporch helps reducing test code clutter when the same mock applies across many tests. If the codebase has the `ViciousMockBase` class, you can also use derived classes here.

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

The override matches by full URL + HTTP method. Builders targeting other endpoints are unaffected.

---

## Step 6: File uploads (multipart/form-data)

Use `CalloutHexFormBuilder` for multipart/form-data uploads. The Apex heap limit means files should not exceed ~2 MB in synchronous contexts — warn users about this.

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

## Step 7: Async callouts (from triggers)

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
                    .withEndpoint('/orders/' + o.ExternalId__c)
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

- For `GET` requests, query parameters _(UTF-8 encoded)_ are appended to the URL: `https://example.com/test?param1=value1&param2=value2&param3=value3`

- For other HTTP methods (e.g., `POST`), parameters are included in the body instead, and the URL remains: `https://example.com/test`

---

## Common mistakes to catch and fix

- `getTypedResponseBody()` without `.withSuccessType()` set — throws immediately
- Passing a class that does not implement `CalloutErrorResponse` to `.withErrorType()` — throws at configuration time, not at callout time
- Using `withQueryParameters` on a POST that also has `.withBody()` — body wins
- Omitting `.withMockIfTest()` — tests fail with "Callout not allowed"
