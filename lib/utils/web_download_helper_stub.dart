import 'dart:typed_data';

class WebDownloadHelper {
  static void downloadFile(Uint8List bytes, String filename, String mimeType) {
    throw UnsupportedError('Web download is only supported on web platform');
  }
}
