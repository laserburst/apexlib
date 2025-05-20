@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.ApexDoc')
@isTest
private with sharing class ConnectApiAdapter_Test {
    @isTest
    static void testGetAppClientIdFromExternalAuthIdentityProvider() {
        Test.startTest();
            String result = ConnectApiAdapter.getAppClientIdFromExternalAuthIdentityProvider('test');
        Test.stopTest();

        Assert.isTrue(result == null, 'App client id should be null as ConnectApi is not testable');
    }

    @isTest
    static void testGetCalloutUrl() {
        Test.startTest();
            String result = ConnectApiAdapter.getCalloutUrl('test');
        Test.stopTest();

        Assert.isTrue(result == null, 'URL should be null as ConnectApi is not testable');
    }

    @isTest
    static void testRefreshToken() {
        Test.startTest();
            ConnectApiAdapter.refreshToken(null, null, null, null);
        Test.stopTest();

        // nothing to assert
    }

    @isTest
    static void testIsCredentialConfigured() {
        Test.startTest();
            ConnectApiAdapter.isCredentialConfigured(null, null, null);
        Test.stopTest();

        // nothing to assert
    }
}
