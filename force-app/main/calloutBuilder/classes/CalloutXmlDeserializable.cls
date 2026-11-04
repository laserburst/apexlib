/**
 * @description Names the elements that become a List even when they occur once, by XML name or Apex field name,
 * matching case, at any depth. CalloutXmlParser.deserialize() asks a new instance of the type it deserializes into,
 * such as a success or error type, so that type needs a no-argument constructor; nested types aren't asked.
 * @team Laserburst
 */
public interface CalloutXmlDeserializable {
    Set<String> getListElements();
}