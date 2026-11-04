@IsTest
private class CalloutXmlParser_Test {
    @IsTest
    static void testDeserializeUntyped() {
        Map<String, Object> order =
            new CalloutXmlParser()
                .withListElements(new Set<String>{ 'tag' })
                .deserializeUntyped(
                    load(
                        '<o:order xmlns:o="urn:o" id="7" status="ignored">'
                        + '<o:status>open</o:status><paid>true</paid><returned>false</returned><shipped>TRUE</shipped><note/>'
                        + '<item sku="A">2</item><item sku="B">3</item><item sku="C">4</item><tag>x</tag>'
                        + '</o:order>'
                    )
                );
        Map<String, Object> text = new CalloutXmlParser().deserializeUntyped(load('<string>abc</string>'));

        Assert.areEqual(
            'open',
            order.get('status'),
            'A child element should win over an attribute and lose its prefix'
        );
        Assert.areEqual('7', order.get('id'), 'An attribute should become a key');
        Assert.areEqual(true, order.get('paid'), 'true should become a Boolean');
        Assert.areEqual(false, order.get('returned'), 'false should become a Boolean');
        Assert.areEqual('TRUE', order.get('shipped'), 'Only lowercase true should become a Boolean');
        Assert.isTrue(order.containsKey('note') && order.get('note') == null, 'An empty element should become null');
        List<Object> items = (List<Object>) order.get('item');
        Assert.areEqual(3, items.size(), 'A repeated element should become a List');
        Assert.areEqual(
            new Map<String, Object>{ 'sku' => 'A', 'text' => '2' },
            items[0],
            'Text next to attributes should be kept under text'
        );
        Assert.areEqual(
            new List<Object>{ 'x' },
            order.get('tag'),
            'A list element should be a List when it occurs once'
        );
        Assert.areEqual(new Map<String, Object>{ 'text' => 'abc' }, text, 'A text-only root should be kept under text');
    }

    @IsTest
    static void testDeserializeToApexType() {
        TypedOrder order =
            (TypedOrder) new CalloutXmlParser()
                .withListElements(new Set<String>{ 'gift_tag' })
                .deserialize(
                    load(
                        '<order xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" _Id="7" unit-price="5.50">'
                        + '<paid xsi:type="xsd:boolean">true</paid><discount xsi:nil="true"/>'
                        + '<Item><qty>2</qty><gift-tag>new</gift-tag></Item>'
                        + '<shipment><item><qty>3</qty></item><label>fragile</label></shipment>'
                        + '</order>'
                    ),
                    TypedOrder.class
                );

        Assert.areEqual(7, order.Id, 'A leading underscore should be removed from a key');
        Assert.areEqual(5.50, order.unit_price, 'A hyphen should become an underscore');
        Assert.isTrue(order.paid, 'An xsi:type attribute should not become a key');
        Assert.isNull(order.discount, 'An xsi:nil element should become null');
        Assert.areEqual(
            2,
            order.item[0].qty,
            'An initialized List field should be a List when its element occurs once, matched ignoring case'
        );
        Assert.areEqual(
            new List<String>{ 'fragile' },
            order.shipment.label,
            'An initialized List field of an initialized object should be a List'
        );
        Assert.areEqual(3, order.shipment.item.qty, 'A learned List field should apply at its own path only');
        Assert.areEqual(
            new List<String>{ 'new' },
            order.item[0].gift_tag,
            'An element withListElements() names by its key should be a List'
        );
    }

    @IsTest
    static void testDeserializeWithoutNoArgConstructor() {
        NoDefaultConstructor result =
            (NoDefaultConstructor) new CalloutXmlParser()
                .withListElements(new Set<String>{ 'tag' })
                .deserialize(load('<a><tag>x</tag></a>'), NoDefaultConstructor.class);

        Assert.areEqual(
            new List<String>{ 'x' },
            result.tag,
            'withListElements() should apply without a no-arg constructor'
        );
    }

    @IsTest
    static void testLoadRejectsUnterminatedCdata() {
        try {
            CalloutXmlParser.load('<note><![CDATA[a</note>');

            Assert.fail('Expected error not thrown');
        } catch (XmlException e) {
            Assert.isNotNull(e.getMessage(), 'Unterminated CDATA should fail to load');
        }
    }

    @IsTest
    static void testSubclassOverridesKeysAndValues() {
        Map<String, Object> order =
            new IndicatorParser().deserializeUntyped(
                load('<order Paid="Y"><Shipped>N</Shipped><Initial>N</Initial></order>')
            );

        Assert.areEqual(true, order.get('paid'), 'Overridden hooks should convert an attribute');
        Assert.areEqual(false, order.get('shipped'), 'Overridden hooks should convert an element');
        Assert.areEqual('N', order.get('initial'), 'Overridden hooks should receive the element name');
    }

    private static Dom.Document load(String xml) {
        Dom.Document document = new Dom.Document();
        document.load(xml);
        return document;
    }

    public class TypedOrder {
        public Integer Id;
        public Decimal unit_price;
        public Boolean paid;
        public Decimal discount;
        public List<TypedItem> item = new List<TypedItem>();
        public TypedShipment shipment = new TypedShipment();
    }

    public class TypedItem {
        public Integer qty;
        public List<String> gift_tag;
    }

    public class TypedShipment {
        public TypedItem item;
        public List<String> label = new List<String>();
    }

    public class NoDefaultConstructor {
        public List<String> tag;

        public NoDefaultConstructor(List<String> tag) {
            this.tag = tag;
        }
    }

    private class IndicatorParser extends CalloutXmlParser {
        private final Set<String> indicators = new Set<String>{ 'Paid', 'Shipped' };

        protected override String toKey(String name) {
            return name.toLowerCase();
        }

        protected override Object toValue(String name, String text) {
            if (this.indicators.contains(name)) {
                return text == 'Y';
            }
            return super.toValue(name, text);
        }
    }
}