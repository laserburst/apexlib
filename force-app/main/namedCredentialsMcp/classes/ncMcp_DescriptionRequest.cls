/**
 * @description ncMcp_DescriptionRequest asks for the description of one exposed Named Credential: the input of the
 * describe tool
 * @team Laserburst
 */
global with sharing class ncMcp_DescriptionRequest {
    @InvocableVariable(required=true description='The name of an API, exactly as listCredentials returns it.')
    global String namedCredential;

    /**
     * @description describeAll describes the requests in order and stops at the first one that throws
     */
    public static List<ncMcp_CredentialDescription> describeAll(List<ncMcp_DescriptionRequest> requests) {
        List<ncMcp_CredentialDescription> descriptions = new List<ncMcp_CredentialDescription>();
        for (ncMcp_DescriptionRequest request : requests) {
            descriptions.add(request.describe());
        }
        return descriptions;
    }

    /**
     * @description describe throws ncMcp_ToolException with ncMcp_PolicyCatalog.NOT_EXPOSED for a name that isn't
     * exposed or that ConnectApi doesn't return to the user
     */
    public ncMcp_CredentialDescription describe() {
        Map<String, Set<String>> methodsByEndpoint =
            ncMcp_PolicyCatalog.getInstance().getMethodsByEndpoint(this.namedCredential);
        ncMcp_Credential credential = ncMcp_Credential.forName(this.namedCredential);
        if (credential == null) {
            throw new ncMcp_ToolException(ncMcp_PolicyCatalog.NOT_EXPOSED);
        }
        return ncMcp_CredentialDescription.forCredential(credential, methodsByEndpoint);
    }
}