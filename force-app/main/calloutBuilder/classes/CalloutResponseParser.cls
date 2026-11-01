/**
 * @description Strategy for turning a response body into a Map or an Apex type.
 * Extend it, CalloutJsonParser or CalloutXmlParser, and pass the parser to CalloutBuilder.withResponseParser().
 * @team Laserburst
 */
public abstract class CalloutResponseParser {
    public abstract Map<String, Object> deserializeUntyped(String body);

    public abstract Object deserialize(String body, System.Type apexType);

    /**
     * @description the parser for the response's Content-Type header, whose name is matched ignoring case
     */
    public static CalloutResponseParser forResponse(HttpResponse response) {
        for (String header : response.getHeaderKeys()) {
            if ('Content-Type'.equalsIgnoreCase(header)) {
                return forContentType(response.getHeader(header));
            }
        }
        return new CalloutJsonParser();
    }

    /**
     * @description CalloutXmlParser for an application/xml, text/xml or +xml media type,
     * CalloutJsonParser for any other Content-Type
     */
    public static CalloutResponseParser forContentType(String contentType) {
        if (!isJson(contentType) && isXml(contentType)) {
            return new CalloutXmlParser();
        }
        return new CalloutJsonParser();
    }

    // must run before isXml(): it handles a null contentType
    private static Boolean isJson(String contentType) {
        return contentType == null || contentType.startsWithIgnoreCase('application/json');
    }

    private static Boolean isXml(String contentType) {
        String mediaType = contentType.substringBefore(';').trim().toLowerCase();
        return mediaType == 'application/xml' || mediaType == 'text/xml' || mediaType.endsWith('+xml');
    }
}