import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/api_database_helper.dart';
import 'package:penpeeper/services/app_paths_service.dart';

class ImagePathHelper {
  /// Converts a stored relative path to an absolute path for the current platform
  /// Stored format: "uploads/ProjectName/image.png" or "risk.png"
  /// Desktop: resolves relative to app data directory
  /// Web: "http://server:8808/uploads/ProjectName/image.png"
  static String resolveImagePath(String storedPath) {
    // Already a data URI or HTTP URL
    if (storedPath.startsWith('data:') || storedPath.startsWith('http')) {
      return storedPath;
    }

    // Web platform: convert relative paths to HTTP URLs
    if (kIsWeb) {
      // Extract relative path starting from 'uploads/' if present
      String relativePath = storedPath;
      final uploadsIndex = storedPath.indexOf('uploads');
      if (uploadsIndex != -1) {
        relativePath = storedPath.substring(uploadsIndex);
      }

      // Normalize to forward slashes for consistency
      relativePath = relativePath.replaceAll('\\', '/');

      // Web: return HTTP URL
      final baseUrl = ApiDatabaseHelper.baseUrl.replaceAll('/api', '');
      return '$baseUrl/$relativePath';
    }

    // Desktop platforms: handle both relative and absolute paths
    // Check if this is already an absolute path (legacy data may have stored absolute paths)
    final isAbsolutePath = storedPath.contains(Platform.pathSeparator) &&
        (storedPath.startsWith('/') || storedPath.contains(':'));

    if (isAbsolutePath) {
      // If it's an absolute path to risk.png but doesn't exist, use the current risk path
      if (storedPath.contains('risk.png')) {
        final file = File(storedPath);
        if (!file.existsSync()) {
          // File doesn't exist at old location, use current AppData location
          return AppPathsService().riskPath;
        }
      }
      // Return the absolute path as-is if file exists
      return storedPath;
    }

    // Extract relative path starting from 'uploads/' if present
    String relativePath = storedPath;
    final uploadsIndex = storedPath.indexOf('uploads');
    if (uploadsIndex != -1) {
      relativePath = storedPath.substring(uploadsIndex);
    }

    // Normalize to forward slashes for consistency
    relativePath = relativePath.replaceAll('\\', '/');

    // Desktop: resolve relative to app data directory
    final basePath = AppPathsService().appDataDir;
    final fullPath = '$basePath/$relativePath';
    return fullPath.replaceAll('/', Platform.pathSeparator);
  }
  
  /// Converts an absolute path to a relative path for storage
  /// Handles both Windows and Linux paths:
  /// - Windows: "C:\full\path\to\uploads\ProjectName\image.png"
  /// - Linux: "/full/path/to/uploads/ProjectName/image.png"
  /// - Web: "http://server:8808/uploads/ProjectName/image.png"
  /// Output: "uploads/ProjectName/image.png" or "risk.png"
  static String toStoragePath(String absolutePath) {
    // Handle Web URLs (strip base URL)
    if (kIsWeb && absolutePath.startsWith('http')) {
       final baseUrl = ApiDatabaseHelper.baseUrl.replaceAll('/api', '');
       if (absolutePath.startsWith(baseUrl)) {
          String relative = absolutePath.substring(baseUrl.length);
          if (relative.startsWith('/')) relative = relative.substring(1);
          return relative;
       }
    }

    // Already relative or a data URI or external URL
    if (absolutePath.startsWith('data:') || absolutePath.startsWith('http')) {
      return absolutePath;
    }

    // Normalize path separators
    String normalizedPath = absolutePath.replaceAll('\\', '/');

    // Special case: risk.png should always be stored as just "risk.png"
    if (normalizedPath.contains('risk.png') && !normalizedPath.contains('uploads')) {
      return 'risk.png';
    }

    // Find "uploads" in the path (case-insensitive for cross-platform compatibility)
    final uploadsIndex = normalizedPath.toLowerCase().indexOf('uploads');
    if (uploadsIndex != -1) {
      // Extract from "uploads" onwards, preserving original case
      return normalizedPath.substring(uploadsIndex);
    }

    // If no uploads folder found and not risk.png, return just the filename
    // This handles any other files stored directly in AppData
    final lastSlash = normalizedPath.lastIndexOf('/');
    if (lastSlash != -1) {
      return normalizedPath.substring(lastSlash + 1);
    }

    // Already relative
    return absolutePath;
  }
}
