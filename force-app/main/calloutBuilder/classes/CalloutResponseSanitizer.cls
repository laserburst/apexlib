/**
* @description Strategy for a single transformation applied to a response after
* it is validated and before the caller sees it. Attach subclasses with
* CalloutBuilder.withResponseSanitizers().
* Each overload mutates its argument in place, or throws to block the response;
* an overload not overridden blocks. Do not execute the builder.
* @team Laserburst
*/
public abstract with sharing class CalloutResponseSanitizer {
    @SuppressWarnings('PMD.ApexDoc')
    public virtual void sanitize(HttpResponse response) {
        throw unsupported('HttpResponse');
    }

    @SuppressWarnings('PMD.ApexDoc')
    public virtual void sanitize(Map<String, Object> body) {
        throw unsupported('Map<String, Object>');
    }

    @SuppressWarnings('PMD.ApexDoc')
    public virtual void sanitize(Object body, System.Type successType) {
        throw unsupported(successType.getName());
    }

    @SuppressWarnings('PMD.ApexDoc')
    public virtual void sanitize(Dom.Document body) {
        throw unsupported('Dom.Document');
    }

    private static CalloutResponseSanitizerException unsupported(String responseType) {
        return new CalloutResponseSanitizerException('Sanitizer does not support ' + responseType);
    }
}
