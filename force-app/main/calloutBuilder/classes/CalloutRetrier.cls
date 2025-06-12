/**
* @description It tells the CalloutBuilder whether it should retry the callout.
*/
public interface CalloutRetrier {
    /**
    * @description shouldRetry
    * It may not only trigger retry but prepare for it, like by
    * refreshing auth token before new attempt.
    * @param  response
    * @return whether to retry
    */
    Boolean shouldRetry(HttpResponse response);
}
