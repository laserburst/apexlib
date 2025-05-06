# CalloutBuilder

## Purpose

Establishing unified callout approach with basic response handling backed in.

## Structure

1. [CalloutBuilder](force-app/main/calloutBuilder/CalloutBuilder.cls) - main class.
2. [CalloutErrorResponse](force-app/main/calloutBuilder/CalloutErrorResponse.cls) - interface used in CalloutBuilder to enable it extract error message from any error object.

## Example

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
    .build();

ExampleResponse.DialogToken tokenResponse = (ExampleResponse.DialogToken)cb.getTypedResponseBody();
```

[Full Example](force-app/main/calloutBuilder/ExampleApi.cls)

