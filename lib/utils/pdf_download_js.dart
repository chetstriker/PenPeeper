@JS()
library pdf_download_js;

import 'dart:js_interop';
import 'dart:typed_data';

@JS('dartDownloadPdf')
external void _jsDownloadPdf(JSUint8Array bytes, JSString filename);

void downloadViaJs(Uint8List bytes, String filename) {
  _jsDownloadPdf(bytes.toJS, filename.toJS);
}
