@IsTest
private class CalloutEndpointGuardrail_Test {
    private static GuardedCalloutBuilder buildGuarded(String path, String pattern) {
        GuardedCalloutConfig config = new GuardedCalloutConfig();
        config.namedCredential = 'GuardedTest_Full';
        config.allowedEndpointPatterns = new List<String>{ pattern };

        GuardedCalloutBuilder guarded = new GuardedCalloutBuilder('GuardedTest_Full');
        guarded.withEndpoint(path).withMethod('GET');
        guarded.config = config;
        return guarded;
    }

    private static void assertPath(String pattern, String path, Boolean expectedAllowed) {
        Boolean allowed = true;
        try {
            new CalloutEndpointGuardrail().enforce(buildGuarded(path, pattern));
        } catch (CalloutGuardrailException e) {
            allowed = false;
        }
        Assert.areEqual(expectedAllowed, allowed, 'Pattern "' + pattern + '" vs path "' + path + '"');
    }

    @IsTest
    static void wildcardMatrix() {
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
    static void blocksDotSegments() {
        // ".." would escape the allowed URL space once the server resolves it
        assertPath('/v1/*', '/v1/../admin/users', false);
        assertPath('/v1/*', '/v1/%2e%2e/admin/users', false); // URL-encoded form
        assertPath('*', '/v1/../admin/users', false); // even when any path is allowed
        assertPath('/v1/*', '/v1/a..b', true); // ".." inside a segment is not a traversal
    }

    @IsTest
    static void ignoresQueryString() {
        GuardedCalloutBuilder guarded = buildGuarded('/v1/models?limit=10', '/v1/models');
        new CalloutEndpointGuardrail().enforce(guarded);
        // no exception = pass; query string is excluded from matching
    }

    @IsTest
    static void blockMessageExplainsMismatch() {
        GuardedCalloutBuilder guarded = buildGuarded('/admin/users', '/v1/*');
        try {
            new CalloutEndpointGuardrail().enforce(guarded);
            Assert.fail('Expected block');
        } catch (CalloutGuardrailException e) {
            Assert.isTrue(e.getMessage().contains('does not match'), 'Unexpected: ' + e.getMessage());
        }
    }
}
