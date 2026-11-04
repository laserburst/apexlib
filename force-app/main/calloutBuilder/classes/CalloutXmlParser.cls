/**
 * @description Parses XML into a Dom.Document that keeps CDATA content, a Map<String, Object> or an Apex type.
 * - Child elements and attributes become keys without namespace prefixes; a child element wins over an attribute of the same name.
 * - A repeated child element becomes a List. One that occurs once is a List when withListElements() names it,
 * by XML name or key, matching case, at any depth, or under deserialize() when a new instance of the type
 * initializes that List field, at that field's path only.
 * - An element without attributes and child elements becomes its text: 'true' and 'false' become Booleans, blank text becomes null.
 * - Text next to attributes or child elements is kept under the key 'text'.
 * - xsi attributes, such as xsi:nil and xsi:type, don't become keys.
 * - deserialize() turns keys into Apex names: unit-price becomes unit_price, and _Value becomes Value.
 * - Subclasses override toKey() to name keys (apexKeys is true under deserialize())
 * and toValue() to convert the text of a named element or attribute.
 * @team Laserburst
 */
public virtual class CalloutXmlParser extends CalloutResponseParser {
    private static final String TEXT_KEY = 'text';
    private static final String CDATA_START = '<![CDATA[';
    private static final String CDATA_END = ']]>';
    // xsi:nil and xsi:type describe a value rather than add a field
    private static final String XSI_NAMESPACE = 'http://www.w3.org/2001/XMLSchema-instance';
    // JSON.deserialize() matches field names ignoring case; a fixed locale keeps 'I' from becoming a dotless 'ı'
    private static final String FIELD_NAME_LOCALE = 'en';
    private static final Map<String, Object> NO_INITIALIZED_FIELDS = new Map<String, Object>();

    private final Set<String> listElements = new Set<String>();

    public static Dom.Document load(String xml) {
        Dom.Document document = new Dom.Document();
        document.load(escapeCdata(xml));
        return document;
    }

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
        return this.toMap(element, false, NO_INITIALIZED_FIELDS);
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

    // Dom.Document.load() drops CDATA content
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
        return String.join(parts, '');
    }

    // any Exception: the type's constructor and getters may throw anything
    private static Map<String, Object> learnFromType(System.Type apexType) {
        try {
            Object instance = apexType.newInstance();
            return toInitializedFields((Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(instance)));
        } catch (Exception e) {
            return NO_INITIALIZED_FIELDS;
        }
    }

    private static Map<String, Object> toInitializedFields(Map<String, Object> serializedFields) {
        Map<String, Object> initializedFields = new Map<String, Object>();
        for (String field : serializedFields.keySet()) {
            Object value = serializedFields.get(field);
            if (value instanceof List<Object>) {
                initializedFields.put(field.toLowerCase(FIELD_NAME_LOCALE), value);
            } else if (value instanceof Map<String, Object>) {
                initializedFields.put(
                    field.toLowerCase(FIELD_NAME_LOCALE),
                    toInitializedFields((Map<String, Object>) value)
                );
            }
        }
        return initializedFields;
    }

    private static Object getInitializedField(Map<String, Object> initializedFields, String key) {
        return initializedFields.get(key.toLowerCase(FIELD_NAME_LOCALE));
    }

    private static Boolean isListField(Object initializedField) {
        return initializedField instanceof List<Object>;
    }

    private static Map<String, Object> getNestedInitializedFields(Object initializedField) {
        if (initializedField instanceof Map<String, Object>) {
            return (Map<String, Object>) initializedField;
        }
        return NO_INITIALIZED_FIELDS;
    }

    private Boolean isListElement(String name, String key) {
        return this.listElements.contains(name) || this.listElements.contains(key);
    }

    private Map<String, Object> toApexMap(Dom.XmlNode element, System.Type apexType) {
        return this.toMap(element, true, learnFromType(apexType));
    }

    private Map<String, Object> toMap(Dom.XmlNode element, Boolean apexKeys, Map<String, Object> initializedFields) {
        Object value = this.convert(element, apexKeys, initializedFields);
        if (value instanceof Map<String, Object>) {
            return (Map<String, Object>) value;
        }
        return new Map<String, Object>{ TEXT_KEY => value };
    }

    private Object convert(Dom.XmlNode element, Boolean apexKeys, Map<String, Object> initializedFields) {
        Map<String, Object> fields = new Map<String, Object>();
        Boolean hasInitializedFields = !initializedFields.isEmpty();
        for (Dom.XmlNode child : element.getChildElements()) {
            String name = child.getName();
            String key = this.toKey(name, apexKeys);
            Boolean alwaysList = this.isListElement(name, key);
            Map<String, Object> nestedInitializedFields = NO_INITIALIZED_FIELDS;
            if (hasInitializedFields) {
                Object initializedField = getInitializedField(initializedFields, key);
                alwaysList = alwaysList || isListField(initializedField);
                nestedInitializedFields = getNestedInitializedFields(initializedField);
            }
            Object value = this.convert(child, apexKeys, nestedInitializedFields);
            this.add(fields, key, value, alwaysList);
        }
        for (Integer i = 0; i < element.getAttributeCount(); i++) {
            String namespace = element.getAttributeKeyNsAt(i);
            if (namespace == XSI_NAMESPACE) {
                continue;
            }
            String name = element.getAttributeKeyAt(i);
            String key = this.toKey(name, apexKeys);
            if (!fields.containsKey(key)) {
                fields.put(key, this.toValue(name, element.getAttributeValue(name, namespace)));
            }
        }
        String text = element.getText();
        if (fields.isEmpty()) {
            return this.toValue(element.getName(), text);
        }
        if (String.isNotBlank(text)) {
            fields.put(TEXT_KEY, this.toValue(element.getName(), text));
        }
        return fields;
    }

    private void add(Map<String, Object> fields, String key, Object value, Boolean alwaysList) {
        Object existing = fields.get(key);
        if (existing instanceof List<Object>) {
            ((List<Object>) existing).add(value);
        } else if (fields.containsKey(key)) {
            fields.put(key, new List<Object>{ existing, value });
        } else if (alwaysList) {
            fields.put(key, new List<Object>{ value });
        } else {
            fields.put(key, value);
        }
    }

    protected virtual String toKey(String name, Boolean apexKeys) {
        if (!apexKeys) {
            return name;
        }
        return name.replaceAll('[^A-Za-z0-9_]', '_').replaceAll('_+', '_').replaceAll('^_|_$', '');
    }

    // String == ignores case, so 'TRUE' must not become a Boolean
    protected virtual Object toValue(String name, String text) {
        if (String.isBlank(text)) {
            return null;
        }
        if (text.equals('true')) {
            return true;
        }
        if (text.equals('false')) {
            return false;
        }
        return text;
    }
}