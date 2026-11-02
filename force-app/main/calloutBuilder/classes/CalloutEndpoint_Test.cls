@IsTest
private class CalloutEndpoint_Test {
    @IsTest
    static void testTemplateGetsOneLeadingSlash() {
        Assert.areEqual(
            'callout:Test/test',
            joined('callout:Test', 'test'),
            'An endpoint must not extend the credential name'
        );
        Assert.areEqual('callout:Test/x', joined('callout:Test', '//x'), 'Leading slashes should collapse to one');
        Assert.areEqual(
            'callout:Test/v1?a=1',
            joined('callout:Test/v1', '?a=1'),
            'A query-only endpoint should get no slash'
        );
        Assert.areEqual('callout:Test', joined('callout:Test', null), 'A null endpoint should leave the base URL');
    }

    @IsTest
    static void testTemplateRejectsFragmentBackslashAndDotSegments() {
        for (String template : new List<String>{ '/a#b', '/a?q=1#b' }) {
            Assert.areEqual('Endpoint must not contain "#"', templateError(template), template);
        }
        Assert.areEqual('Endpoint path must not contain "\\"', templateError('/a\\b'), 'Backslash in the path');
        for (String template : new List<String>{ '/a/../b', '/a/./b', '/a/%2E%2e/b', '/..;/admin', '/a/..' }) {
            Assert.areEqual('Endpoint must not contain "." or ".." path segments', templateError(template), template);
        }
        for (String template : new List<String>{ '/a..b/...', '/a?range=..', '/a?p=c:\\x' }) {
            Assert.isNull(templateError(template), template + ' should be accepted');
        }
    }

    @IsTest
    static void testValueIsEncodedAsOneSegment() {
        Map<String, String> expectedByValue =
            new Map<String, String>{
                'a/b c?d#e%f' => '/items/a%2Fb%20c%3Fd%23e%25f',
                'a+b' => '/items/a%2Bb',
                'a!b~c' => '/items/a!b~c',
                '%21' => '/items/%2521',
                '...' => '/items/...'
            };
        for (String value : expectedByValue.keySet()) {
            CalloutEndpoint endpoint = new CalloutEndpoint();
            endpoint.setTemplate('/items/{id}');
            endpoint.putParameter('id', value);
            Assert.areEqual(expectedByValue.get(value), endpoint.resolve(), 'Unexpected endpoint for ' + value);
        }
    }

    @IsTest
    static void testParameterRejectsInvalidInput() {
        Assert.areEqual('Path parameter name must be provided', parameterError(null, 'x'), 'Missing name');
        Assert.areEqual(
            'Path parameter name must not contain "{", "}", "/" or "?"',
            parameterError('x?', 'v'),
            'A name must not reach outside its placeholder'
        );
        Assert.areEqual('Path parameter "id" must have a value', parameterError('id', '  '), 'Blank value');
        for (String value : new List<String>{ '.', '..' }) {
            Assert.areEqual('Path parameter "id" must not be "." or ".."', parameterError('id', value), value);
        }
    }

    @IsTest
    static void testParameterWithoutPlaceholderThrows() {
        CalloutEndpoint endpoint = new CalloutEndpoint();
        endpoint.setTemplate('/items');
        endpoint.putParameter('id', '5');
        String message;
        try {
            endpoint.resolve();
        } catch (CalloutBuilder.CalloutBuilderException e) {
            message = e.getMessage();
        }
        Assert.areEqual('Path parameter "id" has no {id} placeholder in the endpoint', message, 'Unused parameter');
    }

    @IsTest
    static void testParametersResolveInAnyOrder() {
        CalloutEndpoint endpoint = new CalloutEndpoint();
        endpoint.putParameter('a', '1');
        endpoint.putParameter('b', 'x/y');
        endpoint.setTemplate('/{a}/items/{a}/{b}');

        Assert.areEqual('/1/items/1/x%2Fy', endpoint.resolve(), 'Every placeholder should resolve');
        endpoint.getParameters().put('b', 'changed');
        Assert.areEqual('x/y', endpoint.getParameters().get('b'), 'getParameters should return a copy of raw values');
    }

    private static String joined(String baseUrl, String template) {
        CalloutEndpoint endpoint = new CalloutEndpoint();
        endpoint.setTemplate(template);
        return endpoint.joinTo(baseUrl);
    }

    private static String templateError(String template) {
        try {
            new CalloutEndpoint().setTemplate(template);
        } catch (CalloutBuilder.CalloutBuilderException e) {
            return e.getMessage();
        }
        return null;
    }

    private static String parameterError(String name, String value) {
        try {
            new CalloutEndpoint().putParameter(name, value);
        } catch (CalloutBuilder.CalloutBuilderException e) {
            return e.getMessage();
        }
        return null;
    }
}