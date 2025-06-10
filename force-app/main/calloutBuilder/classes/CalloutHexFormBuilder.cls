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

    public static final Map<String, String> IMAGE_EXTENSION_TO_MIME_TYPE =
        new Map<String, String>{
            'png' => 'image/png',
            'jpeg' => 'image/jpg',
            'jpg' => 'image/jpg',
            'pgm' => 'image/x-portable-graymap',
            'ppm' => 'image/x-portable-pixmap'
        };

    public static final Map<String, String> DOCUMENT_EXTENSION_TO_MIME_TYPE =
        new Map<String, String>{
            'pdf' => 'application/pdf',
            'txt' => 'text/plain',
            'doc' => 'application/msword',
            'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'html' => 'text/html',
            'json' => 'application/json',
            'md' => 'text/markdown',
            'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
        };

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

    public CalloutHexFormBuilder writeParam(String key, String value) {
        String body = '--' + BOUNDARY;
        body += '\r\nContent-Disposition: form-data; name="' + key + '";\r\n\r\n' + value + '\r\n';

        this.form += EncodingUtil.convertToHex(Blob.valueOf(body));
        return this;
    }

    public CalloutHexFormBuilder writeFile(String key, String fileName, String fileContent) {
        String mimeType = resolveMimeType(fileName);

        String content = '--' + BOUNDARY;
        content +=
            '\r\nContent-Disposition: form-data; name="'
            + key
            + '"; filename="'
            + fileName
            + '";\r\nContent-Type: '
            + mimeType
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

    @TestVisible
    private static String resolveMimeType(String fileName) {
        String fileExtension = fileName?.subStringAfterLast('.')?.toLowerCase();
        if (String.isBlank(fileExtension)) {
            throw new IllegalArgumentException('File name contains no extension: ' + fileName);
        }
        if (IMAGE_EXTENSION_TO_MIME_TYPE.containsKey(fileExtension)) {
            return IMAGE_EXTENSION_TO_MIME_TYPE.get(fileExtension);
        }
        if (DOCUMENT_EXTENSION_TO_MIME_TYPE.containsKey(fileExtension)) {
            return DOCUMENT_EXTENSION_TO_MIME_TYPE.get(fileExtension);
        }
        throw new IllegalArgumentException('Not supported file: ' + fileName);
    }
}
