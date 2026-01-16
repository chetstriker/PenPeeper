import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
// Conditional import for platform-specific code
import 'dart:io' if (dart.library.html) 'dart:html' as platform;

/// Utility class for resizing images to ensure they fit within PDF size constraints
///
/// This class works across all platforms (Windows, Mac, Linux, Web) by:
/// - Using the pure Dart 'image' package for resizing operations
/// - Operating on Uint8List which is available on all platforms
/// - Using conditional imports to avoid dart:io on web
class ImageResizer {
  // Maximum dimensions for PDF images (keeping it safe below the 2000px limit)
  static const int maxWidth = 1920;
  static const int maxHeight = 1920;

  /// Resize an image if it exceeds the maximum dimensions
  /// Returns the resized image bytes and whether resizing was performed
  ///
  /// Platform-agnostic: Works on Windows, Mac, Linux, and Web
  static Future<ImageResizeResult> resizeImageIfNeeded({
    required Uint8List imageBytes,
    required String imageName,
  }) async {
    try {
      debugPrint('🔍 [ImageResizer] Analyzing image: $imageName');
      debugPrint('📊 [ImageResizer] Original size: ${imageBytes.length} bytes');

      // Decode the image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('❌ [ImageResizer] Failed to decode image: $imageName');
        return ImageResizeResult(
          imageBytes: imageBytes,
          wasResized: false,
          originalWidth: 0,
          originalHeight: 0,
          newWidth: 0,
          newHeight: 0,
        );
      }

      final originalWidth = image.width;
      final originalHeight = image.height;
      debugPrint('📐 [ImageResizer] Original dimensions: ${originalWidth}x$originalHeight');

      // Check if resizing is needed
      if (originalWidth <= maxWidth && originalHeight <= maxHeight) {
        debugPrint('✅ [ImageResizer] Image is within size limits, no resizing needed');
        return ImageResizeResult(
          imageBytes: imageBytes,
          wasResized: false,
          originalWidth: originalWidth,
          originalHeight: originalHeight,
          newWidth: originalWidth,
          newHeight: originalHeight,
        );
      }

      // Calculate new dimensions while maintaining aspect ratio
      double scale = 1.0;
      if (originalWidth > maxWidth || originalHeight > maxHeight) {
        final widthScale = maxWidth / originalWidth;
        final heightScale = maxHeight / originalHeight;
        scale = widthScale < heightScale ? widthScale : heightScale;
      }

      final newWidth = (originalWidth * scale).round();
      final newHeight = (originalHeight * scale).round();

      debugPrint('⚙️  [ImageResizer] Resizing image...');
      debugPrint('   Scale factor: ${scale.toStringAsFixed(3)}');
      debugPrint('   New dimensions: ${newWidth}x$newHeight');

      // Resize the image using high-quality interpolation
      final resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // Encode back to the original format if possible
      Uint8List resizedBytes;
      final extension = imageName.toLowerCase().split('.').last;

      if (extension == 'png') {
        debugPrint('💾 [ImageResizer] Encoding as PNG...');
        resizedBytes = Uint8List.fromList(img.encodePng(resizedImage));
      } else if (extension == 'jpg' || extension == 'jpeg') {
        debugPrint('💾 [ImageResizer] Encoding as JPEG (quality: 90)...');
        resizedBytes = Uint8List.fromList(img.encodeJpg(resizedImage, quality: 90));
      } else {
        // Default to PNG for unknown formats
        debugPrint('💾 [ImageResizer] Unknown format, encoding as PNG...');
        resizedBytes = Uint8List.fromList(img.encodePng(resizedImage));
      }

      debugPrint('✅ [ImageResizer] Resize complete!');
      debugPrint('   Original: ${originalWidth}x$originalHeight (${imageBytes.length} bytes)');
      debugPrint('   Resized: ${newWidth}x$newHeight (${resizedBytes.length} bytes)');
      debugPrint('   Space saved: ${((1 - (resizedBytes.length / imageBytes.length)) * 100).toStringAsFixed(1)}%');

      return ImageResizeResult(
        imageBytes: resizedBytes,
        wasResized: true,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        newWidth: newWidth,
        newHeight: newHeight,
      );
    } catch (e, stack) {
      debugPrint('❌ [ImageResizer] Error resizing image: $e');
      debugPrint('Stack trace: $stack');

      // Return original image if resizing fails
      return ImageResizeResult(
        imageBytes: imageBytes,
        wasResized: false,
        originalWidth: 0,
        originalHeight: 0,
        newWidth: 0,
        newHeight: 0,
        error: e.toString(),
      );
    }
  }

  /// Check if an image needs resizing without actually resizing it
  ///
  /// Platform-agnostic: Works on all platforms
  static Future<bool> needsResize(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return false;

      return image.width > maxWidth || image.height > maxHeight;
    } catch (e) {
      debugPrint('❌ [ImageResizer] Error checking image size: $e');
      return false;
    }
  }

  /// Get image dimensions without resizing
  static Future<ImageDimensions?> getImageDimensions(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      return ImageDimensions(width: image.width, height: image.height);
    } catch (e) {
      debugPrint('❌ [ImageResizer] Error getting image dimensions: $e');
      return null;
    }
  }
}

/// Result of an image resize operation
class ImageResizeResult {
  final Uint8List imageBytes;
  final bool wasResized;
  final int originalWidth;
  final int originalHeight;
  final int newWidth;
  final int newHeight;
  final String? error;

  ImageResizeResult({
    required this.imageBytes,
    required this.wasResized,
    required this.originalWidth,
    required this.originalHeight,
    required this.newWidth,
    required this.newHeight,
    this.error,
  });
}

/// Simple class to hold image dimensions
class ImageDimensions {
  final int width;
  final int height;

  ImageDimensions({required this.width, required this.height});

  @override
  String toString() => '${width}x$height';
}
