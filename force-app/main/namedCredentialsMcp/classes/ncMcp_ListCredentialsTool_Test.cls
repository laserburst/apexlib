@IsTest
private class ncMcp_ListCredentialsTool_Test {
    @IsTest
    static void listsUnauthenticatedCredentialsToo() {
        CalloutAuthenticationGuardrail.stubAuthenticated('GuardedTest_Full', 'https://example.com', 'PerUserPrincipal');
        // GuardedTest_Defaults and GuardedTest_Guarded are intentionally left unauthenticated

        Test.startTest();
            List<ncMcp_ListCredentialsResult> results = ncMcp_ListCredentialsTool.listCredentials();
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'The tool returns a single result');
        List<Object> credentials = (List<Object>) JSON.deserializeUntyped(results[0].credentials);

        // The three active, well-formed test configs, sorted by name; the
        // inactive and malformed ones are excluded by GuardedCalloutConfig.getActive()
        Assert.areEqual(3, credentials.size(), 'All active configs should be listed regardless of authentication');

        Map<String, Object> defaults = (Map<String, Object>) credentials[0];
        Assert.areEqual('GuardedTest_Defaults', defaults.get('name'), 'Entries should be sorted by name');
        Assert.areEqual(false, defaults.get('isConfigured'), 'Unauthenticated credential should show isConfigured=false');
        Assert.isNull(defaults.get('baseUrl'), 'Unknown base URL should be null');
        Assert.isNull(defaults.get('principalType'), 'Unknown principal type should be null');

        Map<String, Object> full = (Map<String, Object>) credentials[1];
        Assert.areEqual('GuardedTest_Full', full.get('name'), 'Entries should be sorted by name');
        Assert.areEqual(true, full.get('isConfigured'), 'Authenticated credential should show isConfigured=true');
        Assert.areEqual('https://example.com', full.get('baseUrl'), 'Unexpected base URL');
        Assert.areEqual('PerUserPrincipal', full.get('principalType'), 'Unexpected principal type');

        Assert.areEqual('GuardedTest_Guarded', ((Map<String, Object>) credentials[2]).get('name'), 'Entries should be sorted by name');
    }

    @IsTest
    static void resultDtoIsConstructible() {
        ncMcp_ListCredentialsResult result = new ncMcp_ListCredentialsResult();
        result.credentials = '[]';
        Assert.areEqual('[]', result.credentials, 'No-arg constructor should be usable');

        ncMcp_ListCredentialsResult.Credential credential = new ncMcp_ListCredentialsResult.Credential();
        credential.name = 'x';
        credential.isConfigured = true;
        credential.baseUrl = 'https://base';
        credential.principalType = 'NamedPrincipal';
        Assert.areEqual('x', credential.name, 'Credential DTO fields should be settable');
    }
}