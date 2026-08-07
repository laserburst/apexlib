@IsTest
private with sharing class CalloutJsonPathSanitizer_Test {
    private static final String SEARCH_BODY = '{"results":[' +
        '{"name":"ok","folder":{"id":"F-PUBLIC"}},' +
        '{"name":"bad","folder":{"id":"F-RESTRICTED"}},' +
        '{"name":"alsoBad","folder":{"id":"F-SECRET"}}' +
        '],"totalCount":3}';

    @IsTest
    static void testRemovesMatchingListItem() {
        HttpResponse response = jsonResponse(SEARCH_BODY);

        Test.startTest();
        new CalloutJsonPathSanitizer(new Map<String, Object>{ 'results[folder][id]' => 'F-RESTRICTED' })
            .sanitize(response);
        Test.stopTest();

        List<Object> results = resultsOf(response);
        Assert.areEqual(2, results.size(), 'The matching result should be removed');
        Assert.areEqual('ok', nameAt(results, 0), 'Non-matching results should survive');
        Assert.areEqual('alsoBad', nameAt(results, 1), 'Non-matching results should survive');
    }

    @IsTest
    static void testListValueMatchesAnyElement() {
        HttpResponse response = jsonResponse(SEARCH_BODY);

        Test.startTest();
        new CalloutJsonPathSanitizer(new Map<String, Object>{
            'results[folder][id]' => new List<String>{ 'F-RESTRICTED', 'F-SECRET' }
        }).sanitize(response);
        Test.stopTest();

        List<Object> results = resultsOf(response);
        Assert.areEqual(1, results.size(), 'Results in any restricted folder should be removed');
        Assert.areEqual('ok', nameAt(results, 0), 'The unrestricted result should survive');
    }

    @IsTest
    static void testAnyModeCombinesEntriesIndependently() {
        HttpResponse response = jsonResponse('{"results":[' +
            '{"name":"keep","folder":"F-2","status":"active"},' +
            '{"name":"wrongFolder","folder":"F-1","status":"active"},' +
            '{"name":"archived","folder":"F-2","status":"archived"}' +
            ']}');

        Test.startTest();
        new CalloutJsonPathSanitizer(new Map<String, Object>{
            'results[folder]' => 'F-1',
            'results[status]' => 'archived'
        }).sanitize(response);
        Test.stopTest();

        List<Object> results = resultsOf(response);
        Assert.areEqual(1, results.size(), 'A match on either entry should remove the item');
        Assert.areEqual('keep', nameAt(results, 0), 'Items matching no entry should survive');
    }

    @IsTest
    static void testAllModeRequiresEveryEntry() {
        HttpResponse response = jsonResponse('{"results":[' +
            '{"name":"folderOnly","folder":"F-1","status":"active"},' +
            '{"name":"both","folder":"F-1","status":"archived"},' +
            '{"name":"statusOnly","folder":"F-2","status":"archived"}' +
            ']}');

        Test.startTest();
        new CalloutJsonPathSanitizer(new Map<String, Object>{
            'results[folder]' => 'F-1',
            'results[status]' => 'archived'
        }, CalloutJsonPathSanitizer.Match.ALL_ENTRIES).sanitize(response);
        Test.stopTest();

        List<Object> results = resultsOf(response);
        Assert.areEqual(2, results.size(), 'Only the item matching every entry should be removed');
        Assert.areEqual('folderOnly', nameAt(results, 0), 'Partial matches should survive in ALL mode');
        Assert.areEqual('statusOnly', nameAt(results, 1), 'Partial matches should survive in ALL mode');
    }

    @IsTest
    static void testNestedListRemovesInnermostItem() {
        HttpResponse response = jsonResponse(
            '{"folders":[{"name":"root","children":[{"id":"C-1"},{"id":"C-BAD"}]}]}'
        );

        Test.startTest();
        new CalloutJsonPathSanitizer(new Map<String, Object>{ 'folders[children][id]' => 'C-BAD' })
            .sanitize(response);
        Test.stopTest();

        Map<String, Object> body = bodyOf(response);
        List<Object> folders = (List<Object>) body.get('folders');
        Assert.areEqual(1, folders.size(), 'The outer folder should survive');
        List<Object> children = (List<Object>) ((Map<String, Object>) folders[0]).get('children');
        Assert.areEqual(1, children.size(), 'Only the matching child should be removed');
        Assert.areEqual('C-1', ((Map<String, Object>) children[0]).get('id'), 'The other child should survive');
    }

    @IsTest
    static void testExplicitIndexPath() {
        HttpResponse response = jsonResponse('{"items":[{"id":"A"},{"id":"B"}]}');

        Test.startTest();
        new CalloutJsonPathSanitizer(new Map<String, Object>{ 'items[0][id]' => 'A' })
            .sanitize(response);
        Test.stopTest();

        List<Object> items = (List<Object>) bodyOf(response).get('items');
        Assert.areEqual(1, items.size(), 'The indexed item should be removed');
        Assert.areEqual('B', ((Map<String, Object>) items[0]).get('id'), 'The other item should survive');
    }

    @IsTest
    static void testLeafPropertyRemovedWhenPathCrossesNoList() {
        HttpResponse response = jsonResponse('{"meta":{"owner":"secret-user","source":"api","level":3}}');

        Test.startTest();
        new CalloutJsonPathSanitizer(new Map<String, Object>{
            'meta[owner]' => 'secret-user',
            'meta[level]' => 3
        }).sanitize(response);
        Test.stopTest();

        Map<String, Object> meta = (Map<String, Object>) bodyOf(response).get('meta');
        Assert.isFalse(meta.containsKey('owner'), 'The matched leaf property should be removed');
        Assert.isFalse(meta.containsKey('level'), 'A non-String value should match by equality');
        Assert.areEqual('api', meta.get('source'), 'Sibling properties should survive');
    }

    @IsTest
    static void testNestedTargetInsideRemovedItem() {
        HttpResponse response = jsonResponse('{"results":[' +
            '{"folder":{"id":"F-1"},"children":[{"id":"C-1"}]},' +
            '{"folder":{"id":"F-2"},"children":[{"id":"C-1"},{"id":"C-2"}]}' +
            ']}');

        Test.startTest();
        new CalloutJsonPathSanitizer(new Map<String, Object>{
            'results[folder][id]' => 'F-1',
            'results[children][id]' => 'C-1'
        }).sanitize(response);
        Test.stopTest();

        List<Object> results = resultsOf(response);
        Assert.areEqual(1, results.size(), 'The restricted folder item should be removed wholesale');
        Map<String, Object> survivor = (Map<String, Object>) results[0];
        Assert.areEqual('F-2', ((Map<String, Object>) survivor.get('folder')).get('id'), 'The other item should survive');
        List<Object> children = (List<Object>) survivor.get('children');
        Assert.areEqual(1, children.size(), 'The restricted child should be removed from the surviving item');
        Assert.areEqual('C-2', ((Map<String, Object>) children[0]).get('id'), 'The other child should survive');
    }

    @IsTest
    static void testNoMatchLeavesBodyUnchanged() {
        HttpResponse response = jsonResponse(SEARCH_BODY);

        Test.startTest();
        new CalloutJsonPathSanitizer(new Map<String, Object>{
            'results[folder][id]' => 'F-NONE',
            'nonexistent[path]' => 'anything'
        }).sanitize(response);
        Test.stopTest();

        Map<String, Object> body = bodyOf(response);
        Assert.areEqual(3, ((List<Object>) body.get('results')).size(), 'No result should be removed');
        Assert.areEqual(3, body.get('totalCount'), 'Untouched properties should survive');
    }

    @IsTest
    static void testStringMatchIsCaseSensitive() {
        HttpResponse response = jsonResponse(SEARCH_BODY);

        Test.startTest();
        new CalloutJsonPathSanitizer(new Map<String, Object>{ 'results[folder][id]' => 'f-restricted' })
            .sanitize(response);
        Test.stopTest();

        Assert.areEqual(3, resultsOf(response).size(), 'A case mismatch should not match');
    }

    @IsTest
    static void testTopLevelArrayBody() {
        HttpResponse response = jsonResponse('[{"id":"A"},{"id":"BAD"}]');

        Test.startTest();
        new CalloutJsonPathSanitizer(new Map<String, Object>{ 'id' => 'BAD' })
            .sanitize(response);
        Test.stopTest();

        List<Object> items = (List<Object>) JSON.deserializeUntyped(response.getBody());
        Assert.areEqual(1, items.size(), 'The matching root array item should be removed');
        Assert.areEqual('A', ((Map<String, Object>) items[0]).get('id'), 'The other item should survive');
    }

    @IsTest
    static void testNonJsonBodyThrows() {
        HttpResponse response = jsonResponse('not json');

        Test.startTest();
        try {
            new CalloutJsonPathSanitizer(new Map<String, Object>{ 'results[id]' => 'x' })
                .sanitize(response);
            Assert.fail('A non-JSON body should fail closed');
        } catch (CalloutResponseSanitizerException e) {
            Assert.isTrue(e.getMessage().contains('non-JSON'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testInvalidCriteriaThrows() {
        try {
            new CalloutJsonPathSanitizer(null);
            Assert.fail('Null criteria should be rejected');
        } catch (IllegalArgumentException e) {
            Assert.isTrue(e.getMessage().contains('at least one'), 'Unexpected message: ' + e.getMessage());
        }
        try {
            new CalloutJsonPathSanitizer(new Map<String, Object>());
            Assert.fail('Empty criteria should be rejected');
        } catch (IllegalArgumentException e) {
            Assert.isTrue(e.getMessage().contains('at least one'), 'Unexpected message: ' + e.getMessage());
        }
        try {
            new CalloutJsonPathSanitizer(new Map<String, Object>{ 'results[]' => 'x' });
            Assert.fail('A blank path segment should be rejected');
        } catch (IllegalArgumentException e) {
            Assert.isTrue(e.getMessage().contains('Invalid criteria path'), 'Unexpected message: ' + e.getMessage());
        }
    }

    @IsTest
    static void testWorksThroughCalloutBuilder() {
        Test.startTest();
        Map<String, Object> body = new CalloutBuilder('callout:Test')
            .withEndpoint('/search')
            .withResponseSanitizer(new CalloutJsonPathSanitizer(new Map<String, Object>{
                'results[folder][id]' => new List<String>{ 'F-RESTRICTED', 'F-SECRET' }
            }))
            .withMockIfTest(new SearchMock())
            .getResponseBodyMap();
        Test.stopTest();

        List<Object> results = (List<Object>) body.get('results');
        Assert.areEqual(1, results.size(), 'Restricted results should never reach the caller');
        Assert.areEqual('ok', nameAt(results, 0), 'The unrestricted result should survive');
    }

    private static HttpResponse jsonResponse(String body) {
        HttpResponse response = new HttpResponse();
        response.setBody(body);
        return response;
    }

    private static Map<String, Object> bodyOf(HttpResponse response) {
        return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
    }

    private static List<Object> resultsOf(HttpResponse response) {
        return (List<Object>) bodyOf(response).get('results');
    }

    private static String nameAt(List<Object> results, Integer index) {
        return (String) ((Map<String, Object>) results[index]).get('name');
    }

    class SearchMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(SEARCH_BODY);
            res.setStatusCode(200);
            return res;
        }
    }
}
