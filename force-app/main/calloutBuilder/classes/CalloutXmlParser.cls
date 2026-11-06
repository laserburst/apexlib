/**
 * @description Parses XML into a Map<String, Object> or an Apex type.
 * @team Laserburst
 */
public virtual class CalloutXmlParser extends CalloutResponseParser {
    // text next to attributes or child elements, and a root's text when it has neither
    private static final String TEXT_KEY = 'text';
    private static final String CDATA_START = '<![CDATA[';
    private static final String CDATA_END = ']]>';
    // xsi:nil and xsi:type describe a value rather than add a field
    private static final String XSI_NAMESPACE = 'http://www.w3.org/2001/XMLSchema-instance';
    // JSON.deserialize() matches field names ignoring case; a fixed locale keeps 'I' from becoming a dotless 'ı'
    private static final String FIELD_NAME_LOCALE = 'en';
    private static final Target MAP_TARGET = new Target();
    private static final ApexTarget UNKNOWN_FIELD = new ApexTarget();

    private final Set<String> listElements = new Set<String>();

    /**
     * @description load returns a Dom.Document that keeps CDATA content, which Dom.Document.load() drops
     */
    public static Dom.Document load(String xml) {
        Dom.Document document = new Dom.Document();
        document.load(escapeCdata(xml));
        return document;
    }

    /**
     * @description withListElements makes an element that occurs once a List when elementNames holds its
     * XML name or key, such as line-item or, under deserialize(), line_item, matching case at any depth.
     * XML has no array marker, so without it such an element becomes an object or a value.
     */
    public CalloutXmlParser withListElements(Set<String> elementNames) {
        this.listElements.addAll(elementNames);
        return this;
    }

    public override Map<String, Object> deserializeUntyped(String body) {
        return this.deserializeUntyped(load(body));
    }

    public Map<String, Object> deserializeUntyped(Dom.Document document) {
        return this.deserializeUntyped(document.getRootElement());
    }

    public Map<String, Object> deserializeUntyped(Dom.XmlNode element) {
        return this.toMap(element, MAP_TARGET);
    }

    public override Object deserialize(String body, System.Type apexType) {
        // not the Dom.Document overload: it would hold the tree and the JSON string on the heap at once
        Map<String, Object> fields = this.toApexMap(load(body).getRootElement(), apexType);
        return JSON.deserialize(JSON.serialize(fields), apexType);
    }

    public Object deserialize(Dom.Document document, System.Type apexType) {
        return this.deserialize(document.getRootElement(), apexType);
    }

    public Object deserialize(Dom.XmlNode element, System.Type apexType) {
        Map<String, Object> fields = this.toApexMap(element, apexType);
        return JSON.deserialize(JSON.serialize(fields), apexType);
    }

    private static String escapeCdata(String xml) {
        List<String> parts = new List<String>();
        Integer position = 0;
        Integer start = xml.indexOf(CDATA_START);
        while (start != -1) {
            Integer finish = xml.indexOf(CDATA_END, start);
            if (finish == -1) {
                break; // unterminated: load() rejects it
            }
            parts.add(xml.substring(position, start));
            parts.add(xml.substring(start + CDATA_START.length(), finish).escapeXml());
            position = finish + CDATA_END.length();
            start = xml.indexOf(CDATA_START, position);
        }
        parts.add(xml.substring(position));
        // a body cut inside a new element's name otherwise makes load() throw an uncatchable UnexpectedException
        parts.add(' ');
        return String.join(parts, '');
    }

    // runs the type's constructor and getters on every call, and they may throw anything
    private static ApexTarget toApexTarget(System.Type apexType) {
        try {
            Object instance = apexType.newInstance();
            return new ApexTarget(JSON.deserializeUntyped(JSON.serialize(instance)));
        } catch (Exception e) {
            return UNKNOWN_FIELD;
        }
    }

    private Boolean isNamedListElement(String name, String key) {
        return this.listElements.contains(name) || this.listElements.contains(key);
    }

    private Map<String, Object> toApexMap(Dom.XmlNode element, System.Type apexType) {
        return this.toMap(element, toApexTarget(apexType));
    }

    private Map<String, Object> toMap(Dom.XmlNode element, Target target) {
        Object value = this.toElementValue(element, target);
        if (value instanceof Map<String, Object>) {
            return (Map<String, Object>) value;
        }
        return new Map<String, Object>{ TEXT_KEY => value };
    }

    // getName() and getAttributeKeyAt() leave out namespace prefixes
    private Object toElementValue(Dom.XmlNode element, Target target) {
        ElementFields fields = new ElementFields();
        for (Dom.XmlNode child : element.getChildElements()) {
            String name = child.getName();
            String key = target.toFieldName(this.toKey(name));
            Target childTarget = target.get(key);
            Object value = this.toElementValue(child, childTarget);
            if (childTarget.isList || this.isNamedListElement(name, key)) {
                fields.addListElement(key, value);
            } else {
                fields.addElement(key, value);
            }
        }
        for (Integer i = 0; i < element.getAttributeCount(); i++) {
            String namespace = element.getAttributeKeyNsAt(i);
            if (namespace == XSI_NAMESPACE) {
                continue;
            }
            String name = element.getAttributeKeyAt(i);
            String key = target.toFieldName(this.toKey(name));
            fields.addAttribute(key, this.toValue(name, element.getAttributeValue(name, namespace)));
        }
        String text = element.getText();
        if (fields.values.isEmpty()) {
            return this.toValue(element.getName(), text);
        }
        if (String.isNotBlank(text)) {
            fields.addText(this.toValue(element.getName(), text));
        }
        return fields.values;
    }

    /**
     * @description toKey names the key of an element or attribute; deserialize() then turns it into an Apex name
     */
    protected virtual String toKey(String name) {
        return name;
    }

    /**
     * @description toValue converts the text of a named element or attribute:
     * 'true' and 'false' become Booleans, and blank text becomes null
     */
    protected virtual Object toValue(String name, String text) {
        if (String.isBlank(text)) {
            return null;
        }
        // String == ignores case, so 'TRUE' must not become a Boolean
        if (text.equals('true')) {
            return true;
        }
        if (text.equals('false')) {
            return false;
        }
        return text;
    }

    private virtual class Target {
        private Boolean isList = false;

        public virtual String toFieldName(String key) {
            return key;
        }

        public virtual Target get(String key) {
            return this;
        }
    }

    // knows only the List fields a new instance initializes, at their own path and not inside List elements
    private class ApexTarget extends Target {
        private final Map<String, ApexTarget> fields = new Map<String, ApexTarget>();

        private ApexTarget() {
        }

        private ApexTarget(Object serializedValue) {
            this.isList = serializedValue instanceof List<Object>;
            if (serializedValue instanceof Map<String, Object>) {
                Map<String, Object> serializedFields = (Map<String, Object>) serializedValue;
                for (String name : serializedFields.keySet()) {
                    this.fields.put(name.toLowerCase(FIELD_NAME_LOCALE), new ApexTarget(serializedFields.get(name)));
                }
            }
        }

        // unit-price becomes unit_price, and _Value becomes Value
        public override String toFieldName(String key) {
            return key.replaceAll('[^A-Za-z0-9_]', '_').replaceAll('_+', '_').replaceAll('^_|_$', '');
        }

        public override Target get(String key) {
            return this.fields.get(key.toLowerCase(FIELD_NAME_LOCALE)) ?? UNKNOWN_FIELD;
        }
    }

    // child elements first: a child element wins over an attribute of the same name
    private class ElementFields {
        private final Map<String, Object> values = new Map<String, Object>();

        private void addElement(String key, Object value) {
            Object existing = this.values.get(key);
            if (existing instanceof List<Object>) {
                ((List<Object>) existing).add(value);
            } else if (this.values.containsKey(key)) {
                this.values.put(key, new List<Object>{ existing, value });
            } else {
                this.values.put(key, value);
            }
        }

        private void addListElement(String key, Object value) {
            if (!this.values.containsKey(key)) {
                this.values.put(key, new List<Object>());
            }
            this.addElement(key, value);
        }

        private void addAttribute(String key, Object value) {
            if (!this.values.containsKey(key)) {
                this.values.put(key, value);
            }
        }

        private void addText(Object value) {
            this.values.put(TEXT_KEY, value);
        }
    }
}