/**
 * @description CalloutBody is the object a callout sends as its body: a Blob as it is, a Dom.Document or
 * CalloutXmlSerializable as XML, and any other value as text by Content-Type: a String as-is, form fields or JSON
 * @team Laserburst
 */
public class CalloutBody {
    public Boolean suppressApexObjectNulls = false;

    private Object value;
    private Boolean hasBlobValue = false;

    public void setValue(Object value) {
        this.value = value;
    }

    public void setBlobValue(Object value) {
        this.hasBlobValue = true;
        this.value = value;
    }

    public Object getValue() {
        return this.value;
    }

    public Boolean isEmpty() {
        return this.value == null;
    }

    public Boolean isBlob() {
        return this.hasBlobValue && this.value != null;
    }

    public Blob toBlob() {
        return (Blob) this.value;
    }

    /**
     * @description toText returns the String sent for the value: XML for a Dom.Document or CalloutXmlSerializable,
     * otherwise a String as-is, form fields or JSON by Content-Type; null for a Blob or no value
     * @param contentType the Content-Type header, or null when none is set, which means JSON
     */
    public String toText(String contentType) {
        if (this.isEmpty() || this.isBlob()) {
            return null;
        }
        if (this.isXml()) {
            return this.toXml();
        }
        String mediaType = this.toMediaType(contentType);
        if (this.value instanceof String && !this.isJson(mediaType)) {
            return (String) this.value;
        }
        if (this.isForm(mediaType)) {
            return new CalloutUrlEncodedForm(this.value).toString();
        }
        return JSON.serialize(this.value, this.suppressApexObjectNulls);
    }

    /**
     * @description getDefaultContentType returns the Content-Type for a request that sets none: binary for a Blob,
     * XML for a Dom.Document or CalloutXmlSerializable, JSON for any other value, and null without a value
     */
    public String getDefaultContentType() {
        if (this.isBlob()) {
            return 'application/octet-stream';
        }
        if (this.isXml()) {
            return 'application/xml';
        }
        if (this.isEmpty()) {
            return null;
        }
        return 'application/json';
    }

    private Boolean isXml() {
        return this.value instanceof Dom.Document || this.value instanceof CalloutXmlSerializable;
    }

    private String toXml() {
        if (this.value instanceof Dom.Document) {
            return ((Dom.Document) this.value).toXmlString();
        }
        return ((CalloutXmlSerializable) this.value).toXmlBuilder().toXmlString();
    }

    private String toMediaType(String contentType) {
        return contentType?.substringBefore(';').trim().toLowerCase();
    }

    // no Content-Type means JSON
    private Boolean isJson(String mediaType) {
        return mediaType == null || mediaType == 'application/json' || mediaType.endsWith('+json');
    }

    private Boolean isForm(String mediaType) {
        return mediaType == 'application/x-www-form-urlencoded';
    }
}