@isTest
private with sharing class ViciousMockery_Test {
        
    @IsTest
    static void testRespondKnownCode() {
        Integer statusCode = 429;
        String expectedBody = 'I understand that if any more words come pouring out your mouth, I`m gonna have to eat every chicken in this room. [The Hound, GoT]';

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
        String fallbackBody = 'I find your lack of faith disturbing [Vader, SW]';

        ViciousMockery.cast(statusCode);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://mock.vicious.com');
        req.setMethod('GET');

        HttpResponse res = new Http().send(req);

        Assert.areEqual(fallbackBody, res.getBody(), 'Unexpected body');
    }

    @IsTest
    static void testDefaultCodeIfNullPassed() {
        ViciousMockery vm = new ViciousMockery(null);
        HttpResponse res = vm.respond(new HttpRequest());
        Assert.areEqual(200, res.getStatusCode(), 'Unexpected code');
    }
}