@IsTest
private class ncMcp_CalloutResponse_Test {
    @IsTest
    static void testHeaders() {
        HttpResponse response = new HttpResponse();
        response.setHeader('content-type', 'application/json');
        response.setHeader('x-internal-id', '42');
        response.setHeader('X-Internal-Id', ''); // a sanitizer that blanks under another case than the server sent

        Test.startTest();
        String headers = ncMcp_CalloutResponse.forResponse(response).headers;
        Test.stopTest();

        Assert.areEqual(
            new Map<String, Object>{ 'content-type' => 'application/json', 'x-internal-id' => '' },
            JSON.deserializeUntyped(headers),
            'Header names should be lower case, and a header blanked under any case should be blank'
        );
    }
}