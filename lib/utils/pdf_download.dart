import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/utils/pdf_download_js.dart' if (dart.library.io) 'package:penpeeper/utils/pdf_download_stub.dart';

void downloadPdf(Uint8List bytes, String filename) {
  debugPrint('[PDF_DOWNLOAD] downloadPdf called');
  debugPrint('[PDF_DOWNLOAD] kIsWeb: $kIsWeb');
  debugPrint('[PDF_DOWNLOAD] bytes length: ${bytes.length}');
  debugPrint('[PDF_DOWNLOAD] filename: $filename');
  
  if (!kIsWeb) {
    throw UnsupportedError('PDF download not supported on this platform');
  }
  
  downloadViaJs(bytes, filename);
  debugPrint('[PDF_DOWNLOAD] Download triggered');
}
