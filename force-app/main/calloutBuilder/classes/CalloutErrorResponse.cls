/**
* @description It's to unify error handling in response bodies.
* @team Laserburst
*/
public interface CalloutErrorResponse {
    /**
    * @description getErrorMessage extracts error message
    * from error object of the callout response
    */
    String getErrorMessage();
}