@IsTest
private class CalloutEndpointPattern_Test {
    @IsTest
    static void testMatches() {
        Map<String, Boolean> expectedForItem =
            new Map<String, Boolean>{
                '/items/5' => true,
                '/ITEMS/a b/' => true,
                '/items' => false,
                '/items/5/notes' => false
            };
        Map<String, Boolean> expectedForSubtree =
            new Map<String, Boolean>{ '/items' => true, '/items/5/notes' => true, '/items-admin' => false };

        Test.startTest();
        Map<String, Boolean> forItem = toMatchesByPath('/items/{id}', expectedForItem.keySet());
        Map<String, Boolean> forSubtree = toMatchesByPath('/items/*', expectedForSubtree.keySet());
        Test.stopTest();

        Assert.areEqual(expectedForItem, forItem, '{id} should match one segment, literals without case');
        Assert.areEqual(expectedForSubtree, forSubtree, '/* should match the path before it and everything below');
    }

    @IsTest
    static void testToParameters() {
        CalloutEndpointPattern endpoint = new CalloutEndpointPattern('/items/{id}/notes/{note}');

        Test.startTest();
        Map<String, String> parameters = endpoint.toParameters('/items/Ab/notes/c d');
        Test.stopTest();

        Assert.areEqual(
            new Map<String, String>{ 'id' => 'Ab', 'note' => 'c d' },
            parameters,
            'Each name should get its own segment'
        );
    }

    @IsTest
    static void testConstructorRejectsInvalidPatterns() {
        String wholeSegment = 'Endpoint pattern placeholder must be a whole {name} segment';
        String blockedSegment =
            'Endpoint pattern must not contain an empty or dot segment, "\\", ";", "%" or a control character';
        Map<String, String> expectedByPattern =
            new Map<String, String>{
                null => 'Endpoint pattern must start with "/"',
                'items' => 'Endpoint pattern must start with "/"',
                '/items?x' => 'Endpoint pattern must not contain "?" or "#"',
                '/items#x' => 'Endpoint pattern must not contain "?" or "#"',
                '/*/items' => 'Endpoint pattern may contain "*" only as a trailing "/*"',
                '/items/{id}.json' => wholeSegment,
                '/items/{}' => wholeSegment,
                '/items/{a}{b}' => wholeSegment,
                '/items/{id}/{id}' => 'Endpoint pattern placeholder {id} is used twice',
                '/items//5' => blockedSegment,
                '/items/..' => blockedSegment,
                '/a;b' => blockedSegment,
                '/a%2Fb' => blockedSegment,
                '/a\\b' => blockedSegment,
                '/a\tb' => blockedSegment
            };

        Test.startTest();
        Map<String, String> errorByPattern = new Map<String, String>();
        for (String pattern : expectedByPattern.keySet()) {
            errorByPattern.put(pattern, toError(pattern));
        }
        Test.stopTest();

        Assert.areEqual(expectedByPattern, errorByPattern, 'Each invalid pattern should throw its own message');
    }

    @IsTest
    static void testCompareTo() {
        List<String> unsorted =
            new List<String>{ '/items/*', '/items/me', '/*', '/items/{id}/*', '/items/me/*', '/items/{id}' };
        List<CalloutEndpointPattern> patterns = new List<CalloutEndpointPattern>();
        for (String endpoint : unsorted) {
            patterns.add(new CalloutEndpointPattern(endpoint));
        }
        CalloutEndpointPattern item = new CalloutEndpointPattern('/items/{id}');
        CalloutEndpointPattern sameShape = new CalloutEndpointPattern('/ORDERS/{key}/');

        Test.startTest();
        patterns.sort();
        Integer equalShapes = item.compareTo(sameShape);
        Integer againstNull = item.compareTo(null);
        Test.stopTest();

        List<String> sorted = new List<String>();
        for (CalloutEndpointPattern pattern : patterns) {
            sorted.add(pattern.getEndpoint());
        }
        Assert.areEqual(
            new List<String>{ '/items/me', '/items/me/*', '/items/{id}', '/items/{id}/*', '/items/*', '/*' },
            sorted,
            'The most specific pattern should sort first'
        );
        Assert.areEqual(0, equalShapes, 'Equal shapes are equally specific');
        Assert.isTrue(againstNull < 0, 'No pattern ranks last');
    }

    private static Map<String, Boolean> toMatchesByPath(String endpoint, Set<String> paths) {
        CalloutEndpointPattern pattern = new CalloutEndpointPattern(endpoint);
        Map<String, Boolean> matchesByPath = new Map<String, Boolean>();
        for (String path : paths) {
            matchesByPath.put(path, pattern.matches(path));
        }
        return matchesByPath;
    }

    private static String toError(String endpoint) {
        try {
            new CalloutEndpointPattern(endpoint);
        } catch (CalloutBuilder.CalloutBuilderException e) {
            return e.getMessage();
        }
        return null;
    }
}