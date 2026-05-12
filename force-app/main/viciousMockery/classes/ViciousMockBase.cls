public with sharing virtual class ViciousMockBase implements HttpCalloutMock {
    protected Integer statusCode = 200;

    protected String jsonResponse;
    protected Blob blobResponse;

    protected Map<String,String> headers = new Map<String,String> {
        'Content-Type' => 'application/json'
    }; 

    public virtual String constructBody() {
        if (String.isNotBlank(this.jsonResponse)) {
            return this.jsonResponse;
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
        String body = this.constructBody();
        if (String.isNotBlank(body)) {
            res.setBody(body);
        } else if (this.blobResponse != null) {
            res.setBodyAsBlob(this.blobResponse);
        }
        return res;
    }
}