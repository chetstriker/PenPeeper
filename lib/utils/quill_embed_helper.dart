import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/utils/image_path_helper.dart';

class QuillEmbedHelper {
  static String? convertDeltaJsonForWeb(String? deltaJson) {
    if (deltaJson == null || deltaJson.isEmpty) {
      debugPrint('📷 [QuillEmbedHelper] Delta JSON is null or empty');
      return deltaJson;
    }

    try {
      final delta = jsonDecode(deltaJson);
      List ops;

      if (delta is List) {
        // Delta is directly the ops array: [{insert: ...}, ...]
        ops = delta;
        debugPrint(
          '📷 [QuillEmbedHelper] Delta is a List (ops array directly)',
        );
      } else if (delta is Map && delta.containsKey('ops')) {
        // Delta is wrapped: {ops: [{insert: ...}, ...]}
        ops = delta['ops'] as List;
        debugPrint('📷 [QuillEmbedHelper] Delta is a Map with ops key');
      } else {
        debugPrint(
          '📷 [QuillEmbedHelper] Delta JSON does not contain ops array',
        );
        debugPrint('📷 [QuillEmbedHelper] Delta type: ${delta.runtimeType}');
        if (delta is Map) {
          debugPrint(
            '📷 [QuillEmbedHelper] Delta keys: ${delta.keys.toList()}',
          );
          debugPrint(
            '📷 [QuillEmbedHelper] Delta content: ${jsonEncode(delta).substring(0, jsonEncode(delta).length > 200 ? 200 : jsonEncode(delta).length)}...',
          );
        }
        return deltaJson;
      }

      bool modified = false;
      int imageCount = 0;

      for (final op in ops) {
        if (op is Map && op.containsKey('insert') && op['insert'] is Map) {
          final insert = op['insert'] as Map;
          if (insert.containsKey('image')) {
            final imagePath = insert['image'];
            imageCount++;
            debugPrint(
              '📷 [QuillEmbedHelper] Found image #$imageCount: $imagePath',
            );
            debugPrint(
              '📷 [QuillEmbedHelper] Platform: ${kIsWeb ? "Web" : "Desktop"}',
            );

            if (imagePath is String) {
              final convertedPath = ImagePathHelper.resolveImagePath(imagePath);
              if (convertedPath != imagePath) {
                insert['image'] = convertedPath;
                debugPrint(
                  '📷 [QuillEmbedHelper] Converted to: $convertedPath',
                );
                modified = true;
              } else {
                debugPrint(
                  '📷 [QuillEmbedHelper] No conversion needed (already resolved)',
                );
              }
            }
          }
        }
      }

      if (imageCount == 0) {
        debugPrint('📷 [QuillEmbedHelper] No images found in delta');
      } else {
        debugPrint('📷 [QuillEmbedHelper] Total images found: $imageCount');
      }

      if (modified) {
        // Return the modified ops array in the same format it came in
        return delta is List ? jsonEncode(ops) : jsonEncode(delta);
      }
      return deltaJson;
    } catch (e) {
      debugPrint('📷 [QuillEmbedHelper] Error converting delta JSON: $e');
    }

    return deltaJson;
  }
}
