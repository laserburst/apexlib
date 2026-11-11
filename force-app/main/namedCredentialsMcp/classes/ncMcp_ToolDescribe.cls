/**
 * @description MCP tool describe
 * @team Laserburst
 */
global with sharing class ncMcp_ToolDescribe {
    @InvocableMethod(
        label='Describe Named Credential'
        description='Describes one API from listCredentials: its label, description and routes. Each route is an endpoint pattern with the HTTP methods allowed on it. {name} stands for one path segment; a trailing /* also matches everything below the path. A header or query parameter must be granted by policy: a blocked sendRequest names the one that is not.'
        category='Named Credentials MCP'
    )
    global static List<ncMcp_CredentialDescription> describe(List<ncMcp_DescriptionRequest> requests) {
        return ncMcp_DescriptionRequest.describeAll(requests);
    }
}