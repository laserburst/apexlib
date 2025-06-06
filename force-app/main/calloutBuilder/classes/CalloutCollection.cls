/**
* @description It is base behavior of CalloutBuilder instances in the CalloutBuilderQueueable.
* @team Laserburst
*/
public with sharing virtual class CalloutCollection {
    private List<CalloutBuilder> calloutBuilders;

    public CalloutCollection() {
    }

    public CalloutCollection(List<CalloutBuilder> initialBuilders) {
        this.calloutBuilders = new List<CalloutBuilder>();
        if (initialBuilders != null) {
            this.calloutBuilders.addAll(initialBuilders);
        }
    }

    public void add(CalloutBuilder cb) {
        if (this.calloutBuilders == null) {
            this.calloutBuilders = new List<CalloutBuilder>();
        }
        this.calloutBuilders.add(cb);
    }

    public Boolean isEmpty() {
        return this.calloutBuilders == null || this.calloutBuilders?.isEmpty();
    }

    public void executeNext() {
        HttpResponse response = this.call();
        this.postProcess(response);
    }

    public virtual void prepare() {
    }

    private HttpResponse call() {
        return this.next()?.getHttpResponse();
    }

    private CalloutBuilder next() {
        if (this.isEmpty()) {
            return null;
        }
        return this.calloutBuilders.remove(0);
    }

    protected virtual void postProcess(HttpResponse response) {
    }
}
