/**
 * @description ncMcp_CredentialList is the exposed Named Credentials that ConnectApi returns to the user: the output
 * of the listCredentials tool
 * @team Laserburst
 */
global with sharing class ncMcp_CredentialList {
    @InvocableVariable(
        description='JSON array; each element is {"name":"...","label":"...","description":"..."}. description is left out when the admin wrote none. [] when no API is exposed.'
    )
    global String credentials;

    /**
     * @description forUser throws ncMcp_ToolException when the user lacks the Named_Credentials_MCP custom permission
     */
    public static ncMcp_CredentialList forUser() {
        List<ncMcp_Credential> credentials = new List<ncMcp_Credential>();
        for (String name : ncMcp_PolicyCatalog.getInstance().getCredentialNames()) {
            ncMcp_Credential credential = ncMcp_Credential.forName(name);
            if (credential != null) {
                credentials.add(credential);
            }
        }
        ncMcp_CredentialList result = new ncMcp_CredentialList();
        result.credentials = JSON.serialize(credentials, true);
        return result;
    }
}