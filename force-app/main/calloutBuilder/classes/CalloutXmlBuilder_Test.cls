@IsTest
private class CalloutXmlBuilder_Test {
    @IsTest
    static void testToXmlString() {
        String missing;
        CalloutXmlBuilder order =
            new CalloutXmlBuilder('order')
                .withAttribute('id', '7')
                .withAttribute('status', missing)
                .withOptionalAttribute('channel', 'web')
                .withOptionalAttribute('skipped', ' ')
                .addValue('method', 'card')
                .addValue('cvv', '123')
                .addValue('method', 'visa')
                .addValue('required', missing)
                .addOptionalValue('note', 'kept')
                .addOptionalValue('skipped', ' ')
                .addValue('clean', 'a\u0001b\tc\nd\re\uFFFE\uFFFF');
        CalloutXmlBuilder line = order.addChild('line').withAttribute('sku', 'A').withText('two');
        order.addValue('after', 'x');
        line.addValue('late', 'y');
        String longText = 'x'.repeat(700000) + '\u0001';

        Assert.areEqual(
            getExpectedOrder(),
            order.toXmlString(),
            'Children should keep their order, and null and blank values should follow their method'
        );
        Assert.areEqual(
            '<?xml version="1.0" encoding="UTF-8"?><a></a>',
            new CalloutXmlBuilder('a').withXmlDeclaration().toXmlString(),
            'The declaration should be written when asked for'
        );
        Assert.areEqual(
            '<a></a>'.length() + 700000,
            new CalloutXmlBuilder('a').withText(longText).toXmlString().length(),
            'A forbidden character should be removed from very long text'
        );
    }

    @IsTest
    static void testNumbersAndBooleans() {
        Decimal missingNumber;
        Boolean missingFlag;

        String xml =
            new CalloutXmlBuilder('values')
                .withAttribute('count', 2)
                .withAttribute('paid', true)
                .withAttribute('noNumber', missingNumber)
                .withAttribute('noFlag', missingFlag)
                .withOptionalAttribute('total', 1.50)
                .withOptionalAttribute('gift', false)
                .withOptionalAttribute('skippedNumber', missingNumber)
                .withOptionalAttribute('skippedFlag', missingFlag)
                .addValue('price', 0.00000001)
                .addValue('fragile', true)
                .addValue('emptyNumber', missingNumber)
                .addValue('emptyFlag', missingFlag)
                .addOptionalValue('weight', 2)
                .addOptionalValue('insured', false)
                .addOptionalValue('skippedNumber', missingNumber)
                .addOptionalValue('skippedFlag', missingFlag)
                .toXmlString();

        Assert.areEqual(
            getExpectedValues(),
            xml,
            'Numbers and Booleans should be written as text, and a null should follow its method'
        );
    }

    @IsTest
    static void testSerializableContent() {
        Part missing;
        List<Part> noParts;
        CalloutXmlBuilder shared =
            new CalloutXmlBuilder('shared').withAttribute('sku', 'a').withText('t').addValue('v', 'x');

        String xml =
            new CalloutXmlBuilder('parts')
                .addChild(new Part('a'))
                .addChild('renamed', new Part('b'))
                .addChild('empty', missing)
                .addOptionalChild(new Part('c'))
                .addOptionalChild(missing)
                .addChildren(new List<Part>{ new Part('d'), new Part('e') })
                .addChildren(noParts)
                .toXmlString();
        String sharedXml =
            new CalloutXmlBuilder('both').addChild('first', shared).addChild('second', shared).toXmlString();

        Assert.areEqual(
            getExpectedParts(),
            xml,
            'Content should name its element unless a name is given, and each method should keep the parent'
        );
        Assert.areEqual(
            '<both><first sku="a">t<v>x</v></first><second sku="a">t<v>x</v></second></both>',
            sharedXml,
            'One element should keep its content under each name it is given'
        );
    }

    private static String getExpectedOrder() {
        return toCompactXml('''
            <order id="7" status="" channel="web">
                <method>card</method>
                <cvv>123</cvv>
                <method>visa</method>
                <required></required>
                <note>kept</note>
                <clean>ab\tc\nd\re</clean>
                <line sku="A">two<late>y</late></line>
                <after>x</after>
            </order>''');
    }

    private static String getExpectedValues() {
        return toCompactXml('''
            <values count="2" paid="true" noNumber="" noFlag="" total="1.50" gift="false">
                <price>0.00000001</price>
                <fragile>true</fragile>
                <emptyNumber></emptyNumber>
                <emptyFlag></emptyFlag>
                <weight>2</weight>
                <insured>false</insured>
            </values>''');
    }

    private static String getExpectedParts() {
        return toCompactXml('''
            <parts>
                <part sku="a"></part>
                <renamed sku="b"></renamed>
                <empty></empty>
                <part sku="c"></part>
                <part sku="d"></part>
                <part sku="e"></part>
            </parts>''');
    }

    private static String toCompactXml(String xml) {
        return xml.replaceAll('>\\s+<', '><');
    }

    private class Part implements CalloutXmlSerializable {
        private final String sku;

        private Part(String sku) {
            this.sku = sku;
        }

        public CalloutXmlBuilder toXmlBuilder() {
            return new CalloutXmlBuilder('part').withAttribute('sku', this.sku);
        }
    }
}