import 'package:web/web.dart' as web;

String getBaseUrl() {
  final origin = web.window.location.origin;
  return '$origin/api';
}
