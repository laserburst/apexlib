@IsTest
private class CalloutAuthenticationGuardrail_Test {
    private static GuardedCalloutBuilder buildGuarded() {
        GuardedCalloutConfig config = new GuardedCalloutConfig();
        config.namedCredential = 'GuardedTest_Full';

        GuardedCalloutBuilder guarded = new GuardedCalloutBuilder('GuardedTest_Full');
        guarded.withEndpoint('/v1/x').withMethod('GET');
        guarded.config = config;
        return guarded;
    }

    @IsTest
    static void passesWhenConfigured() {
        CalloutAuthenticationGuardrail.stubAuthenticated('GuardedTest_Full', null, null);

        new CalloutAuthenticationGuardrail().enforce(buildGuarded());
        // no exception = pass
    }

    @IsTest
    static void blocksWhenNotConfigured() {
        try {
            new CalloutAuthenticationGuardrail().enforce(buildGuarded());
            Assert.fail('Expected block');
        } catch (CalloutGuardrailException e) {
            Assert.isTrue(e.getMessage().contains('not authenticated'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void statusDefaultsToUnauthenticated() {
        CalloutAuthenticationGuardrail.Status status = CalloutAuthenticationGuardrail.getStatus('unknown_nc');
        Assert.isFalse(status.isAuthenticated, 'Unknown NC should be unauthenticated by default');
    }

    @IsTest
    static void evaluateHandlesNullNamedCredential() {
        // ConnectApi returned null (missing/untestable NC) -> unauthenticated
        Assert.isFalse(
            CalloutAuthenticationGuardrail.evaluate(null).isAuthenticated,
            'Null NC should be unauthenticated'
        );
    }

    @IsTest
    static void evaluateCapturesBaseUrlAndScansExternalCredentials() {
        ConnectApi.NamedCredential nc = new ConnectApi.NamedCredential();
        nc.calloutUrl = 'https://x.example.com';
        ConnectApi.ExternalCredential ec = new ConnectApi.ExternalCredential();
        ec.developerName = 'ec1';
        nc.externalCredentials = new List<ConnectApi.ExternalCredential>{ ec };

        // ConnectApiAdapter.getExternalCredential returns null in test, so no principal is configured
        CalloutAuthenticationGuardrail.Status status = CalloutAuthenticationGuardrail.evaluate(nc);
        Assert.areEqual(
            'https://x.example.com',
            status.baseUrl,
            'Base URL should be captured from the Named Credential'
        );
        Assert.isFalse(status.isAuthenticated, 'No configured principal is reachable in test context');
        Assert.isNull(status.principalType, 'No principal details are reachable in test context');
    }

    @IsTest
    static void evaluateHandlesNamedCredentialWithoutExternalCredentials() {
        ConnectApi.NamedCredential nc = new ConnectApi.NamedCredential();
        nc.calloutUrl = 'https://y.example.com';
        // externalCredentials left null
        Assert.isFalse(
            CalloutAuthenticationGuardrail.evaluate(nc).isAuthenticated,
            'No external credentials -> unauthenticated'
        );
    }

    @IsTest
    static void configuredPrincipalDetectsConfiguredStatus() {
        ConnectApi.ExternalCredentialPrincipal configured = new ConnectApi.ExternalCredentialPrincipal();
        configured.authenticationStatus = ConnectApi.CredentialAuthenticationStatus.Configured;
        configured.principalType = ConnectApi.CredentialPrincipalType.NamedPrincipal;

        ConnectApi.ExternalCredentialPrincipal notConfigured = new ConnectApi.ExternalCredentialPrincipal();
        notConfigured.authenticationStatus = ConnectApi.CredentialAuthenticationStatus.NotConfigured;

        ConnectApi.ExternalCredential ec = new ConnectApi.ExternalCredential();
        ec.principals = new List<ConnectApi.ExternalCredentialPrincipal>{ notConfigured, configured };

        ConnectApi.ExternalCredentialPrincipal found = CalloutAuthenticationGuardrail.configuredPrincipal(ec);
        Assert.isNotNull(found, 'Should find the configured principal');
        Assert.areEqual(
            ConnectApi.CredentialAuthenticationStatus.Configured,
            found.authenticationStatus,
            'Should return the configured principal'
        );
    }

    @IsTest
    static void configuredPrincipalReturnsNullWhenNoneConfigured() {
        Assert.isNull(CalloutAuthenticationGuardrail.configuredPrincipal(null), 'Null external credential -> null');

        ConnectApi.ExternalCredential ec = new ConnectApi.ExternalCredential();
        // principals left null
        Assert.isNull(CalloutAuthenticationGuardrail.configuredPrincipal(ec), 'No principals -> null');
    }

    @IsTest
    static void firstPrincipalTypeReturnsTypeOfFirstPrincipal() {
        ConnectApi.ExternalCredentialPrincipal principal = new ConnectApi.ExternalCredentialPrincipal();
        principal.authenticationStatus = ConnectApi.CredentialAuthenticationStatus.NotConfigured;
        principal.principalType = ConnectApi.CredentialPrincipalType.PerUserPrincipal;

        ConnectApi.ExternalCredential ec = new ConnectApi.ExternalCredential();
        ec.principals = new List<ConnectApi.ExternalCredentialPrincipal>{ principal };

        Assert.areEqual(
            'PerUserPrincipal',
            CalloutAuthenticationGuardrail.firstPrincipalType(ec),
            'An unconfigured principal should still report its type'
        );
    }

    @IsTest
    static void firstPrincipalTypeHandlesMissingData() {
        Assert.isNull(CalloutAuthenticationGuardrail.firstPrincipalType(null), 'Null external credential -> null');

        ConnectApi.ExternalCredential ec = new ConnectApi.ExternalCredential();
        Assert.isNull(CalloutAuthenticationGuardrail.firstPrincipalType(ec), 'No principals -> null');

        ec.principals = new List<ConnectApi.ExternalCredentialPrincipal>();
        Assert.isNull(CalloutAuthenticationGuardrail.firstPrincipalType(ec), 'Empty principals -> null');

        ec.principals =
            new List<ConnectApi.ExternalCredentialPrincipal>{ new ConnectApi.ExternalCredentialPrincipal() };
        Assert.isNull(CalloutAuthenticationGuardrail.firstPrincipalType(ec), 'Principal without a type -> null');
    }
}
