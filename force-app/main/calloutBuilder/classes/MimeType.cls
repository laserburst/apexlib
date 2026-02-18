/**
* It has some important, but not all MIME types. It can be expanded if needed.
* See https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/MIME_types/Common_types
*/
public with sharing class MimeType {
    public static final String FALLBACK_MIME_TYPE = 'application/octet-stream';

    public static final Map<String, String> IMAGE_EXTENSION_TO_MIME_TYPE =
        new Map<String, String>{
            'png' => 'image/png',
            'jpeg' => 'image/jpg',
            'jpg' => 'image/jpg',
            'pgm' => 'image/x-portable-graymap',
            'ppm' => 'image/x-portable-pixmap',
            'svg' => 'image/svg+xml',
            'webp' => 'image/webp',
            'tiff' => 'image/tiff',
            'tif' => 'image/tiff',
            'gif' => 'image/gif',
            'bmp' => 'image/bmp',
            'ico' => 'image/vnd.microsoft.icon'
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
            'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'ppt' => 'application/vnd.ms-powerpoint',
            'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'xls' => 'application/vnd.ms-excel',
            'csv' => 'text/csv',
            'rtf' => 'application/rtf',
            'xml' => 'application/xml',
            'css' => 'text/css',
            'mjs' => 'text/javascript',
            'js' => 'text/javascript',
            'epub' => 'application/epub+zip'
        };

    public static final Map<String, String> AUDIO_EXTENSION_TO_MIME_TYPE =
        new Map<String, String>{
            'mp3' => 'audio/mpeg',
            'wav' => 'audio/wav',
            'ogg' => 'audio/ogg',
            'weba' => 'audio/webm',
            'aac' => 'audio/aac'
        };

    public static final Map<String, String> VIDEO_EXTENSION_TO_MIME_TYPE =
        new Map<String, String>{
            'mp4' => 'video/mp4',
            'avi' => 'video/x-msvideo',
            'mpeg' => 'video/mpeg',
            'webm' => 'video/webm',
            'ogg' => 'video/ogg',
            '3gp' => 'video/3gpp',
            '3g2' => 'video/3gpp2'
        };

    public static final Map<String, String> FONT_EXTENSION_TO_MIME_TYPE =
        new Map<String, String>{
            'woff' => 'font/woff',
            'woff2' => 'font/woff2',
            'ttf' => 'font/ttf',
            'otf' => 'font/otf'
        };

    public static final Map<String, String> ARCHIVE_EXTENSION_TO_MIME_TYPE =
        new Map<String, String>{
            'zip' => 'application/zip',
            'rar' => 'application/vnd.rar',
            '7z' => 'application/x-7z-compressed',
            'tar' => 'application/x-tar',
            'gz' => 'application/gzip',
            'bz2' => 'application/x-bzip2',
            'xz' => 'application/x-xz'
        };

    public static final Map<String, String> EXTENSION_TO_MIME_TYPE = new Map<String, String>();
    static {
        EXTENSION_TO_MIME_TYPE.putAll(IMAGE_EXTENSION_TO_MIME_TYPE);
        EXTENSION_TO_MIME_TYPE.putAll(DOCUMENT_EXTENSION_TO_MIME_TYPE);
        EXTENSION_TO_MIME_TYPE.putAll(AUDIO_EXTENSION_TO_MIME_TYPE);
        EXTENSION_TO_MIME_TYPE.putAll(VIDEO_EXTENSION_TO_MIME_TYPE);
        EXTENSION_TO_MIME_TYPE.putAll(FONT_EXTENSION_TO_MIME_TYPE);
        EXTENSION_TO_MIME_TYPE.putAll(ARCHIVE_EXTENSION_TO_MIME_TYPE);
    }

    public static String getByFileNameWithExtension(String fileNameWithExtension) {
        if (String.isBlank(fileNameWithExtension)) {
            throw new IllegalArgumentException('File name is blank');
        }
        String fileExtension = fileNameWithExtension.subStringAfterLast('.');
        if (String.isBlank(fileExtension)) {
            throw new IllegalArgumentException('File name contains no extension: ' + fileNameWithExtension);
        }
        return getByExtension(fileExtension);
    }

    public static String getByExtension(String fileExtension) {
        if (String.isBlank(fileExtension)) {
            throw new IllegalArgumentException('File extension is blank');
        }
        fileExtension = fileExtension.toLowerCase();
        return EXTENSION_TO_MIME_TYPE.get(fileExtension) ?? FALLBACK_MIME_TYPE;
    }
}
