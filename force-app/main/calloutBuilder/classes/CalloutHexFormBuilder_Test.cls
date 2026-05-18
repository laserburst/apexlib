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
            '------sf-multi-form\r\nContent-Disposition: form-data; name="id"\r\n\r\n123\r\n------sf-multi-form\r\nContent-Disposition: form-data; name="message"\r\n\r\nsecond parameter\r\n------sf-multi-form\r\nContent-Disposition: form-data; name="file"; filename="file.png"\r\nContent-Type: image/png\r\n\r\n\r\n------sf-multi-form--';
        Assert.isTrue(expectedFormData == formData.toString(), 'Unexpected form data');
    }

    @isTest
    static void testWriteFileBlobContent() {
        String fileName = 'file.png';
        Blob fileContent = Blob.valueOf('ABC');

        Test.startTest();
        Blob formData =
            CalloutHexFormBuilder.build()
                .writeFile(fileName, fileContent)
                .getFormAsBlob();
        Test.stopTest();

        String expectedFormData =
            '------sf-multi-form\r\nContent-Disposition: form-data; name="file"; filename="file.png"\r\nContent-Type: image/png\r\n\r\nABC\r\n------sf-multi-form--';
        Assert.isTrue(expectedFormData == formData.toString(), 'Unexpected form data');
    }

    @isTest
    static void testJsonParameterBuild() {
        String fileName = 'doc.docx';
        String fileContent = '';
        String profileJson = '{"doc_profile":{"name":"doc","extension":"docx"}}';

        Test.startTest();
        Blob formData =
            CalloutHexFormBuilder.build()
                .writeJsonParameters(new Map<String, String>{ 'profile' => profileJson })
                .writeFile(fileName, fileContent)
                .getFormAsBlob();
        Test.stopTest();

        String expectedFormData =
            '------sf-multi-form\r\nContent-Disposition: form-data; name="profile"; filename="blob"\r\nContent-Type: application/json\r\n\r\n{"doc_profile":{"name":"doc","extension":"docx"}}\r\n------sf-multi-form\r\nContent-Disposition: form-data; name="file"; filename="doc.docx"\r\nContent-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document\r\n\r\n\r\n------sf-multi-form--';
        Assert.isTrue(expectedFormData == formData.toString(), 'Unexpected form data');
    }
}
