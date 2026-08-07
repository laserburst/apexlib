/**
* @description Strategy for a single transformation applied to a response after
* it is validated and before the caller sees it. Attach implementations with
* CalloutBuilder.withResponseSanitizers().
* @team Laserburst
*/
public interface CalloutResponseSanitizer {
    /**
    * @description Rewrite the response in place with setBody() or
    * setBodyAsBlob(), or throw to block it entirely.
    * Do not execute the builder.
    * @param response the validated response about to be returned
    */
    void sanitize(HttpResponse response);
}
