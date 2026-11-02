/**
 * @description Use case: POST callout with a file of up to about 5 Mb in the body.
 * It supports adding parameters.
 * Many thanks to Nicolas Bruno for original version:
 * https://github.com/nicolas1bruno/multipart-data-apex-request
 * @team Laserburst
 */
public class CalloutHexFormBuilder {
    private static final String BOUNDARY = '----sf-multi-form';
    private List<String> hexParts = new List<String>();

    public static CalloutHexFormBuilder build() {
        return new CalloutHexFormBuilder();
    }

    public static String getContentType() {
        return 'multipart/form-data; boundary="' + BOUNDARY + '"';
    }

    private String footer() {
        return EncodingUtil.convertToHex(Blob.valueOf('--' + BOUNDARY + '--'));
    }

    public CalloutHexFormBuilder writeParameter(String key, String value) {
        String body = '--' + BOUNDARY;
        body += '\r\nContent-Disposition: form-data; name="' + key + '"\r\n\r\n' + value + '\r\n';

        this.hexParts.add(EncodingUtil.convertToHex(Blob.valueOf(body)));
        return this;
    }

    public CalloutHexFormBuilder writeParameters(Map<String, String> parameters) {
        if (parameters == null || parameters?.isEmpty()) {
            return this;
        }
        for (String key : parameters.keySet()) {
            this.writeParameter(key, parameters.get(key));
        }
        return this;
    }

    public CalloutHexFormBuilder writeJsonParameter(String key, String value) {
        String body = '--' + BOUNDARY;
        body += '\r\nContent-Disposition: form-data; name="' + key + '"; filename="blob"';
        body += '\r\nContent-Type: application/json';
        body += '\r\n\r\n' + value + '\r\n';
        this.hexParts.add(EncodingUtil.convertToHex(Blob.valueOf(body)));
        return this;
    }

    public CalloutHexFormBuilder writeJsonParameters(Map<String, String> parameters) {
        if (parameters == null || parameters?.isEmpty()) {
            return this;
        }
        for (String key : parameters.keySet()) {
            this.writeJsonParameter(key, parameters.get(key));
        }
        return this;
    }

    public CalloutHexFormBuilder writeFile(String fileName, Blob fileContent) {
        return this.writeHexFile('file', fileName, EncodingUtil.convertToHex(fileContent));
    }

    public CalloutHexFormBuilder writeFile(String fileName, String fileContent) {
        return this.writeFile('file', fileName, fileContent);
    }

    public CalloutHexFormBuilder writeFile(String key, String fileName, String fileContent) {
        return this.writeHexFile(key, fileName, EncodingUtil.convertToHex(EncodingUtil.base64Decode(fileContent)));
    }

    private CalloutHexFormBuilder writeHexFile(String key, String fileName, String hexContent) {
        String header = '--' + BOUNDARY;
        header +=
            '\r\nContent-Disposition: form-data; name="'
            + key
            + '"; filename="'
            + fileName
            + '"\r\nContent-Type: '
            + MimeType.getByFileNameWithExtension(fileName)
            + '\r\n\r\n';

        this.hexParts.add(EncodingUtil.convertToHex(Blob.valueOf(header)));
        this.hexParts.add(hexContent);
        this.hexParts.add(EncodingUtil.convertToHex(Blob.valueOf('\r\n')));
        return this;
    }

    public String getFormAsString() {
        // joined, not concatenated: + copies the body and throws above 10,000,000 characters
        List<String> parts = this.hexParts.clone();
        parts.add(this.footer());
        return String.join(parts, '');
    }

    public Blob getFormAsBlob() {
        return EncodingUtil.convertFromHex(this.getFormAsString());
    }
}