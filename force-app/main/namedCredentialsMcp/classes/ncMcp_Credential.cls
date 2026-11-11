/**
 * @description ncMcp_Credential is what an agent may know about one Named Credential: its name, label and description.
 * The tools serialize it as is, so its fields are the agent-facing names.
 * @team Laserburst
 */
public with sharing class ncMcp_Credential {
    // ConnectApi throws in a test without SeeAllData, so a test puts its credentials here; empty outside tests
    @TestVisible
    private static final Map<String, ConnectApi.NamedCredential> TEST_CREDENTIAL_BY_NAME =
        new Map<String, ConnectApi.NamedCredential>();

    private final String name;
    private final String label;
    private final String description;

    /**
     * @return null when ConnectApi can't return the Named Credential or its callouts are disabled
     */
    public static ncMcp_Credential forName(String name) {
        ConnectApi.NamedCredential namedCredential = toNamedCredential(name);
        if (namedCredential == null || namedCredential.calloutStatus == ConnectApi.CalloutStatus.Disabled) {
            return null;
        }
        return new ncMcp_Credential(name, namedCredential);
    }

    // ConnectApiAdapter returns null when the Named Credential doesn't exist or the user can't see it
    private static ConnectApi.NamedCredential toNamedCredential(String name) {
        if (TEST_CREDENTIAL_BY_NAME.containsKey(name)) {
            return TEST_CREDENTIAL_BY_NAME.get(name);
        }
        return ConnectApiAdapter.getNamedCredential(name);
    }

    private ncMcp_Credential(String name, ConnectApi.NamedCredential namedCredential) {
        this.name = name;
        this.label = namedCredential.masterLabel;
        this.description = namedCredential.description;
    }

    public String getName() {
        return this.name;
    }

    public String getLabel() {
        return this.label;
    }

    /**
     * @return the Named Credential's Description, or null when the admin wrote none
     */
    public String getDescription() {
        return this.description;
    }
}