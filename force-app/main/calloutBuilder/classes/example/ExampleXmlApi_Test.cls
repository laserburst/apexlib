@IsTest
private with sharing class ExampleXmlApi_Test {
    @IsTest
    static void testGetCustomer() {
        Test.startTest();
        ExampleXmlApi.Customer customer = ExampleXmlApi.getCustomer();
        Test.stopTest();

        Assert.areEqual('Ada', customer.name, 'The customer should be read from XML');
        Assert.areEqual('Prefers <b>email</b> & mornings', customer.note, 'CDATA content should be read as text');
    }

    @IsTest
    static void testGetOrder() {
        Test.startTest();
        ExampleXmlApi.Order order = ExampleXmlApi.getOrder();
        Test.stopTest();

        Assert.areEqual(new List<String>{ 'A-1' }, order.item, 'A single item should be a List');
    }

    @IsTest
    static void testGetOrders() {
        Test.startTest();
        ExampleXmlApi.Orders orders = ExampleXmlApi.getOrders();
        Test.stopTest();

        Assert.areEqual(
            new List<String>{ 'A-1' },
            orders.order[0].item,
            'A single item in a List element should be a List'
        );
    }

    @IsTest
    static void testCreateOrder() {
        ExampleXmlApi.NewOrderItem item = new ExampleXmlApi.NewOrderItem();
        item.sku = 'A-1';
        item.quantity = 2;
        ExampleXmlApi.NewOrder newOrder = new ExampleXmlApi.NewOrder();
        newOrder.customerId = '7';
        newOrder.items.add(item);

        Test.startTest();
        ExampleXmlApi.Order order = ExampleXmlApi.createOrder(newOrder);
        Test.stopTest();

        Assert.areEqual(
            '<order customer="7"><item sku="A-1"><quantity>2</quantity></item></order>',
            newOrder.toXmlBuilder().toXmlString(),
            'The order should build its own XML'
        );
        Assert.areEqual('42', order.id, 'The response should be read from XML');
    }
}