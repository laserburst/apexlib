/**
 * @description Builds an XML element whose children keep the order they are added in.
 * Names are written as given, so a prefix or an xmlns declaration goes in the name, and nothing validates them.
 * Integer, Long and Double values arrive as Decimal.
 * @team Laserburst
 */
public class CalloutXmlBuilder implements CalloutXmlSerializable {
    // XML 1.0 forbids these, and XmlStreamWriter writes them as they are: https://www.w3.org/TR/xml/#charsets
    private static final String FORBIDDEN_CHARACTERS =
        '\u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008\u000B\u000C\u000E\u000F\u0010\u0011'
        + '\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\u001B\u001C\u001D\u001E\u001F\uFFFE\uFFFF';

    private final String name;
    private final Map<String, String> attributes = new Map<String, String>();
    private final List<CalloutXmlBuilder> children = new List<CalloutXmlBuilder>();
    private String text = '';
    private Boolean hasDeclaration = false;

    /**
     * @description CalloutXmlBuilder starts an element with this name
     */
    public CalloutXmlBuilder(String name) {
        this.name = name;
    }

    /**
     * @description getName returns the name of this element
     */
    public String getName() {
        return this.name;
    }

    /**
     * @description toXmlBuilder returns this builder, so a builder goes wherever a CalloutXmlSerializable does
     */
    public CalloutXmlBuilder toXmlBuilder() {
        return this;
    }

    /**
     * @description withAttribute sets an attribute, empty for a null value
     */
    public CalloutXmlBuilder withAttribute(String name, String value) {
        this.attributes.put(name, toXmlText(value));
        return this;
    }

    /**
     * @description withAttribute sets an attribute to a number in plain notation, empty for a null value
     */
    public CalloutXmlBuilder withAttribute(String name, Decimal value) {
        return this.withAttribute(name, value?.toPlainString());
    }

    /**
     * @description withAttribute sets an attribute to true or false, empty for a null value
     */
    public CalloutXmlBuilder withAttribute(String name, Boolean value) {
        return this.withAttribute(name, String.valueOf(value));
    }

    /**
     * @description withOptionalAttribute sets an attribute, or nothing for a blank value
     */
    public CalloutXmlBuilder withOptionalAttribute(String name, String value) {
        if (String.isNotBlank(value)) {
            this.withAttribute(name, value);
        }
        return this;
    }

    /**
     * @description withOptionalAttribute sets an attribute to a number in plain notation, or nothing for a null value
     */
    public CalloutXmlBuilder withOptionalAttribute(String name, Decimal value) {
        return this.withOptionalAttribute(name, value?.toPlainString());
    }

    /**
     * @description withOptionalAttribute sets an attribute to true or false, or nothing for a null value
     */
    public CalloutXmlBuilder withOptionalAttribute(String name, Boolean value) {
        return this.withOptionalAttribute(name, String.valueOf(value));
    }

    /**
     * @description withText sets the text of this element, which is written before its children
     */
    public CalloutXmlBuilder withText(String text) {
        this.text = toXmlText(text);
        return this;
    }

    /**
     * @description withXmlDeclaration applies to the element toXmlString() is called on
     */
    public CalloutXmlBuilder withXmlDeclaration() {
        this.hasDeclaration = true;
        return this;
    }

    /**
     * @description addChild adds an empty child, to add to now or later
     * @return the new child, not this builder
     */
    public CalloutXmlBuilder addChild(String name) {
        CalloutXmlBuilder child = new CalloutXmlBuilder(name);
        this.children.add(child);
        return child;
    }

    /**
     * @description addChild adds the element of content under its own name, and throws on null content
     */
    public CalloutXmlBuilder addChild(CalloutXmlSerializable content) {
        this.children.add(content.toXmlBuilder());
        return this;
    }

    /**
     * @description addChild adds a copy of the element of content under this name,
     * or an empty element for null content
     */
    public CalloutXmlBuilder addChild(String name, CalloutXmlSerializable content) {
        if (content == null) {
            this.addChild(name);
        } else {
            this.children.add(content.toXmlBuilder().toCopyNamed(name));
        }
        return this;
    }

    /**
     * @description addOptionalChild adds the element of content, or nothing for null content
     */
    public CalloutXmlBuilder addOptionalChild(CalloutXmlSerializable content) {
        if (content != null) {
            this.addChild(content);
        }
        return this;
    }

    /**
     * @description addChildren adds the element of each content under its own name, or nothing for a null list
     */
    public CalloutXmlBuilder addChildren(List<CalloutXmlSerializable> contents) {
        if (contents == null) {
            return this;
        }
        for (CalloutXmlSerializable content : contents) {
            this.addChild(content);
        }
        return this;
    }

    /**
     * @description addValue adds a child with text, empty for a null value
     */
    public CalloutXmlBuilder addValue(String name, String value) {
        this.addChild(name).withText(value);
        return this;
    }

    /**
     * @description addValue adds a child with a number in plain notation, empty for a null value
     */
    public CalloutXmlBuilder addValue(String name, Decimal value) {
        return this.addValue(name, value?.toPlainString());
    }

    /**
     * @description addValue adds a child with true or false, empty for a null value
     */
    public CalloutXmlBuilder addValue(String name, Boolean value) {
        return this.addValue(name, String.valueOf(value));
    }

    /**
     * @description addOptionalValue adds a child with text, or nothing for a blank value
     */
    public CalloutXmlBuilder addOptionalValue(String name, String value) {
        if (String.isNotBlank(value)) {
            this.addValue(name, value);
        }
        return this;
    }

    /**
     * @description addOptionalValue adds a child with a number in plain notation, or nothing for a null value
     */
    public CalloutXmlBuilder addOptionalValue(String name, Decimal value) {
        return this.addOptionalValue(name, value?.toPlainString());
    }

    /**
     * @description addOptionalValue adds a child with true or false, or nothing for a null value
     */
    public CalloutXmlBuilder addOptionalValue(String name, Boolean value) {
        return this.addOptionalValue(name, String.valueOf(value));
    }

    /**
     * @description toXmlString writes this element and its children, with no formatting between them
     */
    public String toXmlString() {
        XmlStreamWriter writer = new XmlStreamWriter();
        if (this.hasDeclaration) {
            writer.writeStartDocument('UTF-8', '1.0');
        }
        this.writeTo(writer);
        writer.writeEndDocument();
        String xml = writer.getXmlString();
        writer.close();
        return xml;
    }

    // a copy, so that one element can sit under two names
    private CalloutXmlBuilder toCopyNamed(String name) {
        CalloutXmlBuilder copy = new CalloutXmlBuilder(name);
        copy.attributes.putAll(this.attributes);
        copy.children.addAll(this.children);
        copy.text = this.text;
        return copy;
    }

    private void writeTo(XmlStreamWriter writer) {
        writer.writeStartElement(null, this.name, null);
        for (String attribute : this.attributes.keySet()) {
            writer.writeAttribute(null, null, attribute, this.attributes.get(attribute));
        }
        writer.writeCharacters(this.text);
        for (CalloutXmlBuilder child : this.children) {
            child.writeTo(writer);
        }
        writer.writeEndElement();
    }

    // XmlStreamWriter throws on null, and replaceAll() hits a LimitException on very long text
    private static String toXmlText(String value) {
        String text = value ?? '';
        if (text.containsNone(FORBIDDEN_CHARACTERS)) {
            return text;
        }
        for (String character : FORBIDDEN_CHARACTERS.split('')) {
            text = text.remove(character);
        }
        return text;
    }
}