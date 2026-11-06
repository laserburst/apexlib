/**
 * @description An object that builds its own XML element. CalloutBuilder.withBody() sends it as XML.
 * @team Laserburst
 */
public interface CalloutXmlSerializable {
    CalloutXmlBuilder toXmlBuilder();
}