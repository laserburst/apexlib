# CalloutBuilder

## Purpose

Establishing unified callout approach with basic response handling backed in.

## Structure

1. [CalloutBuilder](CalloutBuilder.cls) - main class.
2. [CalloutErrorResponse](CalloutErrorResponse.cls) - interface enabling CalloutBuilder to extract error message from any error object.
3. [CalloutRetrier](CalloutRetrier.cls) - interface enabling CalloutBuilder to retry a callout and to change something before the new attempt.
4. [CalloutBuilderQueueable](CalloutBuilderQueueable.cls) - virtual class to run one or many callouts asynchronously, for example, from a trigger.
5. [CalloutCollection](CalloutCollection.cls) - virtual class which is bundling many CalloutBuilder instances, callout preparation and post processing for [CalloutBuilderQueueable](CalloutCollection.cls).
6. [Bonus: ConnectApiAdapter](ConnectApiAdapter.cls) - class with a subset of prepared, the most frequently used methods from the ConnectApi namespace.

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
    .withMaxRetries(2);

ExampleResponse.DialogToken tokenResponse = (ExampleResponse.DialogToken)cb.getTypedResponseBody();
```

[Full Example](ExampleApi.cls)

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

#### URL Behavior

- For `GET` requests, query parameters _(UTF-8 encoded)_ are appended to the URL: `https://example.com/test?param1=value1&param2=value2&param3=value3`

- For other HTTP methods (e.g., `POST`), parameters are included in the body instead, and the URL remains: `https://example.com/test`

#### Request Body Note 

If you set a body using `.withBody()`, it _will not be overwritten_ by query parameters.
