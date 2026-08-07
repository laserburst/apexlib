/**
* @description CalloutResponseSanitizer removing JSON nodes matched by criteria.
* Each criteria key is a bracket path (results[folder][id]); the value marks a
* node as restricted — a scalar by equality, a List by matching any element.
* A match removes the nearest enclosing list item, or the leaf property when
* the path crosses no list. Attach with CalloutBuilder.withResponseSanitizer().
* @team Laserburst
*/
public with sharing class CalloutJsonPathSanitizer implements CalloutResponseSanitizer {
    /**
    * @description How multiple criteria entries combine: ANY_ENTRY removes a target
    * matched by at least one entry, ALL_ENTRIES only a target matched by every entry.
    */
    public enum Match {
        ANY_ENTRY,
        ALL_ENTRIES
    }

    private Map<String, Object> criteria;
    private Map<String, List<String>> segmentsByPath = new Map<String, List<String>>();
    private Match combineMode;

    /**
    * @description Sanitizer removing everything matched by any criteria entry.
    * @param sanitizeCriteria bracket path => restricted value, or List of values meaning any-of
    */
    public CalloutJsonPathSanitizer(Map<String, Object> sanitizeCriteria) {
        this(sanitizeCriteria, Match.ANY_ENTRY);
    }

    /**
    * @description Sanitizer with an explicit combining mode for the criteria entries.
    * @param sanitizeCriteria bracket path => restricted value, or List of values meaning any-of
    * @param combineMode Match.ANY_ENTRY or Match.ALL_ENTRIES
    */
    public CalloutJsonPathSanitizer(Map<String, Object> sanitizeCriteria, Match combineMode) {
        if (sanitizeCriteria == null || sanitizeCriteria.isEmpty()) {
            throw new IllegalArgumentException('sanitizeCriteria must contain at least one path.');
        }
        for (String path : sanitizeCriteria.keySet()) {
            if (String.isBlank(path)) {
                throw new IllegalArgumentException('Criteria paths must not be blank.');
            }
            // the -1 limit keeps trailing empty segments, so 'results[]' is rejected below
            List<String> segments = path.replace(']', '').split('\\[', -1);
            for (String segment : segments) {
                if (String.isBlank(segment)) {
                    throw new IllegalArgumentException('Invalid criteria path: ' + path);
                }
            }
            this.segmentsByPath.put(path, segments);
        }
        this.criteria = sanitizeCriteria;
        this.combineMode = combineMode == null ? Match.ANY_ENTRY : combineMode;
    }

    /**
    * @description Removes every matched target and rewrites the body in place.
    * @param response the validated response about to be returned; its body must
    * be JSON, anything else throws CalloutResponseSanitizerException
    */
    public void sanitize(HttpResponse response) {
        Object root;
        try {
            root = JSON.deserializeUntyped(response.getBody());
        } catch (Exception e) {
            throw new CalloutResponseSanitizerException('Cannot sanitize a non-JSON response body: ' + e.getMessage());
        }
        Map<String, List<String>> targets = new Map<String, List<String>>();
        Map<String, Integer> matchedEntries = new Map<String, Integer>();
        for (String path : this.segmentsByPath.keySet()) {
            Map<String, List<String>> entryTargets = new Map<String, List<String>>();
            this.collectTargets(root, new List<String>(), null, this.segmentsByPath.get(path), 0, this.criteria.get(path), entryTargets);
            for (String key : entryTargets.keySet()) {
                targets.put(key, entryTargets.get(key));
                Integer count = matchedEntries.get(key);
                matchedEntries.put(key, count == null ? 1 : count + 1);
            }
        }
        List<List<String>> toRemove = new List<List<String>>();
        for (String key : targets.keySet()) {
            if (this.combineMode == Match.ANY_ENTRY || matchedEntries.get(key) == this.criteria.size()) {
                toRemove.add(targets.get(key));
            }
        }
        this.removeTargets(root, toRemove);
        response.setBody(JSON.serialize(root));
    }

    private void collectTargets(
        Object node,
        List<String> concrete,
        Integer listItemDepth,
        List<String> segments,
        Integer segmentIndex,
        Object restrictedValue,
        Map<String, List<String>> targets
    ) {
        if (segmentIndex == segments.size()) {
            if (this.isRestricted(node, restrictedValue)) {
                // the removal target is the innermost list item on the path, or the leaf itself
                Integer depth = listItemDepth == null ? concrete.size() : listItemDepth;
                List<String> target = new List<String>();
                for (Integer i = 0; i < depth; i++) {
                    target.add(concrete[i]);
                }
                targets.put(String.join(target, '\n'), target);
            }
            return;
        }
        String segment = segments[segmentIndex];
        if (node instanceof List<Object>) {
            List<Object> items = (List<Object>) node;
            if (segment.isNumeric()) {
                Integer index = Integer.valueOf(segment);
                if (index < items.size()) {
                    concrete.add(segment);
                    this.collectTargets(items[index], concrete, concrete.size(), segments, segmentIndex + 1, restrictedValue, targets);
                    concrete.remove(concrete.size() - 1);
                }
                return;
            }
            // non-numeric segment on a list: apply it to every element
            for (Integer i = 0; i < items.size(); i++) {
                concrete.add(String.valueOf(i));
                this.collectTargets(items[i], concrete, concrete.size(), segments, segmentIndex, restrictedValue, targets);
                concrete.remove(concrete.size() - 1);
            }
            return;
        }
        if (node instanceof Map<String, Object> && ((Map<String, Object>) node).containsKey(segment)) {
            concrete.add(segment);
            this.collectTargets(((Map<String, Object>) node).get(segment), concrete, listItemDepth, segments, segmentIndex + 1, restrictedValue, targets);
            concrete.remove(concrete.size() - 1);
        }
    }

    private Boolean isRestricted(Object node, Object restrictedValue) {
        if (restrictedValue instanceof List<Object>) {
            for (Object value : (List<Object>) restrictedValue) {
                if (this.valueMatches(node, value)) {
                    return true;
                }
            }
            return false;
        }
        return this.valueMatches(node, restrictedValue);
    }

    private Boolean valueMatches(Object node, Object value) {
        // equals() keeps String comparison case-sensitive, unlike ==
        if (node instanceof String && value instanceof String) {
            return ((String) node).equals((String) value);
        }
        return node == value;
    }

    private void removeTargets(Object root, List<List<String>> targets) {
        List<List<String>> survivors = new List<List<String>>();
        for (List<String> target : targets) {
            if (!this.hasPrefixIn(target, targets)) {
                survivors.add(target);
            }
        }
        // descending order so a removal never shifts the index of a later target
        survivors.sort(new DescendingPathOrder());
        for (List<String> target : survivors) {
            this.removeTarget(root, target);
        }
    }

    private Boolean hasPrefixIn(List<String> target, List<List<String>> targets) {
        for (List<String> other : targets) {
            if (other.size() < target.size() && this.isPrefix(other, target)) {
                return true;
            }
        }
        return false;
    }

    private Boolean isPrefix(List<String> prefix, List<String> target) {
        for (Integer i = 0; i < prefix.size(); i++) {
            if (!prefix[i].equals(target[i])) {
                return false;
            }
        }
        return true;
    }

    private void removeTarget(Object root, List<String> target) {
        Object node = root;
        for (Integer i = 0; i < target.size() - 1; i++) {
            node = this.stepInto(node, target[i]);
        }
        String leaf = target[target.size() - 1];
        if (node instanceof List<Object>) {
            ((List<Object>) node).remove(Integer.valueOf(leaf));
        } else if (node instanceof Map<String, Object>) {
            ((Map<String, Object>) node).remove(leaf);
        }
    }

    private Object stepInto(Object node, String segment) {
        if (node instanceof List<Object>) {
            return ((List<Object>) node)[Integer.valueOf(segment)];
        }
        if (node instanceof Map<String, Object>) {
            return ((Map<String, Object>) node).get(segment);
        }
        return null;
    }

    private class DescendingPathOrder implements Comparator<List<String>> {
        public Integer compare(List<String> first, List<String> second) {
            Integer size = Math.min(first.size(), second.size());
            for (Integer i = 0; i < size; i++) {
                Integer diff;
                if (first[i].isNumeric() && second[i].isNumeric()) {
                    diff = Integer.valueOf(second[i]) - Integer.valueOf(first[i]);
                } else {
                    diff = second[i].compareTo(first[i]);
                }
                if (diff != 0) {
                    return diff;
                }
            }
            return second.size() - first.size();
        }
    }
}
