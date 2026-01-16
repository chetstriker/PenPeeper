@JS()
library;

import 'dart:js_interop';
import 'dart:typed_data';

@JS('Blob')
external JSFunction get blobConstructor;

@JS('URL.createObjectURL')
external JSString createObjectURL(JSObject blob);

@JS('URL.revokeObjectURL')
external void revokeObjectURL(JSString url);

void downloadPdfWeb(Uint8List bytes, String filename) {
  // Create blob
  final jsArray = bytes.toJS;
  final options = {'type': 'application/pdf'}.jsify();
  final blob = blobConstructor.callAsFunction(null, [jsArray].toJS, options);
  
  // Create download link
  final url = createObjectURL(blob as JSObject);
  
  // Create and click anchor
  final anchor = document.createElement('a') as JSObject;
  anchor.setProperty('href'.toJS, url);
  anchor.setProperty('download'.toJS, filename.toJS);
  (anchor as JSAny).callMethod('click'.toJS);
  
  // Cleanup
  revokeObjectURL(url);
}

@JS('document')
external JSObject get document;

extension on JSObject {
  external JSObject createElement(JSString tagName);
  external void setProperty(JSString name, JSAny value);
}
