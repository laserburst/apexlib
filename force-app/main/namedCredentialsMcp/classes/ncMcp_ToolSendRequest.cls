/**
 * @description MCP tool sendRequest
 * @team Laserburst
 */
global with sharing class ncMcp_ToolSendRequest {
    @InvocableMethod(
        label='Send Request'
        description='Sends one HTTP request to an API from listCredentials. Salesforce adds the credential, so you never see it. Call describe first for the allowed routes. Every status comes back as a result; an error body the policies withhold is empty, with the status "Withheld by policy". A request the policies block fails before anything is sent, with a message that names the method, the path and the rule.'
        callout=true
        category='Named Credentials MCP'
    )
    global static List<ncMcp_CalloutResponse> sendRequest(List<ncMcp_CalloutRequest> requests) {
        return ncMcp_CalloutRequest.sendAll(requests);
    }
}