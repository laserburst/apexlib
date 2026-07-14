@IsTest
private class GuardedCalloutConfig_Test {
    @IsTest
    static void getActiveReturnsOnlyActiveTestRecords() {
        Test.startTest();
        Map<String, GuardedCalloutConfig> configs = GuardedCalloutConfig.getActive();
        Test.stopTest();

        Assert.isTrue(configs.containsKey('GuardedTest_Full'), 'Full config should be present');
        Assert.isTrue(configs.containsKey('GuardedTest_Defaults'), 'Defaults config should be present');
        Assert.isTrue(configs.containsKey('GuardedTest_Guarded'), 'Guarded config should be present');
        Assert.isFalse(configs.containsKey('GuardedTest_Inactive'), 'Inactive config should be excluded');
        Assert.isFalse(configs.containsKey('GuardedTest_BadJson'), 'Malformed config should be skipped, not fatal');
    }

    @IsTest
    static void forNameParsesFullConfig() {
        GuardedCalloutConfig config = GuardedCalloutConfig.forName('GuardedTest_Full');

        Assert.areEqual('Full test API', config.description, 'Unexpected description');
        Assert.areEqual('https://example.com/docs', config.apiDocsUrl, 'Unexpected docs url');
        Assert.areEqual(new List<String>{ 'GET', 'POST' }, config.allowedMethods, 'Unexpected methods');
        Assert.areEqual(new List<String>{ '/v1/*' }, config.allowedEndpointPatterns, 'Unexpected patterns');
        Assert.areEqual(
            'GuardedTest_Full',
            config.namedCredential,
            'Named credential should come from the record field'
        );
    }

    @IsTest
    static void forNameAppliesDefaults() {
        GuardedCalloutConfig config = GuardedCalloutConfig.forName('GuardedTest_Defaults');

        Assert.areEqual(new List<String>{ 'GET' }, config.allowedMethods, 'Should default to GET only');
        Assert.areEqual(new List<String>{ '*' }, config.allowedEndpointPatterns, 'Should default to any path');
        Assert.isTrue(config.guardrails.isEmpty(), 'Should default to no custom guardrails');
    }

    @IsTest
    static void forNameThrowsWhenMissing() {
        try {
            GuardedCalloutConfig.forName('does_not_exist');
            Assert.fail('Expected exception');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(
                e.getMessage().contains('No active configuration found'),
                'Unexpected message: ' + e.getMessage()
            );
        }
    }

    @IsTest
    static void forNameThrowsForInactive() {
        try {
            GuardedCalloutConfig.forName('GuardedTest_Inactive');
            Assert.fail('Expected exception for inactive config');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(
                e.getMessage().contains('No active configuration found'),
                'Unexpected message: ' + e.getMessage()
            );
        }
    }

    @IsTest
    static void forNameThrowsForBadJson() {
        try {
            GuardedCalloutConfig.forName('GuardedTest_BadJson');
            Assert.fail('Expected exception for malformed JSON');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('not valid JSON'), 'Unexpected message: ' + e.getMessage());
        }
    }
}