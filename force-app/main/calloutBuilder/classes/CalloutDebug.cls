/**
 * @description Writes a request and its response to the debug log for CalloutBuilder.withDebugMode(true).
 * A body with a non-text Content-Type is skipped; Content-Type header names are matched ignoring case.
 * @team Laserburst
 */
public with sharing class CalloutDebug {
    // afmt:ignore
    private static final Set<String> TEXT_CONTENT_TYPES = new Set<String>{
        'application/json',
        'application/xml',
        'text/xml',
        'text/plain',
        'text/html',
        '+json',
        '+xml'
    };

    /**
     * @description headers are the ones set on the builder; a default Content-Type is read from the request
     */
    public static void log(HttpRequest request, Map<String, String> headers) {
        String contentType = request.getHeader('Content-Type') ?? getContentType(headers);
        write('-- Request debug start --');
        write('Request endpoint: ' + request.getEndpoint());
        write('Request method: ' + request.getMethod());
        if (isText(contentType)) {
            write('Request body: \n' + request.getBody());
        } else {
            write('Skip verbose request body debugging. Content-Type: ' + contentType);
        }
        writeHeaders('Request', headers);
        write('-- Request debug end --');
    }

    @SuppressWarnings('PMD.ApexDoc')
    public static void log(HttpResponse response) {
        Map<String, String> headers = new Map<String, String>();
        for (String header : response.getHeaderKeys()) {
            headers.put(header, response.getHeader(header));
        }
        String contentType = getContentType(headers);
        write('-- Response debug start --');
        write('Response status code: ' + response.getStatusCode());
        write('Response status: ' + response.getStatus());
        if (isText(contentType)) {
            write('Response body: \n' + response.getBody());
        } else {
            write('Skip verbose response body debugging. Content-Type: ' + contentType);
        }
        writeHeaders('Response', headers);
        write('-- Response debug end --');
    }

    private static void writeHeaders(String label, Map<String, String> headers) {
        write(label + ' headers size: ' + headers.size());
        for (String header : headers.keySet()) {
            write(label + ' header: ' + header + ': ' + headers.get(header));
        }
    }

    private static String getContentType(Map<String, String> headers) {
        for (String header : headers.keySet()) {
            if ('Content-Type'.equalsIgnoreCase(header)) {
                return headers.get(header);
            }
        }
        return null;
    }

    private static Boolean isText(String contentType) {
        if (contentType == null) {
            return true;
        }
        String lowerCaseType = contentType.toLowerCase();
        if (TEXT_CONTENT_TYPES.contains(lowerCaseType)) {
            return true;
        }
        for (String textType : TEXT_CONTENT_TYPES) {
            if (lowerCaseType.contains(textType)) {
                return true;
            }
        }
        return false;
    }

    private static void write(String line) {
        System.debug(LoggingLevel.DEBUG, 'CalloutBuilder: ' + line);
    }
}