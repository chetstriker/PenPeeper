import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_to_pdf/flutter_quill_to_pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:penpeeper/utils/image_path_helper.dart';

class ReportSectionConverter {
  static Future<List<pw.Widget>> convertDeltaToPdf(String? deltaJson) async {
    if (deltaJson == null || deltaJson.isEmpty) return [];

    try {
      final delta = jsonDecode(deltaJson);

      // Resolve relative image paths to absolute paths for PDF rendering
      if (delta is Map && delta.containsKey('ops')) {
        final ops = delta['ops'] as List;
        for (final op in ops) {
          if (op is Map && op.containsKey('insert') && op['insert'] is Map) {
            final insert = op['insert'] as Map;
            if (insert.containsKey('image')) {
              final imagePath = insert['image'];
              if (imagePath is String && !imagePath.startsWith('data:') && !imagePath.startsWith('http')) {
                debugPrint(
                  '🖼️ [ReportSectionConverter] Original path: $imagePath',
                );
                // Resolve relative path to absolute path
                final resolvedPath = ImagePathHelper.resolveImagePath(imagePath);
                insert['image'] = resolvedPath;
                debugPrint(
                  '🖼️ [ReportSectionConverter] Resolved to: $resolvedPath',
                );

                // Verify file exists
                if (!kIsWeb) {
                  final file = File(resolvedPath);
                  final exists = await file.exists();
                  debugPrint('🖼️ [ReportSectionConverter] File exists: $exists');
                  if (!exists) {
                    debugPrint('❌ [ReportSectionConverter] File not found at: $resolvedPath');
                  }
                }
              }
            }
          }
        }
      } else if (delta is List) {
        // Handle delta as direct ops array
        for (final op in delta) {
          if (op is Map && op.containsKey('insert') && op['insert'] is Map) {
            final insert = op['insert'] as Map;
            if (insert.containsKey('image')) {
              final imagePath = insert['image'];
              if (imagePath is String && !imagePath.startsWith('data:') && !imagePath.startsWith('http')) {
                debugPrint(
                  '🖼️ [ReportSectionConverter] Original path: $imagePath',
                );
                // Resolve relative path to absolute path
                final resolvedPath = ImagePathHelper.resolveImagePath(imagePath);
                insert['image'] = resolvedPath;
                debugPrint(
                  '🖼️ [ReportSectionConverter] Resolved to: $resolvedPath',
                );

                // Verify file exists
                if (!kIsWeb) {
                  final file = File(resolvedPath);
                  final exists = await file.exists();
                  debugPrint('🖼️ [ReportSectionConverter] File exists: $exists');
                  if (!exists) {
                    debugPrint('❌ [ReportSectionConverter] File not found at: $resolvedPath');
                  }
                }
              }
            }
          }
        }
      }

      debugPrint('📄 [ReportSectionConverter] Creating Document from delta...');
      final document = Document.fromJson(delta);
      debugPrint('📄 [ReportSectionConverter] Document created, getting ops...');
      final ops = document.toDelta().toList();
      debugPrint('📄 [ReportSectionConverter] Got ${ops.length} ops');

      // Check for images and log their paths
      int imageCount = 0;
      for (final op in ops) {
        if (op.data is Map) {
          final embed = op.data as Map;
          if (embed.containsKey('image')) {
            imageCount++;
            final imagePath = embed['image'];
            debugPrint(
              '🖼️ [#$imageCount] flutter_quill_to_pdf will load image from: $imagePath',
            );

            if (!kIsWeb && imagePath is String && !imagePath.startsWith('data:') && !imagePath.startsWith('http')) {
              final file = File(imagePath);
              final exists = await file.exists();
              debugPrint('🖼️ [#$imageCount] Image file accessible: $exists');
              if (!exists) {
                debugPrint('❌ [#$imageCount] Image file not accessible at: $imagePath');
              }
            }
          }
        }
      }
      debugPrint('📄 [ReportSectionConverter] Found $imageCount images in ops');

      final pdfConverter = PDFConverter(
        document: document.toDelta(),
        pageFormat: PDFPageFormat.a4,
        fallbacks: [
          await PdfGoogleFonts.openSansRegular(),
          await PdfGoogleFonts.openSansBold(),
          await PdfGoogleFonts.openSansItalic(),
          await PdfGoogleFonts.openSansBoldItalic(),
        ],
      );

      debugPrint('📝 Calling flutter_quill_to_pdf generateWidget()...');
      final widget = await pdfConverter.generateWidget();
      debugPrint('✅ flutter_quill_to_pdf returned widget: ${widget != null}');
      return widget != null ? [widget] : [];
    } catch (e, stack) {
      debugPrint('ReportSectionConverter error: $e');
      debugPrint('Stack: $stack');
      try {
        final delta = jsonDecode(deltaJson);
        final document = Document.fromJson(delta);
        final plainText = document.toPlainText();
        return [pw.Text(plainText, style: const pw.TextStyle(fontSize: 9))];
      } catch (_) {
        return [pw.Text(deltaJson, style: const pw.TextStyle(fontSize: 9))];
      }
    }
  }

}
