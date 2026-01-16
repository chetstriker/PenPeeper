import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'file_service.dart';

/// Desktop implementation of file service using dart:io
class DesktopFileService implements FileService {
  @override
  Future<String?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save File',
        fileName: fileName,
      );
      
      if (result != null) {
        final file = File(result);
        await file.writeAsBytes(bytes);
        debugPrint('File saved: $result');
        return result;
      }
      return null;
    } catch (e) {
      debugPrint('Error saving file: $e');
      rethrow;
    }
  }

  @override
  Future<Uint8List?> readFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      debugPrint('Error reading file: $e');
      rethrow;
    }
  }

  @override
  Future<String?> pickFile({List<String>? allowedExtensions}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );
      
      return result?.files.single.path;
    } catch (e) {
      debugPrint('Error picking file: $e');
      rethrow;
    }
  }

  @override
  Future<bool> fileExists(String path) async {
    try {
      return await File(path).exists();
    } catch (e) {
      debugPrint('Error checking file existence: $e');
      return false;
    }
  }

  @override
  Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('File deleted: $path');
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
      rethrow;
    }
  }
}
