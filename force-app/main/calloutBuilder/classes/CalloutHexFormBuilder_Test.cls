@IsTest
private with sharing class CalloutHexFormBuilder_Test {
    @isTest
    static void testFormDataBuild() {
        String fileName = 'file.png';
        String fileContent = '';

        Test.startTest();
        Blob formData =
            CalloutHexFormBuilder.build()
                .writeParameters(new Map<String, String>{ 'id' => '123', 'message' => 'second parameter' })
                .writeFile(fileName, fileContent)
                .getFormAsBlob();
        Test.stopTest();

        String expectedFormData =
            '------sf-multi-form\r\nContent-Disposition: form-data; name="id";\r\n\r\n123\r\n------sf-multi-form\r\nContent-Disposition: form-data; name="message";\r\n\r\nsecond parameter\r\n------sf-multi-form\r\nContent-Disposition: form-data; name="file"; filename="file.png";\r\nContent-Type: image/png;\r\n\r\n\r\n------sf-multi-form--';
        Assert.isTrue(expectedFormData == formData.toString(), 'Unexpected form data');
    }

    @isTest
    static void testResolveMimeType() {
        Map<String, String> fileName2MimeType =
            new Map<String, String>{
                'file.png' => 'image/png',
                'file.jpg' => 'image/jpg',
                'file.JPEG' => 'image/jpg',
                'file.pgm' => 'image/x-portable-graymap',
                'file.ppm' => 'image/x-portable-pixmap',
                'file.pdf' => 'application/pdf',
                'file.txt' => 'text/plain',
                'file.doc' => 'application/msword',
                'file.docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                'file.html' => 'text/html',
                'file.json' => 'application/json',
                'file.md' => 'text/markdown',
                'file.pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
            };

        for (String fileName : fileName2MimeType.keySet()) {
            String mimeType = CalloutHexFormBuilder.resolveMimeType(fileName);
            String expectedMimetype = fileName2MimeType.get(fileName);
            Assert.areEqual(expectedMimeType, mimeType, 'Unexpected MIME');
        }
    }

    @isTest
    static void testResolveMimeTypeError() {
        try {
            CalloutHexFormBuilder.resolveMimeType('error.');
            Assert.fail('Expected exception not thrown');
        } catch (Exception e) {
            Assert.areEqual('File name contains no extension: error.', e.getMessage(), 'Unexpected error message');
        }
        try {
            CalloutHexFormBuilder.resolveMimeType('error.exe');
            Assert.fail('Expected exception not thrown');
        } catch (Exception e) {
            Assert.areEqual('Not supported file: error.exe', e.getMessage(), 'Unexpected error message');
        }
    }
}
