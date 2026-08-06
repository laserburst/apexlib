@IsTest
private class GuardrailsFactory_Test {
    private static GuardedCalloutConfig configNaming(List<String> customGuardrails) {
        GuardedCalloutConfig config = new GuardedCalloutConfig();
        config.namedCredential = 'GuardedTest_Full';
        config.guardrails = customGuardrails;
        return config;
    }

    @IsTest
    static void createsBuiltInsThenCustom() {
        List<CalloutGuardrail> guardrails =
            GuardrailsFactory.create(configNaming(new List<String>{ 'CalloutTestGuardrail' }));

        Assert.areEqual(4, guardrails.size(), 'Three built-ins plus one custom');
        Assert.isInstanceOfType(guardrails[0], CalloutAuthenticationGuardrail.class, 'Authentication runs first');
        Assert.isInstanceOfType(guardrails[1], CalloutMethodGuardrail.class, 'Method runs second');
        Assert.isInstanceOfType(guardrails[2], CalloutEndpointGuardrail.class, 'Endpoint runs third');
        Assert.isInstanceOfType(guardrails[3], CalloutTestGuardrail.class, 'Custom guardrail should run last');
    }

    @IsTest
    static void throwsForUnknownClass() {
        try {
            GuardrailsFactory.create(configNaming(new List<String>{ 'ThisClassDoesNotExist_12345' }));
            Assert.fail('Expected exception');
        } catch (GuardrailsFactory.GuardrailsFactoryException e) {
            Assert.isTrue(e.getMessage().contains('was not found'), 'Unexpected: ' + e.getMessage());
            Assert.isTrue(e.getMessage().contains('GuardedTest_Full'), 'Should name the credential to fix');
        }
    }

    @IsTest
    static void throwsForWrongType() {
        try {
            GuardrailsFactory.create(configNaming(new List<String>{ 'GuardedCalloutConfig' })); // not a guardrail
            Assert.fail('Expected exception');
        } catch (GuardrailsFactory.GuardrailsFactoryException e) {
            Assert.isTrue(e.getMessage().contains('must implement CalloutGuardrail'), 'Unexpected: ' + e.getMessage());
        }
    }
}
