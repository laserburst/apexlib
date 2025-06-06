@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.ApexDoc')
@isTest
private with sharing class ExampleApi_Test {
    @IsTest
    static void testCreateDialogToken() {
        Test.startTest();
            String token = ExampleApi.createDialogToken(123456);
        Test.stopTest();
        
        Assert.areEqual('mocked_token', token, 'The dialog token should match the mocked value');
    }

    @isTest
    static void testAsyncExample() {
        Test.startTest();
            ExampleApi.asyncExample();
        Test.stopTest();
        // nothing to assert
    }

}