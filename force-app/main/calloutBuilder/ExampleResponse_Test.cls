@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.ApexDoc')
@isTest
private with sharing class ExampleResponse_Test {
    @IsTest
    static void testErrorWithNullError() {
        ExampleResponse.Error err = new ExampleResponse.Error();

        Test.startTest();
            String actual = err.getErrorMessage();
        Test.stopTest();

        Assert.areEqual('Example response error is null', actual, 'Unexpected error message');
    }

    @IsTest
    static void testErrorWithNoMessages() {
        ExampleResponse.ErrorDetail detail = new ExampleResponse.ErrorDetail();
        detail.code_message = 'Something went wrong';
        detail.messages = new List<ExampleResponse.MessageDetail>();
        
        ExampleResponse.Error err = new ExampleResponse.Error();
        err.error = detail;

        Test.startTest();
            String actual = err.getErrorMessage();
        Test.stopTest();
        
        Assert.areEqual('Something went wrong with no detail', actual, 'Unexpected error message');
    }

    @IsTest
    static void testErrorWithNullMessageList() {
        ExampleResponse.ErrorDetail detail = new ExampleResponse.ErrorDetail();
        detail.code_message = 'Service error';
        detail.messages = null;

        ExampleResponse.Error err = new ExampleResponse.Error();
        err.error = detail;

        Test.startTest();
            String actual = err.getErrorMessage();
        Test.stopTest();
        
        Assert.areEqual('Service error with no detail', actual, 'Unexpected error message');
    }

    @IsTest
    static void testErrorWithPopulatedMessages() {
        ExampleResponse.MessageDetail msg1 = new ExampleResponse.MessageDetail();
        msg1.field = 'name';
        msg1.code_message = 'Name is required';

        ExampleResponse.MessageDetail msg2 = new ExampleResponse.MessageDetail();
        msg2.code_message = 'Unexpected error';

        ExampleResponse.ErrorDetail detail = new ExampleResponse.ErrorDetail();
        detail.code_message = 'Validation failed';
        detail.messages = new List<ExampleResponse.MessageDetail>{ msg1, msg2 };

        ExampleResponse.Error err = new ExampleResponse.Error();
        err.error = detail;

        Test.startTest();
            String actual = err.getErrorMessage();
        Test.stopTest();

        String expected = 'Validation failed - Field "name": Name is required; Unexpected error';
        Assert.areEqual(expected, actual, 'Unexpected error message');
    }

    @IsTest
    static void testErrorWithNullMessageObjects() {
        ExampleResponse.ErrorDetail detail = new ExampleResponse.ErrorDetail();
        detail.code_message = 'Partial failure';
        detail.messages = new List<ExampleResponse.MessageDetail>{ null, null };

        ExampleResponse.Error err = new ExampleResponse.Error();
        err.error = detail;

        Test.startTest();
            String actual = err.getErrorMessage();
        Test.stopTest();

        Assert.areEqual('Partial failure - No detail; No detail', actual, 'Unexpected error message');
    }

    @IsTest
    static void testMessageDetailWithOnlyField() {
        ExampleResponse.MessageDetail detail = new ExampleResponse.MessageDetail();
        detail.field = 'email';

        Test.startTest();
            String actual = detail.getErrorMessage();
        Test.stopTest();

        Assert.areEqual('Field "email": ', actual, 'Unexpected detail error message');
    }

    @IsTest
    static void testMessageDetailWithOnlyCodeMessage() {
        ExampleResponse.MessageDetail detail = new ExampleResponse.MessageDetail();
        detail.code_message = 'Invalid input';

        Test.startTest();
            String actual = detail.getErrorMessage();
        Test.stopTest();

        Assert.areEqual('Invalid input', actual, 'Unexpected detail error message');
    }

    @IsTest
    static void testMessageDetailWithFieldAndCodeMessage() {
        ExampleResponse.MessageDetail detail = new ExampleResponse.MessageDetail();
        detail.field = 'address';
        detail.code_message = 'Missing address line';

        Test.startTest();
            String actual = detail.getErrorMessage();
        Test.stopTest();

        Assert.areEqual('Field "address": Missing address line', actual, 'Unexpected detail error message');
    }

}