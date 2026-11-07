@IsTest
private class MimeType_Test {
    @IsTest
    static void testGetByFileNameWithExtension() {
        Test.startTest();
        String mimeType = MimeType.getByFileNameWithExtension('test.pdf');
        Test.stopTest();
        Assert.areEqual('application/pdf', mimeType);
    }

    @IsTest
    static void testGetByExtension() {
        Test.startTest();
        String mimeType = MimeType.getByExtension('pdf');
        Test.stopTest();
        Assert.areEqual('application/pdf', mimeType);
    }

    @IsTest
    static void testGetByExtensionWithUnknownExtension() {
        Test.startTest();
        String mimeType = MimeType.getByExtension('unknown');
        Test.stopTest();
        Assert.areEqual('application/octet-stream', mimeType);
    }

    @IsTest
    static void testFileNameWithoutExtension() {
        Test.startTest();
        String mimeType = MimeType.getByFileNameWithExtension('LICENSE');
        Test.stopTest();
        Assert.areEqual('application/octet-stream', mimeType);
    }

    @IsTest
    static void testCaps() {
        Test.startTest();
        String mimeType = MimeType.getByFileNameWithExtension('test.PDF');
        Test.stopTest();
        Assert.areEqual('application/pdf', mimeType);
    }

    @IsTest
    static void testBlankFileName() {
        Test.startTest();
        try {
            MimeType.getByFileNameWithExtension('');
            Assert.fail('Expected exception not thrown');
        } catch (Exception e) {
            Assert.areEqual('File name is blank', e.getMessage());
        }
        Test.stopTest();
    }
}