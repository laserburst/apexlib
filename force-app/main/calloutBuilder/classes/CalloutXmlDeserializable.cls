/**
 * @description Names the XML elements that become a List even when they occur once, at any depth,
 * for CalloutXmlParser.deserialize() into a success or error type. The type needs a no-argument constructor.
 * @team Laserburst
 */
public interface CalloutXmlDeserializable {
    Set<String> getListElements();
}