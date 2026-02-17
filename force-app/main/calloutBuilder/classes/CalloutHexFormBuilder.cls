/**
 * @description Use case: POST callout with about 2 Mb file in the body. 
 * It supports adding parameters.
 * Many thanks to Nicolas Bruno for original version:
 * https://github.com/nicolas1bruno/multipart-data-apex-request
 * @team Laserburst
 */
public class CalloutHexFormBuilder {
    private static final String BOUNDARY = '----sf-multi-form';
    private String form = '';

    public static CalloutHexFormBuilder build() {
        return new CalloutHexFormBuilder();
    }

    public static String getContentType() {
        return 'multipart/form-data; boundary="' + BOUNDARY + '"';
    }

    private CalloutHexFormBuilder writeFooter() {
        this.form += EncodingUtil.convertToHex(Blob.valueOf('--' + boundary + '--'));
        return this;
    }

    public CalloutHexFormBuilder writeParameter(String key, String value) {
        String body = '--' + BOUNDARY;
        body += '\r\nContent-Disposition: form-data; name="' + key + '";\r\n\r\n' + value + '\r\n';

        this.form += EncodingUtil.convertToHex(Blob.valueOf(body));
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

    public CalloutHexFormBuilder writeFile(String fileName, String fileContent) {
        return this.writeFile('file', fileName, fileContent);
    }

    public CalloutHexFormBuilder writeFile(String key, String fileName, String fileContent) {
        String content = '--' + BOUNDARY;
        content +=
            '\r\nContent-Disposition: form-data; name="'
            + key
            + '"; filename="'
            + fileName
            + '";\r\nContent-Type: '
            + MimeType.getByFileNameWithExtension(fileName)
            + ';\r\n\r\n';
        content = EncodingUtil.convertToHex(Blob.valueOf(content));

        content += EncodingUtil.convertToHex(EncodingUtil.base64Decode(fileContent));
        content += EncodingUtil.convertToHex(Blob.valueOf('\r\n'));

        this.form += content;
        return this;
    }

    public String getFormAsString() {
        this.writeFooter();
        return this.form;
    }

    public Blob getFormAsBlob() {
        return EncodingUtil.convertFromHex(this.getFormAsString());
    }
}
