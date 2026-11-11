/**
 * @description MCP tool listCredentials
 * @team Laserburst
 */
global with sharing class ncMcp_ToolListCredentials {
    @InvocableMethod(
        label='List Named Credentials'
        description='Lists the external APIs you can call through this org\'s Named Credentials. Call it first. Each entry has name (pass it as namedCredential to describe and sendRequest), label and description. A call the user is not authorized for fails with the platform\'s own message.'
        category='Named Credentials MCP'
    )
    global static List<ncMcp_CredentialList> listCredentials() {
        return new List<ncMcp_CredentialList>{ ncMcp_CredentialList.forUser() };
    }
}