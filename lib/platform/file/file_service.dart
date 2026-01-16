import 'dart:typed_data';

/// Abstract interface for platform-specific file operations
abstract class FileService {
  /// Save a file with the given name and bytes
  Future<String?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  });

  /// Read a file from the given path
  Future<Uint8List?> readFile(String path);

  /// Pick a file using platform-specific file picker
  Future<String?> pickFile({
    List<String>? allowedExtensions,
  });

  /// Check if a file exists at the given path
  Future<bool> fileExists(String path);

  /// Delete a file at the given path
  Future<void> deleteFile(String path);
}
