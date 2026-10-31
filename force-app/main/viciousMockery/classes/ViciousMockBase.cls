/**
 * @description Base class for HttpCalloutMock implementations
 */
public with sharing virtual class ViciousMockBase implements HttpCalloutMock {
    protected Integer statusCode = 200;

    protected String stringBody;
    protected Blob blobBody;

    protected Map<String,String> headers = new Map<String,String> {
        'Content-Type' => 'application/json'
    };

    private final List<HttpRequest> requests = new List<HttpRequest>();

    public virtual String getBodyString() {
        if (String.isNotBlank(this.stringBody)) {
            return this.stringBody;
        }
        return '';
    }

    // not virtual: every answered request is recorded
    public HTTPResponse respond(HTTPRequest req) {
        this.requests.add(req);
        return this.buildResponse(req);
    }

    /**
     * @description buildResponse answers one request; override it to answer from the request
     */
    protected virtual HttpResponse buildResponse(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(this.statusCode);
        res = setHeaders(res);
        res = setBody(res);
        return res;
    }

    /**
     * @description getRequests returns the answered requests in call order
     */
    public List<HttpRequest> getRequests() {
        return new List<HttpRequest>(this.requests);
    }

    /**
     * @description getLastRequest returns null when the mock was never called
     */
    public HttpRequest getLastRequest() {
        if (this.requests.isEmpty()) {
            return null;
        }
        return this.requests[this.requests.size() - 1];
    }

    private HTTPResponse setHeaders(HttpResponse res) {
        for (String header : headers.keySet()) {
            res.setHeader(header, headers.get(header));
        }
        return res;
    }

    private HTTPResponse setBody(HttpResponse res) {
        String body = this.getBodyString();
        if (String.isNotBlank(body)) {
            res.setBody(body);
        } else if (this.blobBody != null) {
            res.setBodyAsBlob(this.blobBody);
        }
        return res;
    }
}