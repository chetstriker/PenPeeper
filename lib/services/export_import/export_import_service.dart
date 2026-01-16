import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:penpeeper/database_helper.dart';
import 'package:penpeeper/models/export_data.dart';
import 'package:penpeeper/utils/delta_image_path_converter.dart';
import 'package:penpeeper/services/app_paths_service.dart';

class ExportImportService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<ExportData> exportProjects(List<int> projectIds) async {
    final projects = <ProjectExport>[];

    for (final projectId in projectIds) {
      final project = await _exportSingleProject(projectId);
      projects.add(project);
    }

    return ExportData(
      projects: projects,
      version: '1.0',
      exportedAt: DateTime.now(),
    );
  }

  Future<ProjectExport> _exportSingleProject(int projectId) async {
    final db = await _dbHelper.database;

    // Get project
    final projectList = await db.query('projects', where: 'id = ?', whereArgs: [projectId]);
    final project = projectList.first;
    debugPrint('=== EXPORT PROJECT ${project['name']} (ID: $projectId) ===');

    // Get devices
    final devices = await db.query('devices', where: 'project_id = ?', whereArgs: [projectId]);
    debugPrint('Exporting ${devices.length} devices');

    // Get scans - ALL scans for all devices
    final allScans = await db.rawQuery('''
      SELECT s.* FROM scans s
      JOIN devices d ON s.device_id = d.id
      WHERE d.project_id = ?
    ''', [projectId]);
    debugPrint('Exporting ${allScans.length} total scans');
    
    final nmapScans = allScans.where((s) => s['name'] == 'AUTO NMAP').toList();
    final niktoScans = allScans.where((s) => (s['name'] as String).contains('NIKTO')).toList();
    final searchsploitScans = allScans.where((s) => (s['name'] as String).contains('SEARCHSPLOIT')).toList();
    final otherScans = allScans.where((s) => 
      s['name'] != 'AUTO NMAP' && 
      !(s['name'] as String).contains('NIKTO') && 
      !(s['name'] as String).contains('SEARCHSPLOIT')
    ).toList();
    debugPrint('  - NMAP: ${nmapScans.length}');
    debugPrint('  - Nikto: ${niktoScans.length}');
    debugPrint('  - SearchSploit: ${searchsploitScans.length}');
    debugPrint('  - Other: ${otherScans.length}');

    // Get nmap details
    final deviceIds = devices.map((d) => d['id']).toList();
    
    // Get findings - use project_id to include all findings (including non-device findings with device_id = 0)
    final rawFindings = await db.query('flagged_findings', where: 'project_id = ?', whereArgs: [projectId]);
    debugPrint('Exporting ${rawFindings.length} findings');

    // Convert all image paths in findings to relative paths for cross-platform compatibility
    final findings = rawFindings
        .map((f) => DeltaImagePathConverter.convertFindingToRelativePaths(f))
        .toList();

    for (final finding in findings) {
      debugPrint('  - Device ${finding['device_id']}: ${finding['type']} (finding_type: ${finding['finding_type']}, project_id: ${finding['project_id']})');
    }

    // Get classifications - only those with valid finding references
    final findingIds = findings.map((f) => f['id']).toList();
    final classifications = findingIds.isEmpty ? <Map<String, dynamic>>[] : await db.rawQuery('''
      SELECT * FROM vulnerability_classifications 
      WHERE project_id = ? AND finding_id IN (${findingIds.join(',')})
    ''', [projectId]);

    // Get report sections and convert image paths to relative
    final rawReportSections = await db.query('report_sections', where: 'project_id = ?', whereArgs: [projectId]);
    final reportSections = rawReportSections
        .map((s) => DeltaImagePathConverter.convertReportSectionToRelativePaths(s))
        .toList();

    // Get tags
    final tags = await db.rawQuery('''
      SELECT DISTINCT dt.* FROM device_tags dt
      JOIN devices d ON dt.device_id = d.id
      WHERE d.project_id = ?
    ''', [projectId]);
    final nmapHosts = deviceIds.isEmpty ? <Map<String, dynamic>>[] : await db.rawQuery('''
      SELECT * FROM nmap_hosts WHERE device_id IN (${deviceIds.join(',')})
    ''');

    final hostIds = nmapHosts.map((h) => h['id']).toList();
    final nmapOsMatches = hostIds.isEmpty ? <Map<String, dynamic>>[] : await db.rawQuery('''
      SELECT * FROM nmap_os_matches WHERE host_id IN (${hostIds.join(',')})
    ''');
    debugPrint('Exporting ${nmapOsMatches.length} OS matches');
    final nmapPorts = hostIds.isEmpty ? <Map<String, dynamic>>[] : await db.rawQuery('''
      SELECT * FROM nmap_ports WHERE host_id IN (${hostIds.join(',')})
    ''');

    final portIds = nmapPorts.map((p) => p['id']).toList();
    final nmapScripts = portIds.isEmpty ? <Map<String, dynamic>>[] : await db.rawQuery('''
      SELECT * FROM nmap_scripts WHERE port_id IN (${portIds.join(',')})
    ''');

    // Get nikto findings (handle missing table)
    List<Map<String, dynamic>> niktoFindings = [];
    try {
      niktoFindings = await db.rawQuery('''
        SELECT nf.* FROM nikto_findings nf
        JOIN devices d ON nf.device_id = d.id
        WHERE d.project_id = ?
      ''', [projectId]);
    } catch (e) {
      debugPrint('nikto_findings table not found, skipping');
    }

    // Get searchsploit results
    List<Map<String, dynamic>> searchsploitResults = [];
    try {
      searchsploitResults = await db.rawQuery('''
        SELECT v.* FROM vulnerabilities v
        JOIN devices d ON v.device_id = d.id
        WHERE d.project_id = ? AND v.type = 'SearchSploit'
      ''', [projectId]);
    } catch (e) {
      debugPrint('vulnerabilities table not found, skipping');
    }

    // Get ffuf findings
    List<Map<String, dynamic>> ffufFindings = [];
    try {
      ffufFindings = deviceIds.isEmpty ? [] : await db.rawQuery('''
        SELECT * FROM ffuf_findings WHERE device_id IN (${deviceIds.join(',')})
      ''');
    } catch (e) {
      debugPrint('ffuf_findings table not found, skipping');
    }

    // Get whatweb findings
    List<Map<String, dynamic>> whatwebFindings = [];
    try {
      whatwebFindings = deviceIds.isEmpty ? [] : await db.rawQuery('''
        SELECT * FROM whatweb_findings WHERE device_id IN (${deviceIds.join(',')})
      ''');
    } catch (e) {
      debugPrint('whatweb_findings table not found, skipping');
    }

    // Get samba/ldap findings
    List<Map<String, dynamic>> sambaLdapFindings = [];
    try {
      sambaLdapFindings = deviceIds.isEmpty ? [] : await db.rawQuery('''
        SELECT * FROM samba_ldap_findings WHERE device_id IN (${deviceIds.join(',')})
      ''');
    } catch (e) {
      debugPrint('samba_ldap_findings table not found, skipping');
    }

    // Get snmp findings
    List<Map<String, dynamic>> snmpFindings = [];
    try {
      snmpFindings = await db.query('snmp_findings', where: 'project_id = ?', whereArgs: [projectId]);
    } catch (e) {
      debugPrint('snmp_findings table not found, skipping');
    }

    // Collect upload files
    final uploadFiles = await _collectUploadFiles(projectId);

    debugPrint('=== EXPORT COMPLETE ===\n');
    
    return ProjectExport(
      project: project,
      devices: devices,
      nmapScans: [...nmapScans, ...otherScans],
      niktoScans: niktoScans,
      searchsploitScans: searchsploitScans,
      findings: findings,
      classifications: classifications,
      reportSections: reportSections,
      tags: tags,
      nmapHosts: nmapHosts,
      nmapOsMatches: nmapOsMatches,
      nmapPorts: nmapPorts,
      nmapScripts: nmapScripts,
      niktoFindings: niktoFindings,
      searchsploitResults: searchsploitResults,
      ffufFindings: ffufFindings,
      whatwebFindings: whatwebFindings,
      sambaLdapFindings: sambaLdapFindings,
      snmpFindings: snmpFindings,
      uploadFiles: uploadFiles,
    );
  }

  Future<List<String>> _collectUploadFiles(int projectId) async {
    if (kIsWeb) return [];

    final db = await _dbHelper.database;

    // Get all unique image paths from findings and report sections
    final imagePaths = <String>{};

    // Extract from findings
    final findings = await db.query('flagged_findings', where: 'project_id = ?', whereArgs: [projectId]);
    for (final finding in findings) {
      for (final field in ['comment', 'evidence', 'recommendation']) {
        final deltaJson = finding[field] as String?;
        if (deltaJson != null && deltaJson.isNotEmpty) {
          imagePaths.addAll(_extractImagePathsFromDelta(deltaJson));
        }
      }
    }

    // Extract from report sections
    final reportSections = await db.query('report_sections', where: 'project_id = ?', whereArgs: [projectId]);
    for (final section in reportSections) {
      final content = section['content'] as String?;
      if (content != null && content.isNotEmpty) {
        imagePaths.addAll(_extractImagePathsFromDelta(content));
      }
    }

    debugPrint('Found ${imagePaths.length} unique image references in database');

    // Collect files that actually exist on disk
    final files = <String>[];
    final baseDir = AppPathsService().appDataDir;

    for (final imagePath in imagePaths) {
      // Skip data URIs and risk.png (it's not in uploads)
      if (imagePath.startsWith('data:') || imagePath == 'risk.png') {
        continue;
      }

      // Convert forward slashes to platform-specific path separator
      final normalizedPath = imagePath.replaceAll('/', Platform.pathSeparator);

      // Try to resolve the file
      // Check if path is already absolute to avoid doubling the base path
      final absolutePath = path.isAbsolute(normalizedPath)
          ? normalizedPath
          : path.join(baseDir, normalizedPath);
      final file = File(absolutePath);

      if (await file.exists()) {
        // Normalize to relative path for export (strip base directory if present)
        String exportPath = imagePath;
        if (path.isAbsolute(normalizedPath)) {
          // Convert absolute path to relative by removing the base directory
          final relativePathNormalized = path.relative(normalizedPath, from: baseDir);
          // Convert back to forward slashes for cross-platform compatibility
          exportPath = relativePathNormalized.replaceAll(Platform.pathSeparator, '/');
        }

        files.add(exportPath);
        debugPrint('  Found file: $imagePath -> $absolutePath');
        if (imagePath != exportPath) {
          debugPrint('    Normalized to relative: $exportPath');
        }
      } else {
        debugPrint('  ⚠️ File not found: $imagePath (expected at $absolutePath)');
      }
    }

    debugPrint('Collected ${files.length} upload files that exist on disk');
    return files;
  }

  /// Extract image paths from Quill delta JSON
  Set<String> _extractImagePathsFromDelta(String deltaJson) {
    final paths = <String>{};

    try {
      final delta = jsonDecode(deltaJson);
      List ops;

      if (delta is List) {
        ops = delta;
      } else if (delta is Map && delta.containsKey('ops')) {
        ops = delta['ops'] as List;
      } else {
        return paths;
      }

      for (final op in ops) {
        if (op is Map && op.containsKey('insert') && op['insert'] is Map) {
          final insert = op['insert'] as Map;
          if (insert.containsKey('image')) {
            final imagePath = insert['image'];
            if (imagePath is String) {
              paths.add(imagePath);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting image paths: $e');
    }

    return paths;
  }
}
