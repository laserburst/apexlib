@IsTest
private class ncMcp_Credential_Test {
    private static final String HIDDEN = 'hidden';

    @IsTest
    static void testForName() {
        ncMcp_TestFactory.addCredential('Items', ConnectApi.CalloutStatus.Enabled);
        ncMcp_TestFactory.addCredential('Disabled', ConnectApi.CalloutStatus.Disabled);
        Map<String, String> expectedByName =
            new Map<String, String>{
                'Items' => 'Items | Items API | Items items',
                'Disabled' => HIDDEN,
                'Unknown to ConnectApi' => HIDDEN
            };

        Test.startTest();
        Map<String, String> outcomeByName = new Map<String, String>();
        for (String name : expectedByName.keySet()) {
            outcomeByName.put(name, toOutcome(ncMcp_Credential.forName(name)));
        }
        Test.stopTest();

        Assert.areEqual(
            expectedByName,
            outcomeByName,
            'A credential ConnectApi returns with callouts enabled should be shown, and any other hidden'
        );
    }

    private static String toOutcome(ncMcp_Credential credential) {
        if (credential == null) {
            return HIDDEN;
        }
        return String.join(
            new List<String>{ credential.getName(), credential.getLabel(), credential.getDescription() },
            ' | '
        );
    }
}