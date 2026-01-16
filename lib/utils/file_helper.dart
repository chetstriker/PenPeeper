import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';

/// Centralized file operations utility
class FileHelper {
  /// Save file with platform-specific handling
  static Future<String?> saveFile({
    required String content,
    required String defaultFileName,
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    if (kIsWeb) {
      final bytes = utf8.encode(content);
      return await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle ?? 'Save File',
        fileName: defaultFileName,
        bytes: bytes,
      );
    } else {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle ?? 'Save File',
        fileName: defaultFileName,
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );
      
      if (result != null) {
        final file = File(result);
        await file.writeAsString(content);
        return file.path;
      }
    }
    
    return null;
  }

  /// Pick file for reading
  static Future<String?> pickFile({
    List<String>? allowedExtensions,
    String? dialogTitle,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle ?? 'Pick File',
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
    );
    
    if (result != null && result.files.isNotEmpty) {
      if (kIsWeb) {
        final bytes = result.files.first.bytes;
        if (bytes != null) {
          return utf8.decode(bytes);
        }
      } else {
        final path = result.files.first.path;
        if (path != null) {
          final file = File(path);
          return await file.readAsString();
        }
      }
    }
    
    return null;
  }

  /// Get file path for picking (desktop only)
  static Future<String?> pickFilePath({
    List<String>? allowedExtensions,
    String? dialogTitle,
  }) async {
    if (kIsWeb) return null;
    
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle ?? 'Pick File',
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
    );
    
    return result?.files.first.path;
  }
}
