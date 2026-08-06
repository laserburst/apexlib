@IsTest
private class CalloutMethodGuardrail_Test {
    private static GuardedCalloutBuilder buildGuarded(String method, List<String> allowedMethods) {
        GuardedCalloutConfig config = new GuardedCalloutConfig();
        config.namedCredential = 'GuardedTest_Full';
        config.allowedMethods = allowedMethods;

        GuardedCalloutBuilder guarded = new GuardedCalloutBuilder('GuardedTest_Full');
        guarded.withEndpoint('/v1/x').withMethod(method);
        guarded.config = config;
        return guarded;
    }

    @IsTest
    static void allowsListedMethod() {
        GuardedCalloutBuilder guarded = buildGuarded('GET', new List<String>{ 'GET', 'POST' });
        new CalloutMethodGuardrail().enforce(guarded);
        // no exception = pass
    }

    @IsTest
    static void blocksUnlistedMethod() {
        GuardedCalloutBuilder guarded = buildGuarded('DELETE', new List<String>{ 'GET', 'POST' });
        try {
            new CalloutMethodGuardrail().enforce(guarded);
            Assert.fail('Expected block');
        } catch (CalloutGuardrailException e) {
            Assert.isTrue(e.getMessage().contains('is not allowed'), 'Unexpected: ' + e.getMessage());
            Assert.isTrue(e.getMessage().contains('GET, POST'), 'Should list allowed methods');
        }
    }
}
