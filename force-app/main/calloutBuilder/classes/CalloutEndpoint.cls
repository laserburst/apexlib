/**
 * @description CalloutEndpoint is the URL part after the base URL: a template with {name}
 * placeholders and the path parameters that fill them.
 * @team Laserburst
 */
public class CalloutEndpoint {
    private static final String ENCODING = 'UTF-8';

    private String template;
    private Map<String, String> parameters = new Map<String, String>();

    public void setTemplate(String endpoint) {
        if (String.isBlank(endpoint)) {
            this.template = endpoint;
            return;
        }
        if (!endpoint.startsWith('?')) {
            endpoint = '/' + endpoint.replaceFirst('^/+', '');
        }
        if (endpoint.contains('#')) {
            throw new CalloutBuilder.CalloutBuilderException('Endpoint must not contain "#"');
        }
        String path = endpoint.substringBefore('?');
        if (path.contains('\\')) {
            throw new CalloutBuilder.CalloutBuilderException('Endpoint path must not contain "\\"');
        }
        if (hasDotSegment(path)) {
            throw new CalloutBuilder.CalloutBuilderException('Endpoint must not contain "." or ".." path segments');
        }
        this.template = endpoint;
    }

    public void putParameter(String name, String value) {
        if (String.isBlank(name)) {
            throw new CalloutBuilder.CalloutBuilderException('Path parameter name must be provided');
        }
        if (name.containsAny('{}/?')) {
            throw new CalloutBuilder.CalloutBuilderException(
                'Path parameter name must not contain "{", "}", "/" or "?"'
            );
        }
        if (String.isBlank(value)) {
            throw new CalloutBuilder.CalloutBuilderException('Path parameter "' + name + '" must have a value');
        }
        if (value == '.' || value == '..') {
            throw new CalloutBuilder.CalloutBuilderException('Path parameter "' + name + '" must not be "." or ".."');
        }
        this.parameters.put(name, value);
    }

    public Map<String, String> getParameters() {
        return new Map<String, String>(this.parameters);
    }

    public String resolve() {
        if (this.template == null && this.parameters.isEmpty()) {
            return null;
        }
        String resolved = this.template ?? '';
        for (String name : this.parameters.keySet()) {
            String placeholder = '{' + name + '}';
            if (!resolved.contains(placeholder)) {
                throw new CalloutBuilder.CalloutBuilderException(
                    'Path parameter "' + name + '" has no ' + placeholder + ' placeholder in the endpoint'
                );
            }
            resolved = resolved.replace(placeholder, encodePathSegment(this.parameters.get(name)));
        }
        if (resolved.containsAny('{}')) {
            throw new CalloutBuilder.CalloutBuilderException(
                'Endpoint has a placeholder without a path parameter: ' + this.template
            );
        }
        return resolved;
    }

    public String joinTo(String baseUrl) {
        String resolved = this.resolve();
        if (String.isBlank(resolved)) {
            return baseUrl;
        }
        if (resolved.startsWith('/')) {
            return baseUrl?.removeEnd('/') + resolved;
        }
        return baseUrl + resolved;
    }

    private static String encodePathSegment(String value) {
        // '~' is unreserved and must not be encoded (RFC 3986 2.3);
        // '!' stays raw: servers need not treat %21 as '!' (RFC 3986 sub-delimiter)
        return EncodingUtil.urlEncode(value, ENCODING).replace('+', '%20').replace('%21', '!').replace('%7E', '~');
    }

    private static Boolean hasDotSegment(String path) {
        for (String segment : path.split('/')) {
            String name = segment.substringBefore(';').toLowerCase().replace('%2e', '.');
            if (name == '.' || name == '..') {
                return true;
            }
        }
        return false;
    }
}