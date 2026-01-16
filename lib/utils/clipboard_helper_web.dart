import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> copyToClipboardWeb(String text) async {
  try {
    await web.window.navigator.clipboard!.writeText(text).toDart;
    return true;
  } catch (e) {
    return false;
  }
}
