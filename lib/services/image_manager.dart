import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:penpeeper/api_database_helper.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'package:penpeeper/utils/image_resizer.dart';

class ImageManager {
  static Future<String> copyImageToProjectFolder({
    required String sourcePath,
    required String projectName,
    Uint8List? bytes,
  }) async {
    if (kIsWeb) {
      return await _copyImageWeb(sourcePath, projectName, bytes: bytes);
    } else {
      return await _copyImageDesktop(sourcePath, projectName);
    }
  }

  static Future<String> _copyImageDesktop(String sourcePath, String projectName) async {
    debugPrint('🖼️  [ImageManager] Starting desktop image copy...');
    debugPrint('   Source: $sourcePath');
    debugPrint('   Project: $projectName');

    // Get project uploads directory from AppPathsService
    final projectImagesDir = Directory(AppPathsService().getProjectUploadsDir(projectName));

    if (!await projectImagesDir.exists()) {
      debugPrint('📁 [ImageManager] Creating directory: ${projectImagesDir.path}');
      await projectImagesDir.create(recursive: true);
    }

    final sourceFile = File(sourcePath);
    final extension = path.extension(sourcePath);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final newFileName = 'image_$timestamp$extension';
    final destinationPath = path.join(projectImagesDir.path, newFileName);

    // Read and resize the image if needed
    final sourceBytes = await sourceFile.readAsBytes();
    final fileName = path.basename(sourcePath);

    debugPrint('📐 [ImageManager] Checking if resize is needed...');
    final resizeResult = await ImageResizer.resizeImageIfNeeded(
      imageBytes: sourceBytes,
      imageName: fileName,
    );

    if (resizeResult.wasResized) {
      debugPrint('✨ [ImageManager] Image was resized, saving resized version');
    } else {
      debugPrint('✓ [ImageManager] Image is within size limits, saving original');
    }

    // Save the (possibly resized) image
    final destFile = File(destinationPath);
    await destFile.writeAsBytes(resizeResult.imageBytes);

    debugPrint('✅ [ImageManager] Image saved to: $destinationPath');

    // Return relative path from uploads folder instead of absolute path
    return 'uploads/$projectName/$newFileName';
  }

  static Future<String> _copyImageWeb(String sourcePath, String projectName, {Uint8List? bytes}) async {
    try {
      debugPrint('🌐 [ImageManager] Starting web image upload...');
      debugPrint('   Source: $sourcePath');
      debugPrint('   Project: $projectName');

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final fileName = 'image_$timestamp.png';

      if (bytes == null) {
        throw Exception('No file data provided for upload');
      }

      // Resize the image if needed before uploading
      debugPrint('📐 [ImageManager] Checking if resize is needed...');
      final resizeResult = await ImageResizer.resizeImageIfNeeded(
        imageBytes: bytes,
        imageName: sourcePath,
      );

      if (resizeResult.wasResized) {
        debugPrint('✨ [ImageManager] Image was resized before upload');
      } else {
        debugPrint('✓ [ImageManager] Image is within size limits');
      }

      final request = http.MultipartRequest('POST', Uri.parse('${ApiDatabaseHelper.baseUrl}/images/upload'));
      request.fields['projectName'] = projectName;
      request.fields['fileName'] = fileName;

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        resizeResult.imageBytes,
        filename: fileName,
      ));

      debugPrint('📤 [ImageManager] Uploading image...');
      final streamResponse = await request.send();
      final response = await http.Response.fromStream(streamResponse);

      if (response.statusCode == 200) {
        debugPrint('✅ [ImageManager] Upload successful');
        return response.body;
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [ImageManager] Error uploading image: $e');
      rethrow;
    }
  }

  static Future<Uint8List?> readImageBytes(String imagePath) async {
    if (kIsWeb) {
      try {
        if (imagePath.startsWith('http')) {
          final response = await http.get(Uri.parse(imagePath));
          if (response.statusCode == 200) {
            return response.bodyBytes;
          }
        }
      } catch (e) {
        return null;
      }
    } else {
      debugPrint('📁 [ImageManager] Desktop path requested: $imagePath');
      try {
        File file;

        // Extract relative path from uploads/ onwards
        // This handles old absolute paths from different machines
        String resolvedPath = imagePath;
        final uploadsIndex = imagePath.indexOf('uploads');
        debugPrint('📁 [ImageManager] Uploads index: $uploadsIndex');
        if (uploadsIndex != -1) {
          // Extract from "uploads" onwards
          resolvedPath = imagePath.substring(uploadsIndex);
          resolvedPath = resolvedPath.replaceAll('\\', '/');
          // Convert to absolute path relative to app data directory
          resolvedPath = path.join(AppPathsService().appDataDir, resolvedPath);
          resolvedPath = resolvedPath.replaceAll('/', Platform.pathSeparator);

          debugPrint('📁 [ImageManager] Original: $imagePath');
          debugPrint('📁 [ImageManager] Resolved: $resolvedPath');
        } else if (path.isAbsolute(imagePath)) {
          // Absolute path without uploads - use as is
          resolvedPath = imagePath;
        } else {
          // Relative path - resolve from app data directory
          resolvedPath = path.join(AppPathsService().appDataDir, imagePath);
        }

        file = File(resolvedPath);
        final exists = await file.exists();
        debugPrint('📁 [ImageManager] File exists: $exists at $resolvedPath');

        if (exists) {
          return await file.readAsBytes();
        } else {
          // Try to find the file in alternate project folders
          debugPrint('📁 [ImageManager] File not found, searching alternate project folders...');
          final alternateBytes = await _findInAlternateProjectFolders(resolvedPath);
          if (alternateBytes != null) {
            debugPrint('✅ [ImageManager] Found file in alternate project folder');
            return alternateBytes;
          }
        }
      } catch (e) {
        debugPrint('❌ [ImageManager] Error reading image: $e');
        return null;
      }
    }
    return null;
  }

  /// Searches for an image file in alternate project folders when not found in the expected location
  /// This handles cases where the database references one project folder but files are in another
  static Future<Uint8List?> _findInAlternateProjectFolders(String originalPath) async {
    try {
      // Extract filename from the path
      final fileName = path.basename(originalPath);
      final uploadsDir = Directory(AppPathsService().uploadsDir);

      if (!await uploadsDir.exists()) {
        return null;
      }

      // List all project folders in uploads directory
      await for (final entity in uploadsDir.list()) {
        if (entity is Directory) {
          final testPath = path.join(entity.path, fileName);
          final testFile = File(testPath);

          if (await testFile.exists()) {
            debugPrint('📁 [ImageManager] Found in alternate folder: ${path.basename(entity.path)}');
            return await testFile.readAsBytes();
          }
        }
      }

      debugPrint('📁 [ImageManager] File not found in any project folder: $fileName');
      return null;
    } catch (e) {
      debugPrint('❌ [ImageManager] Error searching alternate folders: $e');
      return null;
    }
  }
}
