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

    public virtual String getBodyString() {
        if (String.isNotBlank(this.stringBody)) {
            return this.stringBody;
        }
        return '';
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(this.statusCode);
        res = setHeaders(res);
        res = setBody(res);
        return res;
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