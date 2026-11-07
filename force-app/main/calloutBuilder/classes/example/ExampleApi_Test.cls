@IsTest
private with sharing class ExampleApi_Test {
    @IsTest
    static void testCreateDialogToken() {
        Test.startTest();
            String token = ExampleApi.createDialogToken(123456);
        Test.stopTest();
        
        Assert.areEqual('mocked_token', token, 'The dialog token should match the mocked value');
    }

    @IsTest
    static void testAsyncExample() {
        Exception error;
        try {
            Test.startTest();
                ExampleApi.asyncExample();
            Test.stopTest();
        } catch (Exception e) {
            error = e;
        }

        Assert.isNull(error, 'Should not throw');
    }

}