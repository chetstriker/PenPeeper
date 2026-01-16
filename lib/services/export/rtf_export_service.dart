import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:penpeeper/services/export/rtf_converter.dart';

/// Service for exporting findings to RTF format
class RtfExportService {
  final RtfConverter _converter = RtfConverter();

  /// Exports flagged findings to RTF file
  /// Returns the file path on success, null on cancellation
  Future<String?> exportFlaggedFindings({
    required List<Map<String, dynamic>> findings,
    required Future<String> Function(int deviceId) getMacAddress,
    required Future<List<String>> Function(int deviceId) getDeviceTags,
    String? defaultFileName,
  }) async {
    if (findings.isEmpty) {
      throw Exception('No findings to export');
    }

    _converter.resetColorTable();

    final rtfContent = StringBuffer();
    final findingsContent = StringBuffer();
    
    // Process all findings first to build color table
    final processedFindings = <Map<String, dynamic>>[];
    for (final finding in findings) {
      final comment = finding['comment'] ?? '';
      final rtfComment = await _converter.convertQuillDeltaToRTF(comment);
      processedFindings.add({
        ...finding,
        'rtf_comment': rtfComment,
      });
    }
    
    // RTF header
    rtfContent.writeln('{\\rtf1\\ansi\\deff0 {\\fonttbl {\\f0\\fswiss\\fcharset0 Arial;}{\\f1\\fmodern\\fcharset0 Courier New;}}');
    rtfContent.writeln(_converter.buildColorTable());
    rtfContent.writeln('\\f0\\fs20 ');
    
    for (final finding in processedFindings) {
      final name = _converter.escapeRTFText((finding['device_name'] ?? 'Unknown').toString());
      final ip = _converter.escapeRTFText(finding['ip_address'] ?? 'Unknown');
      final type = _converter.escapeRTFText(finding['type'] ?? 'Unknown');
      final rtfComment = finding['rtf_comment'] ?? '';
      
      final macAddress = await getMacAddress(finding['device_id']);
      final tags = await getDeviceTags(finding['device_id']);
      final tagsStr = _converter.escapeRTFText(tags.join(', '));
      final escapedMac = _converter.escapeRTFText(macAddress);
      
      findingsContent.writeln('{\\cf1\\b TAGS:} $tagsStr\\par');
      findingsContent.writeln('{\\cf1\\b HOST:} $name\\par');
      findingsContent.writeln('{\\cf1\\b IP:} $ip\\par');
      findingsContent.writeln('{\\cf1\\b MAC:} $escapedMac\\par');
      findingsContent.writeln('{\\cf1\\b TYPE:} $type\\par');
      findingsContent.writeln('{\\cf1\\b FINDING:}\\par');
      if (rtfComment.isNotEmpty) {
        findingsContent.writeln('$rtfComment\\par');
      }
      
      findingsContent.writeln('\\par\\par');
    }
    
    rtfContent.write(findingsContent.toString());
    rtfContent.writeln('}');

    final fileName = defaultFileName ?? 'flagged_findings_${DateTime.now().millisecondsSinceEpoch}.rtf';

    if (kIsWeb) {
      final bytes = utf8.encode(rtfContent.toString());
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Flagged Findings RTF',
        fileName: fileName,
        bytes: bytes,
      );
      return result;
    } else {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Flagged Findings RTF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['rtf'],
      );
      
      if (result != null) {
        var filePath = result;
        if (!filePath.toLowerCase().endsWith('.rtf')) {
          filePath = '$filePath.rtf';
        }
        final file = File(filePath);
        await file.writeAsString(rtfContent.toString());
        return filePath;
      }
    }
    
    return null;
  }
}
