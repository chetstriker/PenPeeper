import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show TextSelection;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:file_picker/file_picker.dart';

/// Service for exporting data to CSV format
class CsvExportService {
  /// Exports flagged findings to CSV file
  Future<String?> exportFlaggedFindings({
    required List<Map<String, dynamic>> findings,
    required Future<String> Function(int deviceId) getMacAddress,
    required Future<List<String>> Function(int deviceId) getDeviceTags,
    String? defaultFileName,
  }) async {
    if (findings.isEmpty) {
      throw Exception('No findings to export');
    }

    final csvContent = StringBuffer();
    csvContent.writeln('Host,IP,MAC,Severity,Tags,Finding');
    
    for (final finding in findings) {
      final name = _escapeCsv((finding['device_name'] ?? 'Unknown').toString());
      final ip = finding['ip_address'] ?? 'Unknown';
      final type = finding['type'] ?? 'Unknown';
      final comment = _getPlainTextFromComment(finding['comment'] ?? '');
      
      final macAddress = await getMacAddress(finding['device_id']);
      final tags = await getDeviceTags(finding['device_id']);
      final tagsStr = tags.join(', ');
      
      csvContent.writeln('"$name","$ip","$macAddress","$type","$tagsStr","$comment"');
    }

    return _saveFile(
      content: csvContent.toString(),
      fileName: defaultFileName ?? 'flagged_findings_${DateTime.now().millisecondsSinceEpoch}.csv',
      dialogTitle: 'Save Flagged Findings CSV',
    );
  }

  /// Exports vendor list to CSV
  Future<String?> exportVendorList(List<String> vendors, {String? defaultFileName}) async {
    if (vendors.isEmpty) {
      throw Exception('No vendors to export');
    }

    final csvContent = StringBuffer();
    csvContent.writeln('MAC Vendor');
    for (final vendor in vendors) {
      csvContent.writeln('"$vendor"');
    }

    return _saveFile(
      content: csvContent.toString(),
      fileName: defaultFileName ?? 'penpeeper_vendors_${DateTime.now().millisecondsSinceEpoch}.csv',
      dialogTitle: 'Save Vendor List Export',
    );
  }

  /// Exports banner list to CSV
  Future<String?> exportBannerList(List<String> banners, {String? defaultFileName}) async {
    if (banners.isEmpty) {
      throw Exception('No banners to export');
    }

    final csvContent = StringBuffer();
    csvContent.writeln('Banner');
    for (final banner in banners) {
      csvContent.writeln('"$banner"');
    }

    return _saveFile(
      content: csvContent.toString(),
      fileName: defaultFileName ?? 'penpeeper_banners_${DateTime.now().millisecondsSinceEpoch}.csv',
      dialogTitle: 'Save Banner List Export',
    );
  }

  /// Exports OS list to CSV
  Future<String?> exportOSList(List<String> operatingSystems, {String? defaultFileName}) async {
    if (operatingSystems.isEmpty) {
      throw Exception('No operating systems to export');
    }

    final csvContent = StringBuffer();
    csvContent.writeln('Operating System');
    for (final os in operatingSystems) {
      csvContent.writeln('"$os"');
    }

    return _saveFile(
      content: csvContent.toString(),
      fileName: defaultFileName ?? 'penpeeper_operating_systems_${DateTime.now().millisecondsSinceEpoch}.csv',
      dialogTitle: 'Save OS List Export',
    );
  }

  /// Exports search results to CSV
  Future<String?> exportSearchResults(List<Map<String, dynamic>> results, String activeFilter, {String? defaultFileName}) async {
    if (results.isEmpty) {
      throw Exception('No results to export');
    }

    final csvContent = StringBuffer();
    csvContent.writeln('Device Name,IP Address,Filter,Count');
    
    for (final result in results) {
      final name = _escapeCsv((result['name'] ?? 'Unknown').toString());
      final ip = result['ip_address'] ?? 'Unknown';
      final filter = activeFilter.isNotEmpty ? activeFilter : 'Search Results';
      final count = result['count']?.toString() ?? '1';
      csvContent.writeln('"$name","$ip","$filter","$count"');
    }

    return _saveFile(
      content: csvContent.toString(),
      fileName: defaultFileName ?? 'penpeeper_findings_${DateTime.now().millisecondsSinceEpoch}.csv',
      dialogTitle: 'Save CSV Export',
    );
  }

  /// Exports filter results with detailed records
  Future<String?> exportFilterResults({
    required List<Map<String, dynamic>> devices,
    required String filter,
    required Future<List<Map<String, dynamic>>> Function(int deviceId, String filter) getRecords,
    String? defaultFileName,
  }) async {
    if (devices.isEmpty) {
      throw Exception('No results to export');
    }

    final csvContent = StringBuffer();
    
    switch (filter) {
      case 'FFUF':
        csvContent.writeln('Device Name,IP Address,URL,Status,Words');
        for (final device in devices) {
          final records = await getRecords(device['id'], filter);
          for (final record in records) {
            csvContent.writeln('"${device['name']}","${device['ip_address']}","${record['url']}",${record['status']},${record['words']}');
          }
        }
        break;
      case 'SAMBA':
        csvContent.writeln('Device Name,IP Address,Finding Type,Finding Value');
        for (final device in devices) {
          final records = await getRecords(device['id'], filter);
          for (final record in records) {
            csvContent.writeln('"${device['name']}","${device['ip_address']}","${record['finding_type']}","${record['finding_value']}"');
          }
        }
        break;
      case 'WhatWeb':
        csvContent.writeln('Device Name,IP Address,Finding');
        for (final device in devices) {
          final records = await getRecords(device['id'], filter);
          for (final record in records) {
            csvContent.writeln('"${device['name']}","${device['ip_address']}","${record['finding']}"');
          }
        }
        break;
      case 'SearchSploit':
        csvContent.writeln('Device Name,IP Address,Title,Severity');
        for (final device in devices) {
          final records = await getRecords(device['id'], filter);
          for (final record in records) {
            csvContent.writeln('"${device['name']}","${device['ip_address']}","${record['title']}","${record['severity']}"');
          }
        }
        break;
      case 'Vulners':
        csvContent.writeln('Device Name,IP Address,CVE ID,CVSS');
        for (final device in devices) {
          final records = await getRecords(device['id'], filter);
          for (final record in records) {
            csvContent.writeln('"${device['name']}","${device['ip_address']}","${record['cve_id']}",${record['cvss']}');
          }
        }
        break;
      default:
        csvContent.writeln('Device Name,IP Address');
        for (final device in devices) {
          csvContent.writeln('"${device['name']}","${device['ip_address']}"');
        }
    }

    return _saveFile(
      content: csvContent.toString(),
      fileName: defaultFileName ?? 'penpeeper_${filter.toLowerCase()}_results_${DateTime.now().millisecondsSinceEpoch}.csv',
      dialogTitle: 'Save Results Export',
    );
  }

  /// Saves content to a CSV file
  Future<String?> _saveFile({
    required String content,
    required String fileName,
    required String dialogTitle,
  }) async {
    if (kIsWeb) {
      final bytes = utf8.encode(content);
      final result = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        bytes: bytes,
      );
      return result;
    } else {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      
      if (result != null) {
        final file = File(result);
        await file.writeAsString(content);
        return file.path;
      }
    }
    
    return null;
  }

  /// Escapes CSV special characters
  String _escapeCsv(String text) {
    return text.replaceAll('"', '""').replaceAll(',', ';');
  }

  /// Extracts plain text from Quill Delta JSON
  String _getPlainTextFromComment(String comment) {
    try {
      final delta = jsonDecode(comment);
      final document = Document.fromJson(delta);
      final controller = QuillController(
        document: document,
        selection: const TextSelection(baseOffset: 0, extentOffset: 0),
      );
      return controller.document.toPlainText().replaceAll('"', '""');
    } catch (e) {
      return comment.replaceAll('"', '""');
    }
  }
}
