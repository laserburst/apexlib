@IsTest
private class CalloutUrlEncodedForm_Test {
    @IsTest
    static void testToString() {
        Item item = new Item();
        item.sku = 'B 2';
        Map<String, Object> body =
            new Map<String, Object>{
                'items' => new List<Object>{ new Map<String, Object>{ 'sku' => 'A1', 'qty' => 2 }, item },
                'tags' => new List<Object>{ 'a', null, 'b' },
                'metadata' => new Map<String, Object>{ 'note' => '', 'old' => null },
                'rate' => 0.0000001
            };

        Test.startTest();
        String form = new CalloutUrlEncodedForm(body).toString();
        Test.stopTest();

        Assert.areEqual(
            new Set<String>{
                'items%5B0%5D%5Bsku%5D=A1',
                'items%5B0%5D%5Bqty%5D=2',
                'items%5B1%5D%5Bsku%5D=B+2',
                'tags%5B0%5D=a',
                'tags%5B1%5D=b',
                'metadata%5Bnote%5D=',
                'rate=0.0000001'
            },
            new Set<String>(form.split('&')),
            'Unexpected form fields: ' + form
        );
    }

    @IsTest
    static void testRejectsListBody() {
        String message;
        Test.startTest();
        try {
            new CalloutUrlEncodedForm(new List<Object>{ 'a' });
        } catch (CalloutBuilder.CalloutBuilderException e) {
            message = e.getMessage();
        }
        Test.stopTest();
        Assert.areEqual('A form body must be a Map or an object', message, 'A List body should be rejected');
    }

    public class Item {
        public String sku;
        public Integer qty;
    }
}