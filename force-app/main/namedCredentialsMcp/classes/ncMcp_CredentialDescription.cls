/**
 * @description ncMcp_CredentialDescription is one exposed Named Credential and its routes: the output of the
 * describe tool. Conditions aren't evaluated without a callout, so a listed route can still be refused.
 * @team Laserburst
 */
global with sharing class ncMcp_CredentialDescription {
    @InvocableVariable(description='The name to pass as namedCredential to sendRequest.')
    global String name;

    @InvocableVariable(description='The Named Credential label.')
    global String label;

    @InvocableVariable(description='What the API is for, as the admin wrote it; may be empty.')
    global String description;

    @InvocableVariable(
        description='JSON object of the allowed methods by endpoint pattern, such as {"/items/{id}":["GET","PATCH"]}. A route a policy condition refuses for this user can still be listed.'
    )
    global String routes;

    // a static factory, not a constructor: invocable action parameters need the implicit no-argument constructor
    public static ncMcp_CredentialDescription forCredential(
        ncMcp_Credential credential,
        Map<String, Set<String>> methodsByEndpoint
    ) {
        ncMcp_CredentialDescription result = new ncMcp_CredentialDescription();
        result.name = credential.getName();
        result.label = credential.getLabel();
        result.description = credential.getDescription();
        result.routes = JSON.serialize(methodsByEndpoint);
        return result;
    }
}