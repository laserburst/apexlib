@IsTest
private class ncMcp_DescriptionRequest_Test {
    @TestSetup
    static void makeUsers() {
        ncMcp_TestFactory.insertUsers();
    }

    @IsTest
    static void testDescribe() {
        ncMcp_PolicyCatalog.instance =
            new ncMcp_PolicyCatalog(
                new List<CalloutPolicy>{
                    new CalloutPolicy('callout:Items').withMethod('GET').withEndpoint('/items/*'),
                    new CalloutPolicy('callout:Items').withMethod('PATCH').withEndpoint('/items/{id}'),
                    new CalloutPolicy('callout:Disabled').withMethod('GET')
                }
            );
        ncMcp_TestFactory.addCredential('Items', ConnectApi.CalloutStatus.Enabled);
        ncMcp_TestFactory.addCredential('Disabled', ConnectApi.CalloutStatus.Disabled);
        Map<String, Object> expectedByName =
            new Map<String, Object>{
                'Items' => new List<Object>{
                    'Items',
                    'Items API',
                    'Items items',
                    new Map<String, Object>{
                        '/items/*' => new List<Object>{ 'GET' },
                        '/items/{id}' => new List<Object>{ 'PATCH' }
                    }
                },
                'Disabled' => ncMcp_PolicyCatalog.NOT_EXPOSED,
                'Other' => ncMcp_PolicyCatalog.NOT_EXPOSED
            };

        Map<String, Object> outcomeByName = new Map<String, Object>();
        System.runAs(ncMcp_TestFactory.getUser(ncMcp_TestFactory.MCP_USER)) {
            Test.startTest();
            for (String name : expectedByName.keySet()) {
                outcomeByName.put(name, toOutcome(name));
            }
            Test.stopTest();
        }

        Assert.areEqual(
            expectedByName,
            outcomeByName,
            'Only an exposed credential ConnectApi returns should be described'
        );
    }

    // the description's fields with the routes parsed, or the error
    private static Object toOutcome(String name) {
        ncMcp_DescriptionRequest request = new ncMcp_DescriptionRequest();
        request.namedCredential = name;
        try {
            ncMcp_CredentialDescription description =
                ncMcp_ToolDescribe.describe(new List<ncMcp_DescriptionRequest>{ request })[0];
            return new List<Object>{
                description.name,
                description.label,
                description.description,
                JSON.deserializeUntyped(description.routes)
            };
        } catch (ncMcp_ToolException e) {
            return e.getMessage();
        }
    }
}