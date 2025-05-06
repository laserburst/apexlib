/**
 * @description It illustrates callouts with CalloutBuilder.
 * @team Laserburst 
 */
public with sharing class ExampleApi {
    private static final String NC = 'callout:Example';

    public static String createDialogToken(Integer customerId) {
        CalloutBuilder cb = new CalloutBuilder(NC)
            .withEndpoint('work/api/v2/customers/' + customerId + '/dialog-tokens')
            .withMethod('POST')
            .withHeader('key', 'value')
            .withHeaders(new Map<String, String>{ 'key_2' => 'value_2' })
            .withTimeout(30000)
            .withSuccessType(ExampleResponse.DialogToken.class)
            .withErrorType(ExampleResponse.Error.class)
            .withMockIfTest(new DialogTokenMock())
            .build();

        ExampleResponse.DialogToken tokenResponse = (ExampleResponse.DialogToken)cb.getTypedResponseBody();

        return tokenResponse.data.dialog_token;
    }

    private class DialogTokenMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"data": {"dialog_token": "mocked_token"}}');
            return res;
        }
    }
}