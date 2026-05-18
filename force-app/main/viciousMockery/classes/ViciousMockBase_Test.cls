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
}