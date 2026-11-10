/**
 * @description CalloutEndpointPattern parses an endpoint pattern such as /items/{id}/*, matches decoded callout
 * paths against it, captures their {name} values and ranks it against other patterns by specificity.
 * @team Laserburst
 */
public class CalloutEndpointPattern implements Comparable {
    private static final Pattern BLOCKED_CHARACTER = Pattern.compile('[/\\\\;%\\p{Cc}]');
    private static final String TRAILING_WILDCARD = '/*';

    // declared from least to most specific, because toRank() reads ordinal()
    private enum Rank {
        WILDCARD,
        ENDS, // a pattern that stops at this segment
        PARAMETER,
        LITERAL
    }

    private final String endpoint;
    private final List<Segment> segments = new List<Segment>();
    private final Set<String> parameterNames = new Set<String>();
    private final Boolean coversSubtree;

    public CalloutEndpointPattern(String endpoint) {
        if (endpoint?.startsWith('/') != true) {
            throw new CalloutBuilder.CalloutBuilderException('Endpoint pattern must start with "/"');
        }
        if (endpoint.containsAny('?#')) {
            throw new CalloutBuilder.CalloutBuilderException('Endpoint pattern must not contain "?" or "#"');
        }
        this.endpoint = endpoint;
        this.coversSubtree = endpoint.endsWith(TRAILING_WILDCARD);
        String prefix = endpoint.removeEnd(TRAILING_WILDCARD);
        if (prefix.contains('*')) {
            throw new CalloutBuilder.CalloutBuilderException(
                'Endpoint pattern may contain "*" only as a trailing "/*"'
            );
        }
        for (String text : this.toSegmentTexts(prefix)) {
            this.segments.add(this.toSegment(text));
        }
    }

    /**
     * @return the pattern as written
     */
    public String getEndpoint() {
        return this.endpoint;
    }

    /**
     * @param path decoded once and passed by the path rule; null is the empty path
     */
    public Boolean matches(String path) {
        return this.toParameters(path) != null;
    }

    /**
     * @return each {name} with the path segment it captured; null when the path doesn't match
     */
    public Map<String, String> toParameters(String path) {
        List<String> values = this.toSegmentTexts(path);
        if (!this.isMatchingDepth(values.size())) {
            return null;
        }
        Map<String, String> parameters = new Map<String, String>();
        for (Integer i = 0; i < this.segments.size(); i++) {
            Segment segment = this.segments.get(i);
            String value = values.get(i);
            if (!segment.matches(value)) {
                return null;
            }
            String name = segment.getParameterName();
            if (name != null) {
                parameters.put(name, value);
            }
        }
        return parameters;
    }

    public Boolean hasParameter(String name) {
        return this.parameterNames.contains(name);
    }

    /**
     * @description compareTo is negative when this pattern is more specific, so a sorted list starts with the
     * route that wins. The first segment whose Rank differs decides. Equally specific patterns return 0,
     * and null ranks last.
     */
    public Integer compareTo(Object other) {
        if (other == null) {
            return -1;
        }
        CalloutEndpointPattern otherPattern = (CalloutEndpointPattern) other;
        Integer depth = Math.max(this.segments.size(), otherPattern.segments.size());
        // the pass at i == depth compares how patterns with the same segments end
        for (Integer i = 0; i <= depth; i++) {
            Integer difference = otherPattern.toRank(i) - this.toRank(i);
            if (difference != 0) {
                return difference;
            }
        }
        return 0;
    }

    /**
     * @description isBlockedSegment is the path rule for one decoded segment: true when it is empty, "." or "..",
     * or contains "/", "\", ";", "%" or a control character
     */
    public static Boolean isBlockedSegment(String segment) {
        return String.isEmpty(segment)
            || segment == '.'
            || segment == '..'
            || BLOCKED_CHARACTER.matcher(segment).find();
    }

    // drops one trailing "/"; any other empty segment is kept, so isBlockedSegment() sees it
    private List<String> toSegmentTexts(String path) {
        String trimmed = path?.removeEnd('/');
        if (String.isEmpty(trimmed)) {
            return new List<String>();
        }
        return trimmed.removeStart('/').split('/', -1);
    }

    private Segment toSegment(String text) {
        if (this.isPlaceholder(text)) {
            String name = this.toPlaceholderName(text);
            if (!this.parameterNames.add(name)) {
                throw new CalloutBuilder.CalloutBuilderException(
                    'Endpoint pattern placeholder {' + name + '} is used twice'
                );
            }
            return new ParameterSegment(name);
        }
        if (text.containsAny('{}')) {
            throw new CalloutBuilder.CalloutBuilderException(
                'Endpoint pattern placeholder must be a whole {name} segment'
            );
        }
        // the path rule blocks such a segment in every path, so a pattern with one would never match
        // and its policy's checks would never run
        if (isBlockedSegment(text)) {
            throw new CalloutBuilder.CalloutBuilderException(
                'Endpoint pattern must not contain an empty or dot segment, "\\", ";", "%" or a control character'
            );
        }
        return new LiteralSegment(text);
    }

    private Boolean isPlaceholder(String text) {
        if (!text.startsWith('{') || !text.endsWith('}')) {
            return false;
        }
        String name = this.toPlaceholderName(text);
        return String.isNotBlank(name) && !name.containsAny('{}');
    }

    private String toPlaceholderName(String text) {
        return text.substring(1, text.length() - 1);
    }

    private Boolean isMatchingDepth(Integer depth) {
        return depth == this.segments.size() || (this.coversSubtree && depth > this.segments.size());
    }

    private Integer toRank(Integer index) {
        if (index < this.segments.size()) {
            return this.segments.get(index).getRank().ordinal();
        }
        if (index == this.segments.size() && this.coversSubtree) {
            return Rank.WILDCARD.ordinal();
        }
        return Rank.ENDS.ordinal();
    }

    private abstract class Segment {
        public abstract Rank getRank();

        public abstract Boolean matches(String value);

        public virtual String getParameterName() {
            return null;
        }
    }

    private class LiteralSegment extends Segment {
        private final String literal;

        public LiteralSegment(String literal) {
            this.literal = literal;
        }

        public override Rank getRank() {
            return Rank.LITERAL;
        }

        public override Boolean matches(String value) {
            return this.literal.equalsIgnoreCase(value);
        }
    }

    private class ParameterSegment extends Segment {
        private final String name;

        public ParameterSegment(String name) {
            this.name = name;
        }

        public override Rank getRank() {
            return Rank.PARAMETER;
        }

        // must accept any value: one that failed to match would skip its policy's checks,
        // so path parameter patterns check values instead
        public override Boolean matches(String value) {
            return String.isNotEmpty(value);
        }

        public override String getParameterName() {
            return this.name;
        }
    }
}