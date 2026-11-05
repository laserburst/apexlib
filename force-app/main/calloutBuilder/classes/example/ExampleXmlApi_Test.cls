@IsTest
private with sharing class ExampleXmlApi_Test {
    @IsTest
    static void testGetCustomer() {
        Test.startTest();
        ExampleXmlApi.Customer customer = ExampleXmlApi.getCustomer();
        Test.stopTest();

        Assert.areEqual('Ada', customer.name, 'The customer should be read from XML');
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
}