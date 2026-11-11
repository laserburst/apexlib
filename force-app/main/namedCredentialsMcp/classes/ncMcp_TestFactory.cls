/**
 * @description ncMcp_TestFactory builds what the Named Credentials MCP tests share: users with and without the
 * permission set, and Named Credentials in place of ConnectApi
 * @team Laserburst
 */
@IsTest
public class ncMcp_TestFactory {
    public static final String MCP_USER = 'ncMcpUser';
    public static final String PLAIN_USER = 'ncMcpPlain';

    /**
     * @description insertUsers runs in @TestSetup, so no DML is pending when a test makes a callout
     */
    public static void insertUsers() {
        Id profileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;
        User mcpUser = toUser(MCP_USER, profileId);
        User plainUser = toUser(PLAIN_USER, profileId);
        insert new List<User>{ mcpUser, plainUser };
        Id permissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Named_Credentials_MCP_User' LIMIT 1].Id;
        insert new PermissionSetAssignment(AssigneeId = mcpUser.Id, PermissionSetId = permissionSetId);
    }

    public static User getUser(String lastName) {
        return [SELECT Id FROM User WHERE LastName = :lastName LIMIT 1];
    }

    /**
     * @description addCredential makes ncMcp_Credential.forName() see a Named Credential labeled "<name> API" and
     * described as "<name> items"
     */
    public static void addCredential(String name, ConnectApi.CalloutStatus calloutStatus) {
        ConnectApi.NamedCredential namedCredential = new ConnectApi.NamedCredential();
        namedCredential.developerName = name;
        namedCredential.masterLabel = name + ' API';
        namedCredential.description = name + ' items';
        namedCredential.calloutStatus = calloutStatus;
        ncMcp_Credential.TEST_CREDENTIAL_BY_NAME.put(name, namedCredential);
    }

    private static User toUser(String lastName, Id profileId) {
        return new User(
            Alias = lastName.left(8),
            Email = lastName + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LastName = lastName,
            LocaleSidKey = 'en_US',
            ProfileId = profileId,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = lastName + '.' + Crypto.getRandomInteger() + '@example.com'
        );
    }
}