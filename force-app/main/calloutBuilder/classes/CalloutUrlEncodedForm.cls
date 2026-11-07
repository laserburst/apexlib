/**
 * @description CalloutUrlEncodedForm is a Map or an object written as application/x-www-form-urlencoded fields:
 * a nested field as name[key] and a List item as name[index]
 * @team Laserburst
 */
public class CalloutUrlEncodedForm {
    private static final String ENCODING = 'UTF-8';

    private final List<String> fields = new List<String>();

    /**
     * @description a value takes its JSON form, such as a Datetime in ISO 8601, and field order isn't kept;
     * a null is left out, since a form has no null, and '' sends an empty value
     * @param body a Map or an object; anything else throws CalloutBuilderException
     */
    public CalloutUrlEncodedForm(Object body) {
        Object untypedBody = JSON.deserializeUntyped(JSON.serialize(body));
        if (!(untypedBody instanceof Map<String, Object>)) {
            throw new CalloutBuilder.CalloutBuilderException('A form body must be a Map or an object');
        }
        Map<String, Object> fieldValues = (Map<String, Object>) untypedBody;
        for (String key : fieldValues.keySet()) {
            this.addField(key, fieldValues.get(key));
        }
    }

    /**
     * @description a null value is left out
     */
    public CalloutUrlEncodedForm(Map<String, String> fieldValues) {
        for (String key : fieldValues.keySet()) {
            this.addField(key, fieldValues.get(key));
        }
    }

    public override String toString() {
        return String.join(this.fields, '&');
    }

    private void addField(String name, Object value) {
        if (value instanceof Map<String, Object>) {
            this.addNestedFields(name, (Map<String, Object>) value);
        } else if (value instanceof List<Object>) {
            this.addListItems(name, (List<Object>) value);
        } else if (value != null) {
            String encodedName = EncodingUtil.urlEncode(name, ENCODING);
            String encodedValue = EncodingUtil.urlEncode(this.toText(value), ENCODING);
            this.fields.add(encodedName + '=' + encodedValue);
        }
    }

    private void addNestedFields(String name, Map<String, Object> values) {
        for (String key : values.keySet()) {
            this.addField(name + '[' + key + ']', values.get(key));
        }
    }

    // an index counts only items that write a field, so a null item leaves no gap
    private void addListItems(String name, List<Object> items) {
        Integer index = 0;
        for (Object item : items) {
            Integer fieldCount = this.fields.size();
            this.addField(name + '[' + index + ']', item);
            if (this.fields.size() > fieldCount) {
                index++;
            }
        }
    }

    // String.valueOf() can write a Decimal in scientific notation, such as 1E-7
    private String toText(Object value) {
        if (value instanceof Decimal) {
            return ((Decimal) value).toPlainString();
        }
        return String.valueOf(value);
    }
}