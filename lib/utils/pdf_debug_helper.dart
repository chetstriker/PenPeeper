import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/services/quill_parser.dart';

/// Debug helper to analyze PDF rendering issues for specific findings
class PdfDebugHelper {
  /// Analyzes a finding's content and estimates PDF page count
  static Future<Map<String, dynamic>> analyzeFinding(
    Map<String, dynamic> finding,
    String projectName,
  ) async {
    final findingId = finding['id'];
    final comment = finding['comment'] as String?;
    final recommendation = finding['recommendation'] as String?;

    debugPrint('=== PDF DEBUG: Analyzing Finding ID $findingId ===');

    final analysis = <String, dynamic>{
      'finding_id': findingId,
      'comment_length': comment?.length ?? 0,
      'recommendation_length': recommendation?.length ?? 0,
      'comment_analysis': await _analyzeQuillContent(
        comment,
        projectName,
        'Comment',
      ),
      'recommendation_analysis': await _analyzeQuillContent(
        recommendation,
        projectName,
        'Recommendation',
      ),
    };

    // Calculate estimated pages
    final commentPages = analysis['comment_analysis']['estimated_pages'] as int;
    final recommendationPages =
        analysis['recommendation_analysis']['estimated_pages'] as int;
    analysis['total_estimated_pages'] =
        commentPages + recommendationPages + 1; // +1 for header

    debugPrint('=== ANALYSIS COMPLETE ===');
    debugPrint('Total Estimated Pages: ${analysis['total_estimated_pages']}');
    debugPrint('Comment Pages: $commentPages');
    debugPrint('Recommendation Pages: $recommendationPages');

    return analysis;
  }

  /// Analyzes Quill delta content for potential rendering issues
  static Future<Map<String, dynamic>> _analyzeQuillContent(
    String? deltaJson,
    String projectName,
    String fieldName,
  ) async {
    if (deltaJson == null || deltaJson.isEmpty) {
      debugPrint('[$fieldName] Empty content');
      return {
        'has_content': false,
        'text_length': 0,
        'image_count': 0,
        'estimated_pages': 0,
        'issues': [],
      };
    }

    final issues = <String>[];
    int imageCount = 0;
    int textLength = 0;
    final imageDetails = <Map<String, dynamic>>[];

    try {
      final delta = jsonDecode(deltaJson);
      final operations = delta['ops'] as List;

      debugPrint('[$fieldName] Processing ${operations.length} operations');

      for (int i = 0; i < operations.length; i++) {
        final op = operations[i];

        if (op['insert'] is String) {
          final text = op['insert'] as String;
          textLength += text.length;
        } else if (op['insert'] is Map) {
          final embed = op['insert'] as Map<String, dynamic>;

          if (embed.containsKey('image')) {
            imageCount++;
            final imageSource = embed['image'];
            final imageInfo = await _analyzeImage(
              imageSource,
              projectName,
              imageCount,
            );
            imageDetails.add(imageInfo);

            debugPrint(
              '[$fieldName] Image $imageCount: ${imageInfo['status']}',
            );

            if (imageInfo['has_issue'] == true) {
              issues.add('Image $imageCount: ${imageInfo['issue']}');
            }
          }
        }
      }

      // Estimate pages: ~500 chars per page + 0.5 page per image
      final textPages = (textLength / 500).ceil();
      final imagePages = (imageCount * 0.5).ceil();
      final estimatedPages = textPages + imagePages;

      debugPrint('[$fieldName] Text: $textLength chars (~$textPages pages)');
      debugPrint('[$fieldName] Images: $imageCount (~$imagePages pages)');
      debugPrint('[$fieldName] Estimated Total: $estimatedPages pages');

      if (issues.isNotEmpty) {
        debugPrint('[$fieldName] ISSUES FOUND:');
        for (final issue in issues) {
          debugPrint('  - $issue');
        }
      }

      return {
        'has_content': true,
        'text_length': textLength,
        'image_count': imageCount,
        'image_details': imageDetails,
        'estimated_pages': estimatedPages,
        'issues': issues,
      };
    } catch (e, stack) {
      debugPrint('[$fieldName] ERROR parsing delta: $e');
      debugPrint('Stack: $stack');
      issues.add('Failed to parse delta: $e');

      return {
        'has_content': true,
        'text_length': deltaJson.length,
        'image_count': 0,
        'estimated_pages': (deltaJson.length / 500).ceil(),
        'issues': issues,
        'parse_error': e.toString(),
      };
    }
  }

  /// Analyzes a single image for potential issues
  static Future<Map<String, dynamic>> _analyzeImage(
    dynamic imageSource,
    String projectName,
    int imageNumber,
  ) async {
    final info = <String, dynamic>{
      'image_number': imageNumber,
      'source': imageSource.toString(),
      'has_issue': false,
      'issue': null,
      'status': 'unknown',
    };

    try {
      if (imageSource is String) {
        if (imageSource.startsWith('data:image/')) {
          // Base64 image
          final parts = imageSource.split(',');
          if (parts.length == 2) {
            final base64Data = parts[1];
            final bytes = base64Decode(base64Data);
            info['size_bytes'] = bytes.length;
            info['size_mb'] = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
            info['status'] = 'base64';

            // Check for excessive size
            if (bytes.length > 10 * 1024 * 1024) {
              // > 10MB
              info['has_issue'] = true;
              info['issue'] = 'Image too large: ${info['size_mb']} MB';
            }
          } else {
            info['has_issue'] = true;
            info['issue'] = 'Invalid base64 format';
            info['status'] = 'invalid_base64';
          }
        } else {
          // File path
          File file = File(imageSource);

          if (!await file.exists()) {
            // Try relative path
            final imagePath = imageSource.contains('uploads')
                ? imageSource
                : 'uploads/$projectName/$imageSource';
            file = File(imagePath);
          }

          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            info['size_bytes'] = bytes.length;
            info['size_mb'] = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
            info['path'] = file.path;
            info['status'] = 'file_found';

            // Check for excessive size
            if (bytes.length > 10 * 1024 * 1024) {
              // > 10MB
              info['has_issue'] = true;
              info['issue'] = 'Image too large: ${info['size_mb']} MB';
            }
          } else {
            info['has_issue'] = true;
            info['issue'] = 'File not found';
            info['status'] = 'file_not_found';
          }
        }
      } else {
        info['has_issue'] = true;
        info['issue'] = 'Invalid image source type: ${imageSource.runtimeType}';
        info['status'] = 'invalid_type';
      }
    } catch (e) {
      info['has_issue'] = true;
      info['issue'] = 'Error analyzing image: $e';
      info['status'] = 'error';
    }

    return info;
  }

  /// Tests rendering a finding to PDF widgets and counts actual widgets generated
  static Future<Map<String, dynamic>> testRenderFinding(
    Map<String, dynamic> finding,
    String projectName,
  ) async {
    final findingId = finding['id'];
    final comment = finding['comment'] as String?;
    final recommendation = finding['recommendation'] as String?;

    debugPrint('=== PDF RENDER TEST: Finding ID $findingId ===');

    final result = <String, dynamic>{
      'finding_id': findingId,
      'comment_widgets': 0,
      'recommendation_widgets': 0,
      'total_widgets': 0,
      'errors': [],
    };

    // Test comment rendering
    if (comment != null && comment.isNotEmpty) {
      try {
        debugPrint('[RENDER TEST] Converting comment to PDF widgets...');
        final commentWidgets = await QuillParser.deltaToPdfWidgets(
          comment,
          projectName,
        );
        result['comment_widgets'] = commentWidgets.length;
        debugPrint(
          '[RENDER TEST] Comment generated ${commentWidgets.length} widgets',
        );

        // Analyze widget types
        final widgetTypes = <String, int>{};
        for (final widget in commentWidgets) {
          final type = widget.runtimeType.toString();
          widgetTypes[type] = (widgetTypes[type] ?? 0) + 1;
        }
        result['comment_widget_types'] = widgetTypes;
        debugPrint('[RENDER TEST] Comment widget types: $widgetTypes');
      } catch (e, stack) {
        debugPrint('[RENDER TEST] ERROR rendering comment: $e');
        debugPrint('Stack: $stack');
        result['errors'].add('Comment render error: $e');
      }
    }

    // Test recommendation rendering
    if (recommendation != null && recommendation.isNotEmpty) {
      try {
        debugPrint('[RENDER TEST] Converting recommendation to PDF widgets...');
        final recWidgets = await QuillParser.deltaToPdfWidgets(
          recommendation,
          projectName,
        );
        result['recommendation_widgets'] = recWidgets.length;
        debugPrint(
          '[RENDER TEST] Recommendation generated ${recWidgets.length} widgets',
        );

        // Analyze widget types
        final widgetTypes = <String, int>{};
        for (final widget in recWidgets) {
          final type = widget.runtimeType.toString();
          widgetTypes[type] = (widgetTypes[type] ?? 0) + 1;
        }
        result['recommendation_widget_types'] = widgetTypes;
        debugPrint('[RENDER TEST] Recommendation widget types: $widgetTypes');
      } catch (e, stack) {
        debugPrint('[RENDER TEST] ERROR rendering recommendation: $e');
        debugPrint('Stack: $stack');
        result['errors'].add('Recommendation render error: $e');
      }
    }

    result['total_widgets'] =
        result['comment_widgets'] + result['recommendation_widgets'];
    debugPrint(
      '=== RENDER TEST COMPLETE: ${result['total_widgets']} total widgets ===',
    );

    return result;
  }

  /// Dumps raw delta JSON for inspection
  static void dumpDeltaJson(Map<String, dynamic> finding) {
    final findingId = finding['id'];
    final comment = finding['comment'] as String?;
    final recommendation = finding['recommendation'] as String?;

    debugPrint('=== DELTA JSON DUMP: Finding ID $findingId ===');

    if (comment != null && comment.isNotEmpty) {
      debugPrint('[COMMENT DELTA]');
      debugPrint(comment);
      debugPrint('');
    }

    if (recommendation != null && recommendation.isNotEmpty) {
      debugPrint('[RECOMMENDATION DELTA]');
      debugPrint(recommendation);
      debugPrint('');
    }

    debugPrint('=== END DELTA DUMP ===');
  }
}
