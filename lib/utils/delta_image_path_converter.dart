import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/utils/image_path_helper.dart';

/// Utility class for converting image paths in Quill delta JSON
/// between absolute and relative formats for export/import operations.
class DeltaImagePathConverter {
  /// Converts all absolute image paths in Quill delta JSON to relative paths
  /// for storage/export. This ensures cross-platform compatibility.
  ///
  /// Example:
  /// - Input: "/Users/user/Library/.../uploads/Project/image.png"
  /// - Output: "uploads/Project/image.png"
  static String? convertToRelativePaths(String? deltaJson) {
    if (deltaJson == null || deltaJson.isEmpty) {
      return deltaJson;
    }

    try {
      final delta = jsonDecode(deltaJson);
      List ops;

      if (delta is List) {
        // Delta is directly the ops array: [{insert: ...}, ...]
        ops = delta;
      } else if (delta is Map && delta.containsKey('ops')) {
        // Delta is wrapped: {ops: [{insert: ...}, ...]}
        ops = delta['ops'] as List;
      } else {
        // Not a valid delta format
        return deltaJson;
      }

      bool modified = false;
      int imageCount = 0;
      for (final op in ops) {
        if (op is Map && op.containsKey('insert') && op['insert'] is Map) {
          final insert = op['insert'] as Map;
          if (insert.containsKey('image')) {
            imageCount++;
            final imagePath = insert['image'];
            debugPrint('[Export] Found image #$imageCount: $imagePath');
            if (imagePath is String && !imagePath.startsWith('data:')) {
              // Convert absolute path to relative storage path
              final relativePath = ImagePathHelper.toStoragePath(imagePath);
              if (relativePath != imagePath) {
                insert['image'] = relativePath;
                modified = true;
                debugPrint(
                  '[Export]   -> Converted to relative: $relativePath',
                );
              } else {
                debugPrint(
                  '[Export]   -> Already relative or no conversion needed',
                );
              }
            } else {
              debugPrint('[Export]   -> Skipped (data URI or not a string)');
            }
          }
        }
      }

      if (imageCount == 0) {
        debugPrint('[Export] No images found in delta');
      } else {
        debugPrint('[Export] Processed $imageCount images');
      }

      if (modified) {
        // Return the modified delta in the same format it came in
        return delta is List ? jsonEncode(ops) : jsonEncode(delta);
      }
      return deltaJson;
    } catch (e) {
      debugPrint('[DeltaImagePathConverter] Error converting paths: $e');
      return deltaJson;
    }
  }

  /// Processes a finding record and converts all image paths to relative
  static Map<String, dynamic> convertFindingToRelativePaths(
    Map<String, dynamic> finding,
  ) {
    final result = Map<String, dynamic>.from(finding);

    debugPrint('[Export] Converting finding ${finding['id']} paths to relative');

    // Convert paths in comment, evidence, and recommendation fields
    if (result['comment'] != null) {
      debugPrint('[Export]   Processing comment field');
      result['comment'] = convertToRelativePaths(result['comment'] as String?);
    }
    if (result['evidence'] != null) {
      debugPrint('[Export]   Processing evidence field');
      result['evidence'] = convertToRelativePaths(result['evidence'] as String?);
    }
    if (result['recommendation'] != null) {
      debugPrint('[Export]   Processing recommendation field');
      result['recommendation'] =
          convertToRelativePaths(result['recommendation'] as String?);
    }

    return result;
  }

  /// Processes a report section record and converts all image paths to relative
  static Map<String, dynamic> convertReportSectionToRelativePaths(
    Map<String, dynamic> section,
  ) {
    final result = Map<String, dynamic>.from(section);

    debugPrint(
      '[Export] Converting report section ${section['section_type']} paths to relative',
    );

    // Convert paths in content field
    if (result['content'] != null) {
      debugPrint('[Export]   Processing content field');
      result['content'] = convertToRelativePaths(result['content'] as String?);
    }

    return result;
  }

  /// Processes an entire project export and converts all image paths to relative
  static Map<String, dynamic> convertProjectExportToRelativePaths(
    Map<String, dynamic> projectData,
  ) {
    final result = Map<String, dynamic>.from(projectData);

    // Convert findings
    if (result['findings'] is List) {
      result['findings'] = (result['findings'] as List)
          .map((f) => convertFindingToRelativePaths(f as Map<String, dynamic>))
          .toList();
    }

    // Convert report sections
    if (result['reportSections'] is List) {
      result['reportSections'] = (result['reportSections'] as List)
          .map(
            (s) => convertReportSectionToRelativePaths(s as Map<String, dynamic>),
          )
          .toList();
    }

    return result;
  }
}
