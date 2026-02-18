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
}
