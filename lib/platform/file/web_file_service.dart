import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'file_service.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation of file service using browser APIs
class WebFileService implements FileService {
  @override
  Future<String?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    try {
      final blob = html.Blob([bytes], mimeType ?? 'application/octet-stream');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      debugPrint('File downloaded: $fileName');
      return fileName;
    } catch (e) {
      debugPrint('Error saving file: $e');
      rethrow;
    }
  }

  @override
  Future<Uint8List?> readFile(String path) async {
    throw UnsupportedError('Direct file path reading not supported on web');
  }

  @override
  Future<String?> pickFile({List<String>? allowedExtensions}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );
      
      if (result != null && result.files.single.bytes != null) {
        return result.files.single.name;
      }
      return null;
    } catch (e) {
      debugPrint('Error picking file: $e');
      rethrow;
    }
  }

  @override
  Future<bool> fileExists(String path) async {
    return false; // Not applicable on web
  }

  @override
  Future<void> deleteFile(String path) async {
    throw UnsupportedError('File deletion not supported on web');
  }
}
