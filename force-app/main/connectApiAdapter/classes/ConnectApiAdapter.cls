/**
**@description It simplifies work with ConnectApi namespace.
* @team Laserburst
*/
public inherited sharing class ConnectApiAdapter {
    /**
    * @description getCalloutUrl returns base URL.
    * It may be helpful for building links.
    * @param  namedCredentialApiName
    * @return callout URL
    */
    public static String getCalloutUrl(String namedCredentialApiName) {
        return getNamedCredential(namedCredentialApiName)?.calloutUrl;
    }

    /**
    * @description getAppClientIdFromExternalAuthIdentityProvider
    * extract client id from External Auth Identity Provider
    * This id may be required as query parameter in some URLs
    * @param  apiName
    * @return client id of the app configured on external system
    */
    public static String getAppClientIdFromExternalAuthIdentityProvider(String apiName) {
        if (Test.isRunningTest()) {
            //ConnectApi is not testable
            return null;
        }
        return getClientId(ConnectApi.NamedCredentials.getExternalAuthIdentityProviderCredentials(apiName)?.credentials);
    }

    /**
    * @description getClientId extracts the clientId credential value
    * @param  credentials External Auth Identity Provider credentials
    * @return client id or null
    */
    @TestVisible
    private static String getClientId(List<ConnectApi.ExternalAuthIdentityProviderCredential> credentials) {
        if (credentials == null) {
            return null;
        }
        for (ConnectApi.ExternalAuthIdentityProviderCredential cr : credentials) {
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
    * @description refreshToken overload for an external credential with a single principal
    * @param  externalCredential api name of the external credential
    */
    public static void refreshToken(String externalCredential) {
        if (Test.isRunningTest()) {
            //ConnectApi is not testable
            return;
        }
        ConnectApi.ExternalCredential credential = getExternalCredential(externalCredential);
        ConnectApi.ExternalCredentialPrincipal principal = getSinglePrincipal(credential, externalCredential);
        refreshToken(
            externalCredential,
            principal.principalName,
            principal.principalType,
            getAuthenticationProtocol(credential, externalCredential)
        );
    }

    /**
    * @description isCredentialConfigured
    * @param  externalCredential api name of the external credential
    * @param  principalName (previously called Permission Set Mapping)
    * @param  principalType - https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/connectAPI_enums.htm#CredentialPrincipalTypeEnum
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

    /**
    * @description isCredentialConfigured overload for an external credential with a single principal
    * @param  externalCredential api name of the external credential
    * @return true if configured
    */
    public static Boolean isCredentialConfigured(String externalCredential) {
        if (Test.isRunningTest()) {
            return true;
        }
        ConnectApi.ExternalCredentialPrincipal principal =
            getSinglePrincipal(getExternalCredential(externalCredential), externalCredential);
        return isCredentialConfigured(externalCredential, principal.principalName, principal.principalType);
    }

    /**
     * @description getCredentialAuthenticationUrl
     * @param  externalCredential api name of the external credential
     * @param  principalName (previously called Permission Set Mapping)
     * @param  principalType - https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/connectAPI_enums.htm#CredentialPrincipalTypeEnum
     * @return authentication URL for OAuth flow
     */
    public static String getCredentialAuthenticationUrl(
        String externalCredential,
        String principalName,
        ConnectApi.CredentialPrincipalType principalType
    ) {
        ConnectApi.OAuthCredentialAuthUrlInput input = new ConnectApi.OAuthCredentialAuthUrlInput();

        input.externalCredential = externalCredential;
        input.principalName = principalName;
        input.principalType = principalType;

        if (Test.isRunningTest()) {
            return null;
        }

        ConnectApi.OAuthCredentialAuthUrl output = ConnectApi.NamedCredentials.getOAuthCredentialAuthUrl(input);
        return output.authenticationUrl;
    }

    /**
     * @description getCredentialAuthenticationUrl overload for an external credential with a single principal
     * @param  externalCredential api name of the external credential
     * @return authentication URL for OAuth flow
     */
    public static String getCredentialAuthenticationUrl(String externalCredential) {
        if (Test.isRunningTest()) {
            return null;
        }
        ConnectApi.ExternalCredentialPrincipal principal =
            getSinglePrincipal(getExternalCredential(externalCredential), externalCredential);
        return getCredentialAuthenticationUrl(externalCredential, principal.principalName, principal.principalType);
    }

    /**
    * @description getNamedCredential returns the full Named Credential
    * including its callout URL and associated external credentials.
    * @param  namedCredentialApiName
    * @return Named Credential details or null when it cannot be retrieved
    */
    public static ConnectApi.NamedCredential getNamedCredential(String namedCredentialApiName) {
        if (Test.isRunningTest()) {
            //ConnectApi is not testable
            return null;
        }
        try {
            return ConnectApi.NamedCredentials.getNamedCredential(namedCredentialApiName);
        } catch (Exception e) {
            return null;
        }
    }

    /**
    * @description getExternalCredential returns External Credential details
    * including its principals and their authentication status.
    * @param  externalCredentialApiName
    * @return External Credential details
    */
    public static ConnectApi.ExternalCredential getExternalCredential(String externalCredentialApiName) {
        if (Test.isRunningTest()) {
            //ConnectApi is not testable
            return null;
        }
        return ConnectApi.NamedCredentials.getExternalCredential(externalCredentialApiName);
    }

    /**
    * @description getSinglePrincipal extracts the only principal of an external credential
    * @param  externalCredential fetched External Credential
    * @param  externalCredentialApiName api name for error messages
    * @return the single principal
    */
    @TestVisible
    private static ConnectApi.ExternalCredentialPrincipal getSinglePrincipal(
        ConnectApi.ExternalCredential externalCredential,
        String externalCredentialApiName
    ) {
        if (externalCredential == null) {
            throw new ConnectApiAdapterException(
                'External credential "' + externalCredentialApiName + '" could not be retrieved. ' +
                'Check the API name and the running user\'s access.'
            );
        }
        Integer principalCount = externalCredential.principals == null ? 0 : externalCredential.principals.size();
        if (principalCount != 1) {
            throw new ConnectApiAdapterException(
                'External credential "' + externalCredentialApiName + '" has ' + principalCount +
                ' principals visible to the running user; the single-parameter overload requires exactly 1. ' +
                'Use the overload with explicit principalName and principalType. If a principal exists but is not ' +
                'listed, ensure the running user has the "View Setup and Configuration" permission.'
            );
        }
        return externalCredential.principals[0];
    }

    /**
    * @description getAuthenticationProtocol extracts the authentication protocol of an external credential
    * @param  externalCredential fetched External Credential
    * @param  externalCredentialApiName api name for error messages
    * @return the authentication protocol
    */
    @TestVisible
    private static ConnectApi.CredentialAuthenticationProtocol getAuthenticationProtocol(
        ConnectApi.ExternalCredential externalCredential,
        String externalCredentialApiName
    ) {
        if (externalCredential.authenticationProtocol == null) {
            throw new ConnectApiAdapterException(
                'External credential "' + externalCredentialApiName + '" has no visible authentication protocol; ' +
                'the single-parameter refreshToken() cannot derive it. Call the full-parameter refreshToken() ' +
                'or ensure the running user has the "View Setup and Configuration" permission.'
            );
        }
        return externalCredential.authenticationProtocol;
    }

    /**
    * @description custom adapter exception
    */
    public class ConnectApiAdapterException extends Exception {}
}