import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:js' as js;

void downloadPdfImpl(Uint8List bytes, String filename) {
  debugPrint('[PDF_DOWNLOAD_WEB] downloadPdfImpl called');
  try {
    // Call JS function
    js.context.callMethod('downloadPdfBytes', [bytes, filename]);
    debugPrint('[PDF_DOWNLOAD_WEB] JS function called successfully');
  } catch (e) {
    debugPrint('[PDF_DOWNLOAD_WEB] Error: $e');
    rethrow;
  }
}
