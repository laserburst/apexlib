/**
 * @description The parser for JSON bodies, and the default for a response without an XML Content-Type.
 * @team Laserburst
 */
public virtual class CalloutJsonParser extends CalloutResponseParser {
    public virtual override Map<String, Object> deserializeUntyped(String body) {
        return (Map<String, Object>) JSON.deserializeUntyped(body);
    }

    public virtual override Object deserialize(String body, System.Type apexType) {
        return JSON.deserialize(body, apexType);
    }
}