/**
 * @description Built-in guardrail: the request path must match at least one of
 * the configuration's allowedEndpointPatterns (defaults to "*", i.e. any path).
 * A pattern is a literal path in which "*" matches any run of characters,
 * including "/". The query string is not considered when matching. Paths
 * containing a ".." segment (raw or URL-encoded) are rejected outright, since
 * the server would resolve them outside the allowed URL space.
 * @team Laserburst
 */
public with sharing class ncMcp_EndpointGuardrail implements ncMcp_Guardrail {
    public void enforce(ncMcp_GuardedCalloutBuilder builder) {
        String path = builder.getPath();
        Integer queryStart = path.indexOf('?');
        if (queryStart >= 0) {
            path = path.substring(0, queryStart);
        }
        if (containsDotSegment(path)) {
            throw new ncMcp_Exception(
                'Path "' + path + '" contains a ".." segment, which is not allowed.'
            );
        }

        List<String> patterns = builder.getConfig().allowedEndpointPatterns;
        for (String pattern : patterns) {
            if (isMatch(pattern, path)) {
                return;
            }
        }
        throw new ncMcp_Exception(
            'Path "' +
                path +
                '" does not match any allowed endpoint pattern for "' +
                builder.getNamedCredential() +
                '". Allowed patterns: ' +
                String.join(patterns, ', ') +
                '.'
        );
    }

    private Boolean containsDotSegment(String path) {
        String decoded = path;
        try {
            decoded = EncodingUtil.urlDecode(path, 'UTF-8');
        } catch (Exception e) {
            // undecodable input cannot hide an encoded ".."; check it as-is
        }
        return ('/' + decoded + '/').contains('/../');
    }

    private Boolean isMatch(String pattern, String path) {
        return System.Pattern.matches('^' + toRegex(pattern) + '$', path);
    }

    private String toRegex(String pattern) {
        List<String> literals = new List<String>();
        for (String literal : pattern.split('\\*', -1)) {
            literals.add(System.Pattern.quote(literal));
        }
        return String.join(literals, '.*');
    }
}
