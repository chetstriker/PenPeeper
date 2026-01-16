// Web implementation for downloads
import 'dart:html' as html;

void downloadFile(String content, String filename, String mimeType) {
  final blob = html.Blob([content], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  
  html.Url.revokeObjectUrl(url);
}