/**
**@description It simplifies work with ConnectApi namespace.
* @team Laserburst
*/
public with sharing class ConnectApiAdapter {
    /**
    * @description getCalloutUrl returns base URL.
    * It may be helpful for building links.
    * @param  namedCredentialApiName
    * @return callout URL
    */
    public static String getCalloutUrl(String namedCredentialApiName) {
        ConnectApi.NamedCredential nc;
        if (Test.isRunningTest()) {
            //ConnectApi is not testable
            nc = null;
        } else {
            nc = ConnectApi.NamedCredentials.getNamedCredential(namedCredentialApiName);
            return nc.calloutUrl;
        }
        return null;
    }

    /**
    * @description getAppClientIdFromExternalAuthIdentityProvider
    * extract client id from External Auth Identity Provider
    * This id may be required as query parameter in some URLs
    * @param  apiName
    * @return client id of the app configured on external system
    */
    public static String getAppClientIdFromExternalAuthIdentityProvider(String apiName) {
        List<ConnectApi.ExternalAuthIdentityProviderCredential> externalAuth;

        if (Test.isRunningTest()) {
            //ConnectApi is not testable
            externalAuth = new List<ConnectApi.ExternalAuthIdentityProviderCredential>();
        } else {
            externalAuth = ConnectApi.NamedCredentials.getExternalAuthIdentityProviderCredentials(apiName)?.credentials;
        }

        for (ConnectApi.ExternalAuthIdentityProviderCredential cr : externalAuth) {
            if (cr.credentialName == 'clientId') {
                return cr.credentialValue;
            }
        }
        return null;
    }

    /**
    * @description refreshToken triggers token refresh.
    * Use case: external resource returns 2xx success code
    * for not authorized requests and access token is expired
    * Example:
    * https://developer.salesforce.com/docs/platform/named-credentials/guide/nc-manage-oauth-cred.html#example-refresh-a-token
    * @param  externalCredential api name of the external credential
    * @param  principalName (previously called Permission Set Mapping)
    * @param  principalType - https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/connectAPI_enums.htm#CredentialPrincipalTypeEnum
    * @param  authenticationProtocol - https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/connectAPI_enums.htm#CredentialAuthenticationProtocolEnum
    */
    public static void refreshToken(
        String externalCredential,
        String principalName,
        ConnectApi.CredentialPrincipalType principalType,
        ConnectApi.CredentialAuthenticationProtocol authenticationProtocol
    ) {
        ConnectApi.CredentialInput credentialInput = new ConnectApi.CredentialInput();
        credentialInput.externalCredential = externalCredential;
        credentialInput.principalName = principalName;
        credentialInput.principalType = principalType;
        credentialInput.authenticationProtocol = authenticationProtocol;
        credentialInput.credentials = new Map<String, ConnectApi.CredentialValueInput>();

        if (!Test.isRunningTest()) {
            ConnectApi.NamedCredentials.createCredential(credentialInput, ConnectApi.CreateCredentialAction.Refresh);
        }
    }

    /**
    * @description isCredentialConfigured
    * @return true if configured
    */
    public static Boolean isCredentialConfigured(
        String externalCredential,
        String principalName,
        ConnectApi.CredentialPrincipalType principalType
    ) {
        if (Test.isRunningTest()) {
            return true;
        }
        ConnectApi.Credential cred =
            ConnectApi.NamedCredentials.getCredential(externalCredential, principalName, principalType);
        return cred.authenticationStatus == ConnectApi.CredentialAuthenticationStatus.Configured;
    }
}
