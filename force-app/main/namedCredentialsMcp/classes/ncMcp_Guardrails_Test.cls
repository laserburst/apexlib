@IsTest
private class ncMcp_Guardrails_Test {
    private static ncMcp_GuardedCalloutBuilder buildGuarded(
        String method,
        String path,
        List<String> allowedMethods,
        List<String> patterns
    ) {
        ncMcp_Config config = new ncMcp_Config();
        config.namedCredential = 'ncMcpTest_Full';
        config.allowedMethods = allowedMethods;
        config.allowedEndpointPatterns = patterns;
        config.guardrails = new List<String>();

        ncMcp_GuardedCalloutBuilder guarded = new ncMcp_GuardedCalloutBuilder('ncMcpTest_Full')
            .withEndpoint(path)
            .withMethod(method);
        guarded.config = config;
        return guarded;
    }

    // --- Method guardrail ---

    @IsTest
    static void methodGuardrailAllowsListedMethod() {
        ncMcp_GuardedCalloutBuilder guarded = buildGuarded('GET', '/v1/x', new List<String>{ 'GET', 'POST' }, new List<String>{ '*' });
        new ncMcp_MethodGuardrail().enforce(guarded);
        // no exception = pass
    }

    @IsTest
    static void methodGuardrailBlocksUnlistedMethod() {
        ncMcp_GuardedCalloutBuilder guarded = buildGuarded('DELETE', '/v1/x', new List<String>{ 'GET', 'POST' }, new List<String>{ '*' });
        try {
            new ncMcp_MethodGuardrail().enforce(guarded);
            Assert.fail('Expected block');
        } catch (ncMcp_Exception e) {
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
        ncMcp_GuardedCalloutBuilder guarded = buildGuarded('GET', path, new List<String>{ 'GET' }, new List<String>{ pattern });
        Boolean allowed = true;
        try {
            new ncMcp_EndpointGuardrail().enforce(guarded);
        } catch (ncMcp_Exception e) {
            allowed = false;
        }
        Assert.areEqual(expectedAllowed, allowed, 'Pattern "' + pattern + '" vs path "' + path + '"');
    }

    @IsTest
    static void endpointGuardrailIgnoresQueryString() {
        ncMcp_GuardedCalloutBuilder guarded = buildGuarded(
            'GET',
            '/v1/models?limit=10',
            new List<String>{ 'GET' },
            new List<String>{ '/v1/models' }
        );
        new ncMcp_EndpointGuardrail().enforce(guarded);
        // no exception = pass; query string is excluded from matching
    }

    @IsTest
    static void endpointGuardrailBlockMessage() {
        ncMcp_GuardedCalloutBuilder guarded = buildGuarded('GET', '/admin/users', new List<String>{ 'GET' }, new List<String>{ '/v1/*' });
        try {
            new ncMcp_EndpointGuardrail().enforce(guarded);
            Assert.fail('Expected block');
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('does not match'), 'Unexpected: ' + e.getMessage());
        }
    }

    // --- Authentication guardrail ---

    @IsTest
    static void authGuardrailPassesWhenConfigured() {
        ncMcp_AuthenticationGuardrail.stubAuthenticated('ncMcpTest_Full', null, null);

        ncMcp_GuardedCalloutBuilder guarded = buildGuarded('GET', '/v1/x', new List<String>{ 'GET' }, new List<String>{ '*' });
        new ncMcp_AuthenticationGuardrail().enforce(guarded);
        // no exception = pass
    }

    @IsTest
    static void authGuardrailBlocksWhenNotConfigured() {
        ncMcp_GuardedCalloutBuilder guarded = buildGuarded('GET', '/v1/x', new List<String>{ 'GET' }, new List<String>{ '*' });
        try {
            new ncMcp_AuthenticationGuardrail().enforce(guarded);
            Assert.fail('Expected block');
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('not authenticated'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void authStatusDefaultsToUnauthenticated() {
        ncMcp_AuthenticationGuardrail.Status status = ncMcp_AuthenticationGuardrail.getStatus('unknown_nc');
        Assert.isFalse(status.isAuthenticated, 'Unknown NC should be unauthenticated by default');
    }

    @IsTest
    static void evaluateHandlesNullNamedCredential() {
        // ConnectApi returned null (missing/untestable NC) -> unauthenticated
        Assert.isFalse(ncMcp_AuthenticationGuardrail.evaluate(null).isAuthenticated, 'Null NC should be unauthenticated');
    }

    @IsTest
    static void evaluateCapturesBaseUrlAndScansExternalCredentials() {
        ConnectApi.NamedCredential nc = new ConnectApi.NamedCredential();
        nc.calloutUrl = 'https://x.example.com';
        ConnectApi.ExternalCredential ec = new ConnectApi.ExternalCredential();
        ec.developerName = 'ec1';
        nc.externalCredentials = new List<ConnectApi.ExternalCredential>{ ec };

        // ConnectApiAdapter.getExternalCredential returns null in test, so no principal is configured
        ncMcp_AuthenticationGuardrail.Status status = ncMcp_AuthenticationGuardrail.evaluate(nc);
        Assert.areEqual('https://x.example.com', status.baseUrl, 'Base URL should be captured from the Named Credential');
        Assert.isFalse(status.isAuthenticated, 'No configured principal is reachable in test context');
        Assert.isNull(status.principalType, 'No principal details are reachable in test context');
    }

    @IsTest
    static void evaluateHandlesNamedCredentialWithoutExternalCredentials() {
        ConnectApi.NamedCredential nc = new ConnectApi.NamedCredential();
        nc.calloutUrl = 'https://y.example.com';
        // externalCredentials left null
        Assert.isFalse(ncMcp_AuthenticationGuardrail.evaluate(nc).isAuthenticated, 'No external credentials -> unauthenticated');
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

        ConnectApi.ExternalCredentialPrincipal found = ncMcp_AuthenticationGuardrail.configuredPrincipal(ec);
        Assert.isNotNull(found, 'Should find the configured principal');
        Assert.areEqual(
            ConnectApi.CredentialAuthenticationStatus.Configured,
            found.authenticationStatus,
            'Should return the configured principal'
        );
    }

    @IsTest
    static void configuredPrincipalReturnsNullWhenNoneConfigured() {
        Assert.isNull(ncMcp_AuthenticationGuardrail.configuredPrincipal(null), 'Null external credential -> null');

        ConnectApi.ExternalCredential ec = new ConnectApi.ExternalCredential();
        // principals left null
        Assert.isNull(ncMcp_AuthenticationGuardrail.configuredPrincipal(ec), 'No principals -> null');
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
            ncMcp_AuthenticationGuardrail.firstPrincipalType(ec),
            'An unconfigured principal should still report its type'
        );
    }

    @IsTest
    static void firstPrincipalTypeHandlesMissingData() {
        Assert.isNull(ncMcp_AuthenticationGuardrail.firstPrincipalType(null), 'Null external credential -> null');

        ConnectApi.ExternalCredential ec = new ConnectApi.ExternalCredential();
        Assert.isNull(ncMcp_AuthenticationGuardrail.firstPrincipalType(ec), 'No principals -> null');

        ec.principals = new List<ConnectApi.ExternalCredentialPrincipal>();
        Assert.isNull(ncMcp_AuthenticationGuardrail.firstPrincipalType(ec), 'Empty principals -> null');

        ec.principals = new List<ConnectApi.ExternalCredentialPrincipal>{ new ConnectApi.ExternalCredentialPrincipal() };
        Assert.isNull(ncMcp_AuthenticationGuardrail.firstPrincipalType(ec), 'Principal without a type -> null');
    }

    // --- Example (custom) guardrail ---

    @IsTest
    static void exampleGuardrailBlocksSensitiveBody() {
        ncMcp_GuardedCalloutBuilder guarded = buildGuarded('POST', '/v1/x', new List<String>{ 'POST' }, new List<String>{ '*' })
            .withBody('{"user":"a","password":"hunter2"}');
        try {
            new ncMcp_ExampleGuardrail().enforce(guarded);
            Assert.fail('Expected block');
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('credential'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void exampleGuardrailAllowsCleanAndBlankBody() {
        ncMcp_GuardedCalloutBuilder withCleanBody = buildGuarded('POST', '/v1/x', new List<String>{ 'POST' }, new List<String>{ '*' })
            .withBody('{"name":"widget"}');
        new ncMcp_ExampleGuardrail().enforce(withCleanBody);

        ncMcp_GuardedCalloutBuilder withoutBody = buildGuarded('POST', '/v1/x', new List<String>{ 'POST' }, new List<String>{ '*' });
        new ncMcp_ExampleGuardrail().enforce(withoutBody);
        // no exception = pass
    }

    // --- Guardrail chain resolution (decorator) ---

    @IsTest
    static void resolveGuardrailsIncludesBuiltInsThenCustom() {
        ncMcp_GuardedCalloutBuilder guarded = buildGuarded('GET', '/v1/x', new List<String>{ 'GET' }, new List<String>{ '*' });
        guarded.config.guardrails = new List<String>{ 'ncMcp_ExampleGuardrail' };

        List<ncMcp_Guardrail> guardrails = guarded.resolveGuardrails();

        Assert.areEqual(4, guardrails.size(), 'Three built-ins plus one custom');
        Assert.isInstanceOfType(guardrails[3], ncMcp_ExampleGuardrail.class, 'Custom guardrail should run last');
    }

    @IsTest
    static void resolveGuardrailsThrowsForUnknownClass() {
        ncMcp_GuardedCalloutBuilder guarded = buildGuarded('GET', '/v1/x', new List<String>{ 'GET' }, new List<String>{ '*' });
        guarded.config.guardrails = new List<String>{ 'ThisClassDoesNotExist_12345' };

        try {
            guarded.resolveGuardrails();
            Assert.fail('Expected exception');
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('was not found'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void resolveGuardrailsThrowsForWrongType() {
        ncMcp_GuardedCalloutBuilder guarded = buildGuarded('GET', '/v1/x', new List<String>{ 'GET' }, new List<String>{ '*' });
        guarded.config.guardrails = new List<String>{ 'ncMcp_Config' }; // a real class that is not a guardrail

        try {
            guarded.resolveGuardrails();
            Assert.fail('Expected exception');
        } catch (ncMcp_Exception e) {
            Assert.isTrue(e.getMessage().contains('must implement ncMcp_Guardrail'), 'Unexpected: ' + e.getMessage());
        }
    }
}
