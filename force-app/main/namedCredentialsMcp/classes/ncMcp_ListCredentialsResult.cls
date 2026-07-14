/**
* @description Output type of the listCredentials MCP tool. credentials is a
* JSON array string (rather than a nested Apex type) because a documented JSON
* string renders reliably in an MCP output schema. Each element is a
* Credential, below.
* @team Laserburst
*/
global with sharing class ncMcp_ListCredentialsResult {
    @InvocableVariable(
        description='JSON array string. Each element: {"name":"<use as describe/sendRequest namedCredential>","isConfigured":true when the credential is authenticated and ready to use,"baseUrl":"resolved callout base URL, may be null","principalType":"NamedPrincipal or PerUserPrincipal, may be null"}. Empty array [] when no credentials are exposed.'
    )
    global String credentials;

    global ncMcp_ListCredentialsResult() {
    }

    global ncMcp_ListCredentialsResult(String credentials) {
        this.credentials = credentials;
    }

    /**
    * @description One exposed Named Credential, as serialized into credentials.
    */
    public class Credential {
        public String name;
        public Boolean isConfigured;
        public String baseUrl;
        public String principalType;
    }
}