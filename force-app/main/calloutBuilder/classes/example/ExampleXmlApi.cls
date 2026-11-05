/**
 * @description It illustrates XML callouts with CalloutBuilder.
 * @team Laserburst
 */
public with sharing class ExampleXmlApi {
    private static final String NC = 'callout:Example';
    private static final String CUSTOMER = '''
        <customer id="7">
            <name>Ada</name>
            <city>London</city>
            <note><![CDATA[Prefers <b>email</b> & mornings]]></note>
        </customer>''';
    private static final String ORDER = '''
        <order id="42">
            <status>open</status>
            <item>A-1</item>
        </order>''';
    private static final String ORDERS = '''
        <orders>
            <order id="42">
                <status>open</status>
                <item>A-1</item>
            </order>
        </orders>''';

    // the response's XML Content-Type selects CalloutXmlParser
    public static Customer getCustomer() {
        return (Customer) new CalloutBuilder(NC)
            .withSuccessType(Customer.class)
            .withMockIfTest(new XmlMock(CUSTOMER))
            .getTypedResponseBody();
    }

    public static Order getOrder() {
        return (Order) new CalloutBuilder(NC)
            .withSuccessType(Order.class)
            .withMockIfTest(new XmlMock(ORDER))
            .getTypedResponseBody();
    }

    // nothing inside a List element is learned, so a single <item> in an <order> needs withListElements()
    public static Orders getOrders() {
        CalloutXmlParser parser = new CalloutXmlParser().withListElements(new Set<String>{ 'item' });
        return (Orders) new CalloutBuilder(NC)
            .withResponseParser(parser)
            .withSuccessType(Orders.class)
            .withMockIfTest(new XmlMock(ORDERS))
            .getTypedResponseBody();
    }

    public class Customer {
        public String id;
        public String name;
        public String city;
        // CDATA content arrives as text, markup included
        public String note;
    }

    public class Order {
        public String id;
        public String status;
        // initialized, so a single <item> becomes a List instead of failing JSON.deserialize();
        // an order without <item> still leaves it null
        public List<String> item = new List<String>();
    }

    public class Orders {
        public List<Order> order = new List<Order>();
    }

    private class XmlMock implements HttpCalloutMock {
        private final String body;

        private XmlMock(String body) {
            this.body = body;
        }

        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/xml');
            response.setStatusCode(200);
            response.setBody(this.body);
            return response;
        }
    }
}