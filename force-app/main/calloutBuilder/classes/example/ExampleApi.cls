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
            .withRetrier(new ExampleRetrier())
            .withMaxRetries(2)
            .withMockIfTest(new DialogTokenMock());

        ExampleResponse.DialogToken tokenResponse = (ExampleResponse.DialogToken)cb.getTypedResponseBody();

        return tokenResponse.data.dialog_token;
    }

    public static void asyncExample() {
        CalloutBuilder cb = new CalloutBuilder(NC).withMockIfTest(new DialogTokenMock());

        // list constructor example
        CalloutCollection callouts = new CalloutCollection(new List<CalloutBuilder> { cb });
        CalloutBuilderQueueable.enqueue(callouts);

        // empty constructor example
        CalloutCollection nextCallouts = new CalloutCollection();
        nextCallouts.add(cb);
        CalloutBuilderQueueable.enqueue(nextCallouts);
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

    private with sharing class ExampleRetrier implements CalloutRetrier {
        public Boolean shouldRetry(HttpResponse response) {
            if (response.getStatusCode() >= 400) {
                return false;
            }

            if (response.getBody()?.containsAny('unauthenticated')) {
                ConnectApiAdapter.refreshToken(
                    'externalCredential', 
                    'principalName',
                    ConnectApi.CredentialPrincipalType.PERUSERPRINCIPAL,
                    ConnectApi.CredentialAuthenticationProtocol.OAUTH
                );

                return true;
            }

            return false;
        }
    }

}