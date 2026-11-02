@isTest
private with sharing class ViciousMockBase_Test {

    private class JsonBodyMock extends ViciousMockBase {
        { 
            stringBody = '{"ok":true}'; 
        }
    }

    private class BlobBodyMock extends ViciousMockBase {
        {
            headers.put('Content-Type', 'application/octet-stream');
            blobBody = Blob.valueOf('binary content');
        }
    }

    private class RetryAfterNotFound extends ViciousMockBase {
        protected override HttpResponse buildResponse(HttpRequest req) {
            HttpResponse res = super.buildResponse(req);
            if (this.getRequests().size() == 1) {
                res.setStatusCode(404);
            }
            return res;
        }
    }

    @IsTest
    static void testgetBodyDefault() {
        Assert.areEqual('', new ViciousMockBase().getBodyString(), 'Expected empty string when no jsonResponse set');
    }

    @IsTest
    static void testgetBodyWithJson() {
        Assert.areEqual('{"ok":true}', new JsonBodyMock().getBodyString(), 'Expected jsonResponse returned');
    }

    @IsTest
    static void testRespondWithBlobResponse() {
        Blob expected = Blob.valueOf('binary content');
        Test.setMock(HttpCalloutMock.class, new BlobBodyMock());

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://mock.vicious.com');
        req.setMethod('GET');

        HttpResponse res = new Http().send(req);
        Assert.areEqual(expected, res.getBodyAsBlob(), 'Expected blob body in response');
    }

    @IsTest
    static void testRecordsRequestsInCallOrder() {
        ViciousMockBase mock = new ViciousMockBase();
        Assert.isTrue(mock.getRequests().isEmpty(), 'A fresh mock should have no requests');
        Assert.isNull(mock.getLastRequest(), 'A fresh mock should have no last request');

        Test.setMock(HttpCalloutMock.class, mock);
        send('https://mock.vicious.com/first');
        send('https://mock.vicious.com/second');

        List<HttpRequest> requests = mock.getRequests();
        Assert.areEqual(2, requests.size(), 'Every answered request should be recorded');
        Assert.areEqual('https://mock.vicious.com/first', requests[0].getEndpoint(), 'Wrong first request');
        Assert.areEqual('https://mock.vicious.com/second', mock.getLastRequest().getEndpoint(), 'Wrong last request');

        requests.clear();
        Assert.areEqual(2, mock.getRequests().size(), 'getRequests should return a copy');
    }

    @IsTest
    static void testBuildResponseOverrideAnswersByCallNumber() {
        Test.setMock(HttpCalloutMock.class, new RetryAfterNotFound());

        Assert.areEqual(404, send('https://mock.vicious.com').getStatusCode(), 'The first call should get 404');
        Assert.areEqual(200, send('https://mock.vicious.com').getStatusCode(), 'The second call should get 200');
    }

    private static HttpResponse send(String endpoint) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        return new Http().send(req);
    }
}