@isTest
private class MimeType_Test {
    @isTest
    static void testGetByFileNameWithExtension() {
        Test.startTest();
        String mimeType = MimeType.getByFileNameWithExtension('test.pdf');
        Test.stopTest();
        Assert.areEqual('application/pdf', mimeType);
    }

    @isTest
    static void testGetByExtension() {
        Test.startTest();
        String mimeType = MimeType.getByExtension('pdf');
        Test.stopTest();
        Assert.areEqual('application/pdf', mimeType);
    }

    @isTest
    static void testGetByExtensionWithUnknownExtension() {
        Test.startTest();
        String mimeType = MimeType.getByExtension('unknown');
        Test.stopTest();
        Assert.areEqual('application/octet-stream', mimeType);
    }

    @isTest
    static void testCaps() {
        Test.startTest();
        String mimeType = MimeType.getByFileNameWithExtension('test.PDF');
        Test.stopTest();
        Assert.areEqual('application/pdf', mimeType);
    }

    @isTest
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
