@IsTest
private class CalloutResponseParser_Test {
    @IsTest
    static void testForContentTypeSelectsParser() {
        Assert.isInstanceOfType(
            CalloutResponseParser.forContentType('application/soap+xml; charset=utf-8'),
            CalloutXmlParser.class,
            'A +xml media type should select the XML parser'
        );
        Assert.isInstanceOfType(
            CalloutResponseParser.forResponse(new HttpResponse()),
            CalloutJsonParser.class,
            'A response without a Content-Type should select the JSON parser'
        );
    }
}