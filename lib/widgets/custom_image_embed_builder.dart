import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:penpeeper/services/image_manager.dart';

/// Custom embed builder for displaying images in QuillEditor
/// Handles both relative paths (desktop) and URLs (web)
class CustomImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final imageUrl = embedContext.node.value.data as String;
    debugPrint('🖼️  [CustomImageEmbed] Building image: $imageUrl');

    if (kIsWeb) {
      // Web: Use network image or data URL
      return _buildWebImage(imageUrl);
    } else {
      // Desktop: Load from local file system
      return _buildDesktopImage(imageUrl);
    }
  }

  Widget _buildWebImage(String imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Image.network(
        imageUrl,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ [CustomImageEmbed] Failed to load web image: $error');
          return _buildErrorWidget(imageUrl);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      ),
    );
  }

  Widget _buildDesktopImage(String imagePath) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: FutureBuilder<Uint8List?>(
        future: ImageManager.readImageBytes(imagePath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
            debugPrint('❌ [CustomImageEmbed] Error loading image: ${snapshot.error}');
            return _buildErrorWidget(imagePath);
          }

          if (!snapshot.hasData || snapshot.data == null) {
            debugPrint('❌ [CustomImageEmbed] No image data for: $imagePath');
            return _buildErrorWidget(imagePath);
          }

          debugPrint('✅ [CustomImageEmbed] Successfully loaded image: $imagePath');
          return Image.memory(
            snapshot.data!,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('❌ [CustomImageEmbed] Failed to display image: $error');
              return _buildErrorWidget(imagePath);
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(String imagePath) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Failed to load image',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  imagePath,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
