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

    @isTest
    static void testRefreshTokenSingleParameter() {
        Test.startTest();
            ConnectApiAdapter.refreshToken('test');
        Test.stopTest();

        // nothing to assert
    }

    @isTest
    static void testIsCredentialConfiguredSingleParameter() {
        Boolean isConfigured;
        Test.startTest();
            isConfigured = ConnectApiAdapter.isCredentialConfigured('test');
        Test.stopTest();

        Assert.isTrue(isConfigured, 'Should return true');
    }

    @isTest
    static void testGetCredentialAuthenticationUrlSingleParameter() {
        Test.startTest();
            String result = ConnectApiAdapter.getCredentialAuthenticationUrl('test');
        Test.stopTest();

        Assert.isNull(result, 'Should be null as ConnectApi is not testable');
    }

    @isTest
    static void testGetSinglePrincipal() {
        ConnectApi.ExternalCredentialPrincipal principal = new ConnectApi.ExternalCredentialPrincipal();
        principal.principalName = 'test';
        ConnectApi.ExternalCredential credential = new ConnectApi.ExternalCredential();
        credential.principals = new List<ConnectApi.ExternalCredentialPrincipal>{ principal };

        Test.startTest();
            ConnectApi.ExternalCredentialPrincipal result = ConnectApiAdapter.getSinglePrincipal(credential, 'test');
        Test.stopTest();

        Assert.areEqual('test', result.principalName, 'Should return the only principal');
    }

    @isTest
    static void testGetSinglePrincipalThrowsOnNullExternalCredential() {
        Test.startTest();
            try {
                ConnectApiAdapter.getSinglePrincipal(null, 'test');
                Assert.fail('Expected ConnectApiAdapterException to be thrown');
            } catch (ConnectApiAdapter.ConnectApiAdapterException e) {
                Assert.isTrue(
                    e.getMessage().contains('could not be retrieved'),
                    'Message should explain the credential could not be retrieved'
                );
            }
        Test.stopTest();
    }

    @isTest
    static void testGetSinglePrincipalThrowsOnNullPrincipals() {
        ConnectApi.ExternalCredential credential = new ConnectApi.ExternalCredential();
        credential.principals = null;

        Test.startTest();
            try {
                ConnectApiAdapter.getSinglePrincipal(credential, 'test');
                Assert.fail('Expected ConnectApiAdapterException to be thrown');
            } catch (ConnectApiAdapter.ConnectApiAdapterException e) {
                Assert.isTrue(e.getMessage().contains('has 0 principals'), 'Message should report 0 principals');
            }
        Test.stopTest();
    }

    @isTest
    static void testGetSinglePrincipalThrowsOnZeroPrincipals() {
        ConnectApi.ExternalCredential credential = new ConnectApi.ExternalCredential();
        credential.principals = new List<ConnectApi.ExternalCredentialPrincipal>();

        Test.startTest();
            try {
                ConnectApiAdapter.getSinglePrincipal(credential, 'test');
                Assert.fail('Expected ConnectApiAdapterException to be thrown');
            } catch (ConnectApiAdapter.ConnectApiAdapterException e) {
                Assert.isTrue(e.getMessage().contains('has 0 principals'), 'Message should report 0 principals');
            }
        Test.stopTest();
    }

    @isTest
    static void testGetClientId() {
        ConnectApi.ExternalAuthIdentityProviderCredential credential = new ConnectApi.ExternalAuthIdentityProviderCredential();
        credential.credentialName = 'clientId';
        credential.credentialValue = 'test';

        Test.startTest();
            String result = ConnectApiAdapter.getClientId(
                new List<ConnectApi.ExternalAuthIdentityProviderCredential>{ credential }
            );
        Test.stopTest();

        Assert.areEqual('test', result, 'Should return the clientId credential value');
    }

    @isTest
    static void testGetClientIdNoMatch() {
        ConnectApi.ExternalAuthIdentityProviderCredential credential = new ConnectApi.ExternalAuthIdentityProviderCredential();
        credential.credentialName = 'clientSecret';
        credential.credentialValue = 'test';

        Test.startTest();
            String result = ConnectApiAdapter.getClientId(
                new List<ConnectApi.ExternalAuthIdentityProviderCredential>{ credential }
            );
        Test.stopTest();

        Assert.isNull(result, 'Should be null when no clientId credential exists');
    }

    @isTest
    static void testGetClientIdEmptyList() {
        Test.startTest();
            String result = ConnectApiAdapter.getClientId(new List<ConnectApi.ExternalAuthIdentityProviderCredential>());
        Test.stopTest();

        Assert.isNull(result, 'Should be null for empty credentials');
    }

    @isTest
    static void testGetClientIdNullList() {
        Test.startTest();
            String result = ConnectApiAdapter.getClientId(null);
        Test.stopTest();

        Assert.isNull(result, 'Should be null for null credentials');
    }

    @isTest
    static void testGetAuthenticationProtocol() {
        ConnectApi.ExternalCredential credential = new ConnectApi.ExternalCredential();
        credential.authenticationProtocol = ConnectApi.CredentialAuthenticationProtocol.OAuth;

        Test.startTest();
            ConnectApi.CredentialAuthenticationProtocol result =
                ConnectApiAdapter.getAuthenticationProtocol(credential, 'test');
        Test.stopTest();

        Assert.areEqual(ConnectApi.CredentialAuthenticationProtocol.OAuth, result, 'Should return the protocol');
    }

    @isTest
    static void testGetAuthenticationProtocolThrowsOnNullProtocol() {
        ConnectApi.ExternalCredential credential = new ConnectApi.ExternalCredential();

        Test.startTest();
            try {
                ConnectApiAdapter.getAuthenticationProtocol(credential, 'test');
                Assert.fail('Expected ConnectApiAdapterException to be thrown');
            } catch (ConnectApiAdapter.ConnectApiAdapterException e) {
                Assert.isTrue(
                    e.getMessage().contains('no visible authentication protocol'),
                    'Message should explain the protocol is not visible'
                );
            }
        Test.stopTest();
    }

    @isTest
    static void testGetSinglePrincipalThrowsOnMultiplePrincipals() {
        ConnectApi.ExternalCredential credential = new ConnectApi.ExternalCredential();
        credential.principals = new List<ConnectApi.ExternalCredentialPrincipal>{
            new ConnectApi.ExternalCredentialPrincipal(),
            new ConnectApi.ExternalCredentialPrincipal()
        };

        Test.startTest();
            try {
                ConnectApiAdapter.getSinglePrincipal(credential, 'test');
                Assert.fail('Expected ConnectApiAdapterException to be thrown');
            } catch (ConnectApiAdapter.ConnectApiAdapterException e) {
                Assert.isTrue(e.getMessage().contains('has 2 principals'), 'Message should report 2 principals');
            }
        Test.stopTest();
    }
}