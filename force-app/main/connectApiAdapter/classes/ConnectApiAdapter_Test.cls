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
        Boolean isConfigured;
        Test.startTest();
            isConfigured = ConnectApiAdapter.isCredentialConfigured(null, null, null);
        Test.stopTest();

        Assert.isTrue(isConfigured, 'Should return true');
    }

    @isTest
    static void testGetNamedCredential() {
        Test.startTest();
            ConnectApi.NamedCredential result = ConnectApiAdapter.getNamedCredential('test');
        Test.stopTest();

        Assert.isNull(result, 'Should be null as ConnectApi is not testable');
    }

    @isTest
    static void testGetExternalCredential() {
        Test.startTest();
            ConnectApi.ExternalCredential result = ConnectApiAdapter.getExternalCredential('test');
        Test.stopTest();

        Assert.isNull(result, 'Should be null as ConnectApi is not testable');
    }

    @isTest
    static void testGetCredentialAuthenticationUrl() {
        Test.startTest();
            String result = ConnectApiAdapter.getCredentialAuthenticationUrl(
                'test',
                'test',
                ConnectApi.CredentialPrincipalType.PerUserPrincipal
            );
        Test.stopTest();

        Assert.isNull(result, 'Should be null as ConnectApi is not testable');
    }
}
