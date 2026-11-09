/**
* @description Strategy for a single transformation applied to a response after
* it is validated and before the caller sees it. Attach subclasses with
* CalloutBuilder.withResponseSanitizers().
* Each overload mutates its argument in place, or throws to block the response;
* an overload not overridden blocks. Do not execute the builder.
* @team Laserburst
*/
public abstract with sharing class CalloutResponseSanitizer {
    /**
     * @description receives an error response before CalloutBuilderException is built from it, so its message and
     * getError() come from the sanitized body; it gets error responses from every getter, blank and non-JSON bodies
     * included. A CalloutResponseSanitizerException withholds the error body, and the exception keeps its code and
     * status. Not overridden, it lets the error response through as is
     */
    public virtual void sanitizeError(HttpResponse response) {
    }

    public virtual void sanitize(HttpResponse response) {
        throw unsupported('HttpResponse');
    }

    public virtual void sanitize(Map<String, Object> body) {
        throw unsupported('Map<String, Object>');
    }

    public virtual void sanitize(Object body, System.Type successType) {
        throw unsupported(successType.getName());
    }

    public virtual void sanitize(Dom.Document body) {
        throw unsupported('Dom.Document');
    }

    private static CalloutResponseSanitizerException unsupported(String responseType) {
        return new CalloutResponseSanitizerException('Sanitizer does not support ' + responseType);
    }
}
