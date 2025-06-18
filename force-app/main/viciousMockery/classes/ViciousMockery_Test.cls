@isTest
private with sharing class ViciousMockery_Test {
        
    @IsTest
    static void testRespondKnownCode() {
        Integer statusCode = 429;
        String expectedBody = ViciousMockery.CODE_TO_BODY.get(statusCode);

        ViciousMockery.cast(statusCode);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://mock.vicious.com');
        req.setMethod('GET');

        HttpResponse res = new Http().send(req);

        Assert.areEqual(statusCode, res.getStatusCode(), 'Expected status code to match mock');
        Assert.areEqual(expectedBody, res.getBody(), 'Expected body to match mapped quote');
    }

    @IsTest
    static void testRespondUnknownCode() {
        Integer statusCode = 999;

        ViciousMockery.cast(statusCode);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://mock.vicious.com');
        req.setMethod('GET');

        HttpResponse res = new Http().send(req);

        Assert.areEqual(ViciousMockery.FALLBACK_BODY, res.getBody(), 'Unexpected body');
    }

    @IsTest
    static void testDefaultCodeIfNullPassed() {
        ViciousMockery vm = new ViciousMockery(null);
        HttpResponse res = vm.respond(new HttpRequest());
        Assert.areEqual(200, res.getStatusCode(), 'Unexpected code');
    }
}