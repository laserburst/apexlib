@IsTest
private class ncMcp_PolicyCatalog_Test {
    @TestSetup
    static void makeUsers() {
        ncMcp_TestFactory.insertUsers();
    }

    @IsTest
    static void testCredentialNames() {
        List<CalloutPolicy> policies =
            new List<CalloutPolicy>{
                new CalloutPolicy('callout:Orders').withMethod('GET'),
                new CalloutPolicy('callout:Items/').withMethod('GET').withEndpoint('/items/*'),
                new CalloutPolicy('callout:Items').withMethod('PATCH').withEndpoint('/items/{id}'),
                new CalloutPolicy('callout:RulesOnly').withAllowedHeaders(new Set<String>{ 'Accept' }),
                new CalloutPolicy('https://example.com').withMethod('GET')
            };

        Test.startTest();
        List<String> names = new ncMcp_PolicyCatalog(policies).getCredentialNames();
        Test.stopTest();

        Assert.areEqual(
            new List<String>{ 'Items', 'Orders' },
            names,
            'Only Named Credentials with an allowing policy should be exposed, once each and sorted'
        );
    }

    @IsTest
    static void testRoutes() {
        List<CalloutPolicy> policies =
            new List<CalloutPolicy>{
                new CalloutPolicy('callout:Items').withMethod('PATCH').withEndpoint('/items/{id}'),
                new CalloutPolicy('callout:Items').withMethod('GET').withEndpoint('/items/{id}'),
                new CalloutPolicy('callout:Items')
                    .withMethods(new Set<String>{ 'GET', 'POST' })
                    .withEndpoint('/items/*'),
                new CalloutPolicy('callout:Items').withMethod('HEAD'),
                new CalloutPolicy('callout:Items')
                    .withEndpoint('/items/{id}/*')
                    .withAllowedHeaders(new Set<String>{ 'A' }),
                new CalloutPolicy('callout:Orders').withMethod('DELETE').withEndpoint('/orders/{id}')
            };

        Test.startTest();
        Map<String, Set<String>> methodsByEndpoint = new ncMcp_PolicyCatalog(policies).getMethodsByEndpoint('Items');
        Test.stopTest();

        Assert.areEqual(
            new Map<String, Set<String>>{
                '/*' => new Set<String>{ 'HEAD' },
                '/items/*' => new Set<String>{ 'GET', 'POST' },
                '/items/{id}' => new Set<String>{ 'GET', 'PATCH' }
            },
            methodsByEndpoint,
            'Methods should be merged by endpoint, with rule-only and other credentials\' policies left out'
        );
    }

    @IsTest
    static void testScopeWithPath() {
        List<CalloutPolicy> policies =
            new List<CalloutPolicy>{
                new CalloutPolicy('callout:Items').withMethod('GET'),
                new CalloutPolicy('callout:Items/v2').withAllowedHeaders(new Set<String>{ 'Accept' })
            };

        Test.startTest();
        String error;
        try {
            new ncMcp_PolicyCatalog(policies);
        } catch (ncMcp_ToolException e) {
            error = e.getMessage();
        }
        Test.stopTest();

        Assert.areEqual(
            'Policy scope callout:Items/v2 has a path; use callout:<name> and endpoints',
            error,
            'A scope the tools never call would skip its checks, so it should fail closed'
        );
    }

    @IsTest
    static void testGetInstanceNeedsPermission() {
        Map<String, User> userByCase =
            new Map<String, User>{
                'with the permission set' => ncMcp_TestFactory.getUser(ncMcp_TestFactory.MCP_USER),
                'without it' => ncMcp_TestFactory.getUser(ncMcp_TestFactory.PLAIN_USER)
            };
        Map<String, String> expectedByCase =
            new Map<String, String>{
                'with the permission set' => 'catalog',
                'without it' => 'Named Credentials MCP is not enabled for this user'
            };

        Test.startTest();
        Map<String, String> outcomeByCase = new Map<String, String>();
        for (String testCase : userByCase.keySet()) {
            System.runAs(userByCase.get(testCase)) {
                try {
                    ncMcp_PolicyCatalog.getInstance();
                    outcomeByCase.put(testCase, 'catalog');
                } catch (ncMcp_ToolException e) {
                    outcomeByCase.put(testCase, e.getMessage());
                }
            }
        }
        Test.stopTest();

        Assert.areEqual(
            expectedByCase,
            outcomeByCase,
            'Only a user with the custom permission should get a catalog; it loads the org\'s own policy classes, '
            + 'so one that fails to load fails this test'
        );
    }
}