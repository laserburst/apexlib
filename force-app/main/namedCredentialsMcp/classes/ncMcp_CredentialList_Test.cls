@IsTest
private class ncMcp_CredentialList_Test {
    @TestSetup
    static void makeUsers() {
        ncMcp_TestFactory.insertUsers();
    }

    @IsTest
    static void testForUser() {
        ncMcp_PolicyCatalog.instance =
            new ncMcp_PolicyCatalog(
                new List<CalloutPolicy>{
                    new CalloutPolicy('callout:Items').withMethod('GET'),
                    new CalloutPolicy('callout:Disabled').withMethod('GET')
                }
            );
        ncMcp_TestFactory.addCredential('Items', ConnectApi.CalloutStatus.Enabled);
        ncMcp_TestFactory.addCredential('Disabled', ConnectApi.CalloutStatus.Disabled);

        List<ncMcp_CredentialList> lists;
        System.runAs(ncMcp_TestFactory.getUser(ncMcp_TestFactory.MCP_USER)) {
            Test.startTest();
            lists = ncMcp_ToolListCredentials.listCredentials();
            Test.stopTest();
        }

        Assert.areEqual(
            new List<Object>{
                new Map<String, Object>{ 'name' => 'Items', 'label' => 'Items API', 'description' => 'Items items' }
            },
            JSON.deserializeUntyped(lists[0].credentials),
            'Only the exposed credentials ConnectApi returns should be listed'
        );
    }
}