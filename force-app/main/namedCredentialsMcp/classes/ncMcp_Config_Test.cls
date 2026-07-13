@IsTest
private class ncMcp_Config_Test {
    @IsTest
    static void getActiveReturnsOnlyActiveTestRecords() {
        Test.startTest();
            Map<String, ncMcp_Config> configs = ncMcp_Config.getActive();
        Test.stopTest();

        Assert.isTrue(configs.containsKey('ncMcpTest_Full'), 'Full config should be present');
        Assert.isTrue(configs.containsKey('ncMcpTest_Defaults'), 'Defaults config should be present');
        Assert.isTrue(configs.containsKey('ncMcpTest_Guarded'), 'Guarded config should be present');
        Assert.isFalse(configs.containsKey('ncMcpTest_Inactive'), 'Inactive config should be excluded');
        Assert.isFalse(configs.containsKey('ncMcpTest_BadJson'), 'Malformed config should be skipped, not fatal');
    }

    @IsTest
    static void forNameParsesFullConfig() {
        ncMcp_Config config = ncMcp_Config.forName('ncMcpTest_Full');

        Assert.areEqual('Full test API', config.description, 'Unexpected description');
        Assert.areEqual('https://example.com/docs', config.apiDocsUrl, 'Unexpected docs url');
        Assert.areEqual(new List<String>{ 'GET', 'POST' }, config.allowedMethods, 'Unexpected methods');
        Assert.areEqual(new List<String>{ '/v1/*' }, config.allowedEndpointPatterns, 'Unexpected patterns');
        Assert.areEqual('ncMcpTest_Full', config.namedCredential, 'Named credential should come from the record field');
    }

    @IsTest
    static void forNameAppliesDefaults() {
        ncMcp_Config config = ncMcp_Config.forName('ncMcpTest_Defaults');

        Assert.areEqual(new List<String>{ 'GET' }, config.allowedMethods, 'Should default to GET only');
        Assert.areEqual(new List<String>{ '*' }, config.allowedEndpointPatterns, 'Should default to any path');
        Assert.isTrue(config.guardrails.isEmpty(), 'Should default to no custom guardrails');
    }

    @IsTest
    static void forNameThrowsWhenMissing() {
        try {
            ncMcp_Config.forName('does_not_exist');
            Assert.fail('Expected exception');
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('No active configuration found'), 'Unexpected message: ' + e.getMessage());
        }
    }

    @IsTest
    static void forNameThrowsForInactive() {
        try {
            ncMcp_Config.forName('ncMcpTest_Inactive');
            Assert.fail('Expected exception for inactive config');
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('No active configuration found'), 'Unexpected message: ' + e.getMessage());
        }
    }

    @IsTest
    static void forNameThrowsForBadJson() {
        try {
            ncMcp_Config.forName('ncMcpTest_BadJson');
            Assert.fail('Expected exception for malformed JSON');
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('not valid JSON'), 'Unexpected message: ' + e.getMessage());
        }
    }
}
