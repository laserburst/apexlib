/**
 * @description Composite CalloutResponseSanitizer: runs its sanitizers in the order added and stops at the first throw.
 * Attach one with CalloutBuilder.withResponseSanitizer() to reuse a set of sanitizers as one.
 * @team Laserburst
 */
public with sharing class CalloutResponseSanitizerChain extends CalloutResponseSanitizer {
    private final List<CalloutResponseSanitizer> sanitizers = new List<CalloutResponseSanitizer>();
    private Boolean running = false;

    @SuppressWarnings('PMD.ApexDoc')
    public CalloutResponseSanitizerChain add(CalloutResponseSanitizer sanitizer) {
        this.sanitizers.add(sanitizer);
        return this;
    }

    @SuppressWarnings('PMD.ApexDoc')
    public CalloutResponseSanitizerChain addAll(List<CalloutResponseSanitizer> sanitizers) {
        this.sanitizers.addAll(sanitizers);
        return this;
    }

    /**
     * @description true while a sanitize() overload runs, so a sanitizer that executes the builder can be rejected
     * before the request is sent
     */
    public Boolean isRunning() {
        return this.running;
    }

    @SuppressWarnings('PMD.ApexDoc')
    public override void sanitize(HttpResponse response) {
        this.running = true;
        try {
            for (CalloutResponseSanitizer sanitizer : this.sanitizers) {
                sanitizer.sanitize(response);
            }
        } finally {
            this.running = false;
        }
    }

    @SuppressWarnings('PMD.ApexDoc')
    public override void sanitize(Map<String, Object> body) {
        this.running = true;
        try {
            for (CalloutResponseSanitizer sanitizer : this.sanitizers) {
                sanitizer.sanitize(body);
            }
        } finally {
            this.running = false;
        }
    }

    @SuppressWarnings('PMD.ApexDoc')
    public override void sanitize(Object body, System.Type successType) {
        this.running = true;
        try {
            for (CalloutResponseSanitizer sanitizer : this.sanitizers) {
                sanitizer.sanitize(body, successType);
            }
        } finally {
            this.running = false;
        }
    }
}