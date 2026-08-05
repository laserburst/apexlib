@IsTest
private class ncMcp_DescribeTool_Test {
    private static void authenticate(String namedCredential, String baseUrl) {
        CalloutAuthenticationGuardrail.stubAuthenticated(namedCredential, baseUrl, null);
    }

    private static List<ncMcp_DescribeResult> describe(String namedCredential) {
        ncMcp_DescribeTool.Request request = new ncMcp_DescribeTool.Request();
        request.namedCredential = namedCredential;
        return ncMcp_DescribeTool.describe(new List<ncMcp_DescribeTool.Request>{ request });
    }

    @IsTest
    static void describeReturnsSingleApiAsJsonObject() {
        authenticate('GuardedTest_Full', 'https://example.com');

        Test.startTest();
        List<ncMcp_DescribeResult> results = describe('GuardedTest_Full');
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'One result per input request');
        Map<String, Object> api = (Map<String, Object>) JSON.deserializeUntyped(results[0].api);
        Assert.areEqual('GuardedTest_Full', api.get('name'), 'Unexpected API name');
        Assert.areEqual('https://example.com', api.get('baseUrl'), 'Unexpected base URL');
        Assert.areEqual(
            new List<Object>{ 'GET', 'POST' },
            (List<Object>) api.get('allowedMethods'),
            'Unexpected methods'
        );
        Assert.isNotNull(api.get('allowedEndpointPatterns'), 'Endpoint patterns should be included');
    }

    @IsTest
    static void describeThrowsWhenNotAuthenticated() {
        // no authenticate() call -> the credential exists but is not usable
        try {
            describe('GuardedTest_Full');
            Assert.fail('Expected GuardedCalloutException');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('not authenticated'), 'Unexpected: ' + e.getMessage());
            Assert.isTrue(
                e.getMessage().contains('listCredentials'),
                'Should point the agent to the listCredentials tool'
            );
        }
    }

    @IsTest
    static void describeThrowsWhenNoActiveConfig() {
        try {
            describe('GuardedTest_Inactive');
            Assert.fail('Expected GuardedCalloutException');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('No active configuration found'), 'Unexpected: ' + e.getMessage());
            Assert.isTrue(
                e.getMessage().contains('listCredentials'),
                'Should point the agent to the listCredentials tool'
            );
        }
    }

    @IsTest
    static void describeThrowsWhenNameIsBlank() {
        try {
            describe(null);
            Assert.fail('Expected GuardedCalloutException');
        } catch (GuardedCalloutException e) {
            Assert.isTrue(e.getMessage().contains('"namedCredential" is required'), 'Unexpected: ' + e.getMessage());
        }
    }

    @IsTest
    static void resultDtoIsConstructible() {
        ncMcp_DescribeResult result = new ncMcp_DescribeResult();
        result.api = '{}';
        Assert.areEqual('{}', result.api, 'No-arg constructor should be usable');

        ncMcp_DescribeResult.Api api = new ncMcp_DescribeResult.Api();
        api.name = 'x';
        api.description = 'desc';
        api.apiDocsUrl = 'https://docs';
        api.baseUrl = 'https://base';
        api.allowedMethods = new List<String>{ 'GET' };
        api.allowedEndpointPatterns = new List<String>{ '*' };
        Assert.areEqual('x', api.name, 'Api DTO fields should be settable');
    }
}