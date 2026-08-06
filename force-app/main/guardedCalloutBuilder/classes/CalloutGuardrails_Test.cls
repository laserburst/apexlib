@IsTest
private class CalloutGuardrails_Test {
    private static GuardedCalloutBuilder buildGuarded(
        String method,
        String path,
        List<String> allowedMethods,
        List<String> patterns
    ) {
        GuardedCalloutConfig config = new GuardedCalloutConfig();
        config.namedCredential = 'GuardedTest_Full';
        config.allowedMethods = allowedMethods;
        config.allowedEndpointPatterns = patterns;
        config.guardrails = new List<String>();

        GuardedCalloutBuilder guarded = new GuardedCalloutBuilder('GuardedTest_Full');
        guarded.withEndpoint(path).withMethod(method);
        guarded.config = config;
        return guarded;
    }

    // --- Method guardrail ---

    @IsTest
    static void methodGuardrailAllowsListedMethod() {
        GuardedCalloutBuilder guarded =
            buildGuarded('GET', '/v1/x', new List<String>{ 'GET', 'POST' }, new List<String>{ '*' });
        new CalloutMethodGuardrail().enforce(guarded);
        // no exception = pass
    }

    @IsTest
    static void methodGuardrailBlocksUnlistedMethod() {
        GuardedCalloutBuilder guarded =
            buildGuarded('DELETE', '/v1/x', new List<String>{ 'GET', 'POST' }, new List<String>{ '*' });
        try {
            new CalloutMethodGuardrail().enforce(guarded);
            Assert.fail('Expected block');
        } catch (CalloutGuardrailException e) {
            Assert.isTrue(e.getMessage().contains('is not allowed'), 'Unexpected: ' + e.getMessage());
            Assert.isTrue(e.getMessage().contains('GET, POST'), 'Should list allowed methods');
        }
    }

    // --- Endpoint guardrail ---

    @IsTest
    static void endpointGuardrailWildcardMatrix() {
        assertPath('/v1/*', '/v1/models', true);
        assertPath('/v1/*', '/v1/models/gpt/completions', true); // * crosses '/'
        assertPath('/v1/*', '/v2/models', false);
        assertPath('*', '/anything/at/all', true);
        assertPath('/exact', '/exact', true);
        assertPath('/exact', '/exact/more', false);
        assertPath('/files/*.pdf', '/files/report.pdf', true);
        assertPath('/files/*.pdf', '/files/report.txt', false);
        // regex metacharacters in the pattern are treated literally
        assertPath('/a.b', '/a.b', true);
        assertPath('/a.b', '/axb', false);
    }

    @IsTest
    static void endpointGuardrailBlocksDotSegments() {
        // ".." would escape the allowed URL space once the server resolves it
        assertPath('/v1/*', '/v1/../admin/users', false);
        assertPath('/v1/*', '/v1/%2e%2e/admin/users', false); // URL-encoded form
        assertPath('*', '/v1/../admin/users', false); // even when any path is allowed
        assertPath('/v1/*', '/v1/a..b', true); // ".." inside a segment is not a traversal
    }

    private static void assertPath(String pattern, String path, Boolean expectedAllowed) {
        GuardedCalloutBuilder guarded =
            buildGuarded('GET', path, new List<String>{ 'GET' }, new List<String>{ pattern });
        Boolean allowed = true;
        try {
            new CalloutEndpointGuardrail().enforce(guarded);
        } catch (CalloutGuardrailException e) {
            allowed = false;
        }
        Assert.areEqual(expectedAllowed, allowed, 'Pattern "' + pattern + '" vs path "' + path + '"');
    }

    @IsTest
    static void endpointGuardrailIgnoresQueryString() {
        GuardedCalloutBuilder guarded =
            buildGuarded('GET', '/v1/models?limit=10', new List<String>{ 'GET' }, new List<String>{ '/v1/models' });
        new CalloutEndpointGuardrail().enforce(guarded);
        // no exception = pass; query string is excluded from matching
    }

    @IsTest
    static void endpointGuardrailBlockMessage() {
        GuardedCalloutBuilder guarded =
            buildGuarded('GET', '/admin/users', new List<String>{ 'GET' }, new List<String>{ '/v1/*' });
        try {
            new CalloutEndpointGuardrail().enforce(guarded);
            Assert.fail('Expected block');
        } catch (CalloutGuardrailException e) {
            Assert.isTrue(e.getMessage().contains('does not match'), 'Unexpected: ' + e.getMessage());
        }
    }

    // --- Authentication guardrail ---

    @IsTest
    static void authGuardrailPassesWhenConfigured() {
        CalloutAuthenticationGuardrail.stubAuthenticated('GuardedTest_Full', null, null);

        GuardedCalloutBuilder guarded =
            buildGuarded('GET', '/v1/x', new List<String>{ 'GET' }, new List<String>{ '*' });
        new CalloutAuthenticationGuardrail().enforce(guarded);
        // no exception = pass
    }

    @IsTest
    static void authGuardrailBlocksWhenNotConfigured() {
        GuardedCalloutBuilder guarded =
            buildGuarded('GET', '/v1/x', new List<String>{ 'GET' }, new List<String>{ '*' });
        try {
            new CalloutAuthenticationGuardrail().enforce(guarded);
            Assert.fail('Expected block');
        } catch (CalloutGuardrailException e) {
            Assert.isTrue(e.getMessage().contains('not authenticated'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void authStatusDefaultsToUnauthenticated() {
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

    // --- GuardrailsFactory ---

    private static GuardedCalloutConfig configNaming(List<String> customGuardrails) {
        GuardedCalloutConfig config = new GuardedCalloutConfig();
        config.namedCredential = 'GuardedTest_Full';
        config.guardrails = customGuardrails;
        return config;
    }

    @IsTest
    static void factoryCreatesBuiltInsThenCustom() {
        List<CalloutGuardrail> guardrails =
            GuardrailsFactory.create(configNaming(new List<String>{ 'CalloutTestGuardrail' }));

        Assert.areEqual(4, guardrails.size(), 'Three built-ins plus one custom');
        Assert.isInstanceOfType(guardrails[0], CalloutAuthenticationGuardrail.class, 'Authentication runs first');
        Assert.isInstanceOfType(guardrails[1], CalloutMethodGuardrail.class, 'Method runs second');
        Assert.isInstanceOfType(guardrails[2], CalloutEndpointGuardrail.class, 'Endpoint runs third');
        Assert.isInstanceOfType(guardrails[3], CalloutTestGuardrail.class, 'Custom guardrail should run last');
    }

    @IsTest
    static void factoryThrowsForUnknownClass() {
        try {
            GuardrailsFactory.create(configNaming(new List<String>{ 'ThisClassDoesNotExist_12345' }));
            Assert.fail('Expected exception');
        } catch (GuardrailsFactory.GuardrailsFactoryException e) {
            Assert.isTrue(e.getMessage().contains('was not found'), 'Unexpected: ' + e.getMessage());
            Assert.isTrue(e.getMessage().contains('GuardedTest_Full'), 'Should name the credential to fix');
        }
    }

    @IsTest
    static void factoryThrowsForWrongType() {
        try {
            GuardrailsFactory.create(configNaming(new List<String>{ 'GuardedCalloutConfig' })); // not a guardrail
            Assert.fail('Expected exception');
        } catch (GuardrailsFactory.GuardrailsFactoryException e) {
            Assert.isTrue(e.getMessage().contains('must implement CalloutGuardrail'), 'Unexpected: ' + e.getMessage());
        }
    }
}