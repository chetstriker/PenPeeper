import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:penpeeper/database_helper.dart';
import 'package:penpeeper/repositories/project_repository.dart';
import 'package:penpeeper/models/export_data.dart';
import 'package:penpeeper/services/export_import/archive_service.dart';
import 'package:penpeeper/services/export_import/conflict_resolver.dart';
import 'package:penpeeper/services/export_import/validation_service.dart';
import 'package:penpeeper/services/export_import/error_handler.dart';
import 'package:penpeeper/services/export_import/rollback_service.dart';
import 'package:penpeeper/services/app_paths_service.dart';

class ImportResult {
  final bool success;
  final List<String> importedProjects;
  final List<String> errors;
  final int totalProjects;

  ImportResult({
    required this.success,
    required this.importedProjects,
    required this.errors,
    required this.totalProjects,
  });
}

class ImportService {
  final ArchiveService _archiveService = ArchiveService();
  final ConflictResolver _conflictResolver = ConflictResolver();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ValidationService _validationService = ValidationService();
  final RollbackService _rollbackService = RollbackService();

  Future<ImportResult> importArchive(
    Uint8List archiveData,
    String password,
  ) async {
    try {
      final exportData = await _archiveService.extractArchive(
        archiveData,
        password,
      );

      final archiveValidation = _validationService.validateArchiveStructure(
        exportData.metadata,
        exportData.projects.map((p) => p.project).toList(),
      );

      if (!archiveValidation.isValid) {
        return ImportResult(
          success: false,
          importedProjects: [],
          errors: archiveValidation.errors,
          totalProjects: exportData.projects.length,
        );
      }

      final conflicts = await _conflictResolver.findConflicts(
        exportData.projects,
      );

      if (conflicts.isNotEmpty) {
        return ImportResult(
          success: false,
          importedProjects: [],
          errors: [
            'Conflicts detected: ${conflicts.map((c) => c.projectName).join(', ')}',
          ],
          totalProjects: exportData.projects.length,
        );
      }

      return await importProjects(exportData, {}, archiveData, password);
    } catch (e, stack) {
      if (e is Exception) {
        ExportImportErrorHandler.logError('importArchive', e, stack);
        return ImportResult(
          success: false,
          importedProjects: [],
          errors: [ExportImportErrorHandler.getUserFriendlyMessage(e)],
          totalProjects: 0,
        );
      }
      rethrow;
    }
  }

  Future<List<ProjectConflict>> detectConflicts(ExportData exportData) async {
    return await _conflictResolver.findConflicts(exportData.projects);
  }

  Future<ImportResult> importProjects(
    ExportData exportData,
    Map<String, ConflictResolution> resolutions,
    Uint8List? archiveData,
    String? password,
  ) async {
    final importedProjects = <String>[];
    final errors = <String>[];
    final importedProjectIds = <int>[];

    try {
      for (final project in exportData.projects) {
        try {
          final projectValidation = _validationService.validateProjectData(
            project.project,
          );
          if (!projectValidation.isValid) {
            errors.add(
              '${project.project['name']}: ${projectValidation.errors.join(', ')}',
            );
            continue;
          }

          final projectData = {
            ...project.project,
            'devices': project.devices,
            'nmap_hosts': project.nmapHosts,
            'nmap_ports': project.nmapPorts,
            'nmap_scripts': project.nmapScripts,
            'scans': [
              ...project.nmapScans,
              ...project.niktoScans,
              ...project.searchsploitScans,
            ],
            'findings': project.findings,
            'classifications': project.classifications,
            'upload_files': project.uploadFiles
                .map((f) => {'file_path': f})
                .toList(),
          };

          final fkErrors = _validationService.validateForeignKeys(projectData);
          if (fkErrors.isNotEmpty) {
            errors.add('${project.project['name']}: ${fkErrors.join(', ')}');
            continue;
          }

          if (!_validationService.validateFileReferences(projectData)) {
            errors.add(
              '${project.project['name']}: Invalid file references detected',
            );
            continue;
          }

          final projectName = project.project['name'] as String;
          final resolution = resolutions[projectName];

          if (resolution == ConflictResolution.cancel) {
            continue;
          }

          if (resolution == ConflictResolution.replace) {
            final existing = await _conflictResolver.getExistingProject(
              projectName,
            );
            if (existing != null) {
              final projectRepo = ProjectRepository();
              await projectRepo.deleteProject(existing['id'] as int);
            }
          }

          String finalName = projectName;
          if (resolution == ConflictResolution.rename) {
            finalName = await _conflictResolver.generateUniqueNameAsync(
              projectName,
            );
          }

          final projectId = await _importSingleProject(project, finalName);
          importedProjectIds.add(projectId);
          importedProjects.add(finalName);

          // Extract upload files
          if (!kIsWeb && archiveData != null && password != null) {
            await _extractUploadFiles(
              archiveData,
              password,
              project.project['name'] as String,
              finalName,
            );
          }
        } catch (e, stack) {
          if (e is Exception) {
            ExportImportErrorHandler.logError('importProject', e, stack);
            errors.add(
              '${project.project['name']}: ${ExportImportErrorHandler.getUserFriendlyMessage(e)}',
            );
          } else {
            errors.add('${project.project['name']}: Unexpected error');
          }

          await _rollbackService.rollbackImport(importedProjectIds);
          importedProjectIds.clear();
          importedProjects.clear();
          break;
        }
      }

      return ImportResult(
        success: errors.isEmpty,
        importedProjects: importedProjects,
        errors: errors,
        totalProjects: exportData.projects.length,
      );
    } catch (e, stack) {
      if (e is Exception) {
        ExportImportErrorHandler.logError('importProjects', e, stack);
        await _rollbackService.rollbackImport(importedProjectIds);
        return ImportResult(
          success: false,
          importedProjects: [],
          errors: [ExportImportErrorHandler.getUserFriendlyMessage(e)],
          totalProjects: exportData.projects.length,
        );
      }
      rethrow;
    }
  }

  /// Updates project name in relative image paths within Quill delta JSON
  /// Example: "uploads/OldProject/image.png" -> "uploads/NewProject/image.png"
  /// Also handles cases where images reference a different project folder
  String? _updateProjectNameInDelta(
    String? deltaJson,
    String oldProjectName,
    String newProjectName,
  ) {
    if (deltaJson == null || deltaJson.isEmpty) {
      return deltaJson;
    }

    try {
      final delta = jsonDecode(deltaJson);
      List ops;

      if (delta is List) {
        ops = delta;
      } else if (delta is Map && delta.containsKey('ops')) {
        ops = delta['ops'] as List;
      } else {
        return deltaJson;
      }

      bool modified = false;
      int imageCount = 0;
      for (final op in ops) {
        if (op is Map && op.containsKey('insert') && op['insert'] is Map) {
          final insert = op['insert'] as Map;
          if (insert.containsKey('image')) {
            imageCount++;
            final imagePath = insert['image'] as String?;
            if (imagePath != null) {
              debugPrint(
                '[Import] Found image #$imageCount: $imagePath',
              );

              // Update any uploads path to use the new project name
              // This handles both renamed projects and projects where uploads dir doesn't match
              if (imagePath.startsWith('uploads/') && !imagePath.startsWith('uploads/$newProjectName/')) {
                // Extract just the filename from the old path
                final fileName = imagePath.split('/').last;
                final newPath = 'uploads/$newProjectName/$fileName';
                insert['image'] = newPath;
                modified = true;
                debugPrint(
                  '[Import]   -> Updated to: $newPath',
                );
              } else {
                debugPrint(
                  '[Import]   -> Already points to correct project folder',
                );
              }
            }
          }
        }
      }

      if (imageCount == 0) {
        debugPrint('[Import] No images found in delta');
      } else {
        debugPrint('[Import] Processed $imageCount images, $modified modified');
      }

      if (modified) {
        return delta is List ? jsonEncode(ops) : jsonEncode(delta);
      }
      return deltaJson;
    } catch (e) {
      debugPrint('[Import] Error updating project name in delta: $e');
      return deltaJson;
    }
  }

  /// Updates project name in a finding record's image paths
  Map<String, dynamic> _updateProjectNameInFinding(
    Map<String, dynamic> finding,
    String oldProjectName,
    String newProjectName,
  ) {
    final result = Map<String, dynamic>.from(finding);

    debugPrint('[Import] Updating finding ${finding['id']} paths');
    if (result['comment'] != null) {
      debugPrint('[Import]   Processing comment field');
      result['comment'] = _updateProjectNameInDelta(
        result['comment'] as String?,
        oldProjectName,
        newProjectName,
      );
    }
    if (result['evidence'] != null) {
      debugPrint('[Import]   Processing evidence field');
      result['evidence'] = _updateProjectNameInDelta(
        result['evidence'] as String?,
        oldProjectName,
        newProjectName,
      );
    }
    if (result['recommendation'] != null) {
      debugPrint('[Import]   Processing recommendation field');
      result['recommendation'] = _updateProjectNameInDelta(
        result['recommendation'] as String?,
        oldProjectName,
        newProjectName,
      );
    }

    return result;
  }

  /// Updates project name in a report section's image paths
  Map<String, dynamic> _updateProjectNameInReportSection(
    Map<String, dynamic> section,
    String oldProjectName,
    String newProjectName,
  ) {
    final result = Map<String, dynamic>.from(section);

    debugPrint(
      '[Import] Updating report section ${section['section_type']} paths',
    );
    if (result['content'] != null) {
      debugPrint('[Import]   Processing content field');
      result['content'] = _updateProjectNameInDelta(
        result['content'] as String?,
        oldProjectName,
        newProjectName,
      );
    }

    return result;
  }

  Future<int> _importSingleProject(
    ProjectExport project,
    String projectName,
  ) async {
    final db = await _dbHelper.database;
    final originalProjectName = project.project['name'] as String;

    return await db.transaction((txn) async {
      debugPrint('=== IMPORT PROJECT $projectName ===');
      debugPrint('Original project name: $originalProjectName');
      debugPrint('Final project name: $projectName');
      if (originalProjectName != projectName) {
        debugPrint('⚠️ Project will be renamed - image paths will be updated');
      }

      // Insert project
      final projectData = Map<String, dynamic>.from(project.project);
      projectData['name'] = projectName;
      final projectId = await txn.insert('projects', projectData);
      debugPrint('Project ID: $projectId');

      // Insert devices
      final deviceIdMap = <int, int>{};
      for (final device in project.devices) {
        final deviceData = Map<String, dynamic>.from(device);
        deviceData['project_id'] = projectId;
        final oldDeviceId = deviceData['id'];
        deviceData.remove('id');
        final newDeviceId = await txn.insert('devices', deviceData);
        deviceIdMap[oldDeviceId] = newDeviceId;
      }
      debugPrint('Imported ${project.devices.length} devices');

      // Insert scans
      final totalScans = [
        ...project.nmapScans,
        ...project.niktoScans,
        ...project.searchsploitScans,
      ];
      debugPrint('Importing ${totalScans.length} scans');
      for (final scan in totalScans) {
        final scanData = Map<String, dynamic>.from(scan);
        final oldDeviceId = scanData['device_id'];
        scanData['device_id'] = deviceIdMap[oldDeviceId];
        scanData.remove('id');
        await txn.insert('scans', scanData);
      }

      // Insert findings with updated project names in image paths
      debugPrint('Importing ${project.findings.length} findings');
      final findingIdMap = <int, int>{};
      for (final finding in project.findings) {
        // Update project name in image paths if project was renamed
        final findingWithUpdatedPaths = _updateProjectNameInFinding(
          finding,
          originalProjectName,
          projectName,
        );

        final findingData = Map<String, dynamic>.from(findingWithUpdatedPaths);
        final oldDeviceId = findingData['device_id'];
        final oldFindingId = findingData['id'];

        // Handle device_id = 0 (non-device findings) specially
        int? newDeviceId;
        if (oldDeviceId == 0) {
          newDeviceId = 0;
        } else {
          newDeviceId = deviceIdMap[oldDeviceId];
          if (newDeviceId == null) {
            debugPrint(
              '  WARNING: Device ID mapping not found for old device ID $oldDeviceId, skipping finding',
            );
            continue;
          }
        }

        findingData['device_id'] = newDeviceId;
        findingData['project_id'] = projectId;
        findingData.remove('id');
        debugPrint(
          '  - Importing finding for device $newDeviceId: ${findingData['type']} (finding_type: ${findingData['finding_type']})',
        );
        final newFindingId = await txn.insert('flagged_findings', findingData);
        findingIdMap[oldFindingId] = newFindingId;
      }

      // Insert classifications
      debugPrint('Importing ${project.classifications.length} classifications');
      for (final classification in project.classifications) {
        final classData = Map<String, dynamic>.from(classification);
        final oldDeviceId = classData['device_id'];
        final oldFindingId = classData['finding_id'];

        // Handle device_id = 0 (non-device findings) specially
        int? newDeviceId;
        if (oldDeviceId == 0) {
          newDeviceId = 0;
        } else {
          newDeviceId = deviceIdMap[oldDeviceId];
        }

        final newFindingId = findingIdMap[oldFindingId];
        if (newDeviceId == null || newFindingId == null) {
          debugPrint(
            '  WARNING: Classification ${classData['id']}: references non-existent finding $oldFindingId',
          );
          continue;
        }
        classData['project_id'] = projectId;
        classData['device_id'] = newDeviceId;
        classData['finding_id'] = newFindingId;
        classData.remove('id');

        // Handle legacy data migration: these fields belong in flagged_findings, not classifications
        // Older exports may have stored these in classifications table
        final legacyRecommendation = classData.remove('recommendation');
        final legacyEvidence = classData.remove('evidence');
        final legacyComment = classData.remove('comment');

        // If any legacy fields have values, update the corresponding finding record
        if (legacyRecommendation != null || legacyEvidence != null || legacyComment != null) {
          final updateFields = <String, dynamic>{};
          if (legacyRecommendation != null && legacyRecommendation.toString().isNotEmpty) {
            updateFields['recommendation'] = legacyRecommendation;
          }
          if (legacyEvidence != null && legacyEvidence.toString().isNotEmpty) {
            updateFields['evidence'] = legacyEvidence;
          }
          if (legacyComment != null && legacyComment.toString().isNotEmpty) {
            updateFields['comment'] = legacyComment;
          }

          if (updateFields.isNotEmpty) {
            debugPrint('  Migrating legacy fields from classification to finding $newFindingId: ${updateFields.keys.join(', ')}');
            await txn.update(
              'flagged_findings',
              updateFields,
              where: 'id = ?',
              whereArgs: [newFindingId],
            );
          }
        }

        await txn.insert('vulnerability_classifications', classData);
      }

      // Insert report sections with updated project names in image paths
      for (final section in project.reportSections) {
        // Update project name in image paths if project was renamed
        final sectionWithUpdatedPaths = _updateProjectNameInReportSection(
          section,
          originalProjectName,
          projectName,
        );

        final sectionData = Map<String, dynamic>.from(sectionWithUpdatedPaths);
        sectionData['project_id'] = projectId;
        sectionData.remove('id');
        await txn.insert(
          'report_sections',
          sectionData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Insert tags
      for (final tag in project.tags) {
        final tagData = Map<String, dynamic>.from(tag);
        final oldDeviceId = tagData['device_id'];
        tagData['device_id'] = deviceIdMap[oldDeviceId];
        tagData.remove('id');
        await txn.insert('device_tags', tagData);
      }

      // Insert nmap data
      final hostIdMap = <int, int>{};
      for (final host in project.nmapHosts) {
        final hostData = Map<String, dynamic>.from(host);
        final oldDeviceId = hostData['device_id'];
        final oldHostId = hostData['id'];
        hostData['device_id'] = deviceIdMap[oldDeviceId];
        hostData.remove('id');
        final newHostId = await txn.insert('nmap_hosts', hostData);
        hostIdMap[oldHostId] = newHostId;
      }

      // Insert nmap OS matches
      debugPrint('Importing ${project.nmapOsMatches.length} OS matches');
      for (final osMatch in project.nmapOsMatches) {
        final osData = Map<String, dynamic>.from(osMatch);
        final oldHostId = osData['host_id'];
        final newHostId = hostIdMap[oldHostId];
        if (newHostId == null) {
          debugPrint('  WARNING: Host ID mapping not found for old host ID $oldHostId');
          continue;
        }
        osData['host_id'] = newHostId;
        osData.remove('id');
        await txn.insert('nmap_os_matches', osData);
      }

      final portIdMap = <int, int>{};
      for (final port in project.nmapPorts) {
        final portData = Map<String, dynamic>.from(port);
        final oldHostId = portData['host_id'];
        final oldPortId = portData['id'];
        portData['host_id'] = hostIdMap[oldHostId];
        portData.remove('id');
        final newPortId = await txn.insert('nmap_ports', portData);
        portIdMap[oldPortId] = newPortId;
      }

      for (final script in project.nmapScripts) {
        final scriptData = Map<String, dynamic>.from(script);
        final oldPortId = scriptData['port_id'];
        scriptData['port_id'] = portIdMap[oldPortId];
        scriptData.remove('id');
        await txn.insert('nmap_scripts', scriptData);
      }

      // Insert nikto findings
      for (final finding in project.niktoFindings) {
        final findingData = Map<String, dynamic>.from(finding);
        final oldDeviceId = findingData['device_id'];
        findingData['device_id'] = deviceIdMap[oldDeviceId];
        findingData.remove('id');
        await txn.insert('nikto_findings', findingData);
      }

      // Insert searchsploit results
      for (final result in project.searchsploitResults) {
        final resultData = Map<String, dynamic>.from(result);
        final oldDeviceId = resultData['device_id'];
        resultData['device_id'] = deviceIdMap[oldDeviceId];
        resultData.remove('id');
        await txn.insert('vulnerabilities', resultData);
      }

      // Insert ffuf findings
      for (final finding in project.ffufFindings) {
        final findingData = Map<String, dynamic>.from(finding);
        final oldDeviceId = findingData['device_id'];
        findingData['device_id'] = deviceIdMap[oldDeviceId];
        findingData.remove('id');
        await txn.insert('ffuf_findings', findingData);
      }

      // Insert whatweb findings
      for (final finding in project.whatwebFindings) {
        final findingData = Map<String, dynamic>.from(finding);
        final oldDeviceId = findingData['device_id'];
        findingData['device_id'] = deviceIdMap[oldDeviceId];
        findingData.remove('id');
        await txn.insert('whatweb_findings', findingData);
      }

      // Insert samba/ldap findings
      for (final finding in project.sambaLdapFindings) {
        final findingData = Map<String, dynamic>.from(finding);
        final oldDeviceId = findingData['device_id'];
        findingData['device_id'] = deviceIdMap[oldDeviceId];
        findingData.remove('id');
        await txn.insert('samba_ldap_findings', findingData);
      }

      // Insert snmp findings
      for (final finding in project.snmpFindings) {
        final findingData = Map<String, dynamic>.from(finding);
        final oldDeviceId = findingData['device_id'];
        findingData['device_id'] = deviceIdMap[oldDeviceId];
        findingData['project_id'] = projectId;
        findingData.remove('id');
        await txn.insert('snmp_findings', findingData);
      }

      // Insert scan ranges
      for (final scanRange in project.scanRanges) {
        final rangeData = Map<String, dynamic>.from(scanRange);
        rangeData['project_id'] = projectId;
        rangeData.remove('id');
        await txn.insert('scan_range', rangeData);
      }

      debugPrint('=== IMPORT COMPLETE ===\n');
      return projectId;
    });
  }

  Future<ImportResult> importArchiveWithPath(
    String archivePath,
    String password,
  ) async {
    final file = File(archivePath);
    final archiveData = await file.readAsBytes();
    return await importArchive(archiveData, password);
  }

  Future<void> _extractUploadFiles(
    Uint8List archiveData,
    String password,
    String originalProjectName,
    String finalProjectName,
  ) async {
    if (kIsWeb) return;

    debugPrint('[Import] Extracting upload files...');
    debugPrint('[Import]   Original project name: $originalProjectName');
    debugPrint('[Import]   Final project name: $finalProjectName');

    final archive = await _archiveService.extractUploadFiles(
      archiveData,
      password,
    );
    final sanitizedOriginalName = originalProjectName.replaceAll(
      RegExp(r'[^\w\s-]'),
      '_',
    );
    debugPrint('[Import]   Sanitized original name: $sanitizedOriginalName');

    // Ensure project uploads directory exists
    await AppPathsService().ensureProjectUploadsDir(finalProjectName);
    final uploadsDir = AppPathsService().getProjectUploadsDir(finalProjectName);
    debugPrint('[Import]   Target uploads directory: $uploadsDir');

    int fileCount = 0;
    final expectedPrefix = 'projects/$sanitizedOriginalName/uploads/';
    debugPrint('[Import]   Looking for files with prefix: $expectedPrefix');

    for (final file in archive.files) {
      debugPrint('[Import]   Archive file: ${file.name} (isFile: ${file.isFile})');
      if (file.isFile &&
          file.name.startsWith(expectedPrefix)) {
        final fileName = file.name.replaceAll('\\', '/').split('/').last;
        final destPath = '$uploadsDir${Platform.pathSeparator}$fileName';
        final destFile = File(destPath);
        await destFile.writeAsBytes(file.content as List<int>);
        fileCount++;
        debugPrint('[Import]     -> Extracted to: $destPath');
      }
    }

    debugPrint('[Import] Extracted $fileCount files');

    // Check if any files are missing and attempt to find them in other project folders
    // Always run this to handle cases where files might be in different project folders
    await _copyMissingFilesFromOtherProjects(finalProjectName);
  }

  /// Checks if files are missing in the target project folder and copies them from other project folders
  Future<void> _copyMissingFilesFromOtherProjects(String projectName) async {
    try {
      final uploadsBaseDir = Directory(AppPathsService().uploadsDir);
      if (!await uploadsBaseDir.exists()) return;

      final targetDir = Directory(AppPathsService().getProjectUploadsDir(projectName));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Get all project folders in uploads directory
      final projectFolders = await uploadsBaseDir
          .list()
          .where((entity) => entity is Directory)
          .cast<Directory>()
          .toList();

      int copiedCount = 0;
      for (final sourceDir in projectFolders) {
        final sourceDirName = path.basename(sourceDir.path);
        if (sourceDirName == projectName) continue; // Skip the target folder itself

        // Check each file in the source directory
        await for (final file in sourceDir.list()) {
          if (file is! File) continue;

          final fileName = path.basename(file.path);
          final targetFilePath = path.join(targetDir.path, fileName);
          final targetFile = File(targetFilePath);

          // If file doesn't exist in target, copy it
          if (!await targetFile.exists()) {
            await file.copy(targetFilePath);
            copiedCount++;
            debugPrint('[Import] Copied missing file from $sourceDirName: $fileName');
          }
        }
      }

      if (copiedCount > 0) {
        debugPrint('[Import] Copied $copiedCount missing files from other project folders');
      }
    } catch (e) {
      debugPrint('[Import] Error copying missing files: $e');
    }
  }
}
