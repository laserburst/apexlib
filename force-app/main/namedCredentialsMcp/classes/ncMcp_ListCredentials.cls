/**
 * @description MCP tool "listCredentials": lists the Named Credentials exposed
 * through this server (those with an active configuration record) and whether
 * each is ready to use for the running context. Unlike describe, it does NOT
 * filter out unauthenticated credentials — isConfigured=false with a principal
 * type tells an agent which kind of authorization is missing. Takes no inputs.
 * Exposed as an invocable action so it is also usable from Flows and Agentforce.
 * @team Laserburst
 */
global with sharing class ncMcp_ListCredentials {
    @InvocableMethod(
        label='List Named Credentials'
        description='Lists the Named Credentials exposed through this server and whether each is ready to use. Each entry has the credential\'s name, isConfigured (true when it is authenticated for the current context), its base URL, and its principal type. Call this first to discover credentials; it does not include usage details — call the describe tool on one credential to learn how to call it.'
        callout=true
        category='Named Credentials MCP'
    )
    global static List<ncMcp_ListCredentialsResult> listCredentials() {
        return new List<ncMcp_ListCredentialsResult>{
            new ncMcp_ListCredentialsResult(JSON.serialize(buildCredentials()))
        };
    }

    private static List<ncMcp_ListCredentialsResult.Credential> buildCredentials() {
        List<String> names = new List<String>(ncMcp_Config.getActive().keySet());
        names.sort();

        List<ncMcp_ListCredentialsResult.Credential> credentials = new List<ncMcp_ListCredentialsResult.Credential>();
        for (String name : names) {
            ncMcp_AuthenticationGuardrail.Status status = ncMcp_AuthenticationGuardrail.getStatus(name);
            ncMcp_ListCredentialsResult.Credential credential = new ncMcp_ListCredentialsResult.Credential();
            credential.name = name;
            credential.isConfigured = status.isAuthenticated;
            credential.baseUrl = status.baseUrl;
            credential.principalType = status.principalType;
            credentials.add(credential);
        }
        return credentials;
    }
}
