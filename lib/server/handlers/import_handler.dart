import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:penpeeper/services/export_import/archive_service.dart';
import 'package:penpeeper/services/export_import/conflict_resolver.dart';
import 'package:penpeeper/database/connection/database_connection.dart';
import 'package:penpeeper/repositories/project_repository.dart';
import 'package:penpeeper/models/export_data.dart';
import 'package:flutter/foundation.dart';

class ImportHandler {
  static final Map<String, dynamic> _tempStorage = {};

  Future<Response> handleImport(Request request) async {
    try {
      final contentType = request.headers['content-type'] ?? '';
      
      // Handle both multipart and direct binary upload
      if (contentType.contains('multipart/form-data')) {
        // Original multipart handling (keep for compatibility)
        final bytes = await request.read().expand((chunk) => chunk).toList();
        final archiveBytes = Uint8List.fromList(bytes);
        
        final password = request.url.queryParameters['password'] ?? '';
        
        final archiveService = ArchiveService();
        final exportData = await archiveService.extractArchive(archiveBytes, password);
        
        // Use server database connection for conflict detection
        final db = await DatabaseConnection().database;
        final conflicts = <ProjectConflict>[];
        
        for (final project in exportData.projects) {
          final projectName = project.project['name'] as String;
          final results = await db.query(
            'projects',
            where: 'name = ?',
            whereArgs: [projectName],
            limit: 1,
          );
          
          if (results.isNotEmpty) {
            final existing = results.first;
            conflicts.add(ProjectConflict(
              projectName: projectName,
              existingProjectId: existing['id'] as int,
              existingUpdatedAt: DateTime.parse(existing['updated_at'] as String),
              importUpdatedAt: DateTime.parse(project.project['updated_at'] as String),
            ));
          }
        }
        
        final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
        _tempStorage[sessionId] = {
          'exportData': exportData,
          'archiveBytes': archiveBytes,
          'password': password,
        };
        
        return Response.ok(
          jsonEncode({
            'success': true,
            'conflicts': conflicts.map((c) => {
              'projectName': c.projectName,
              'existingProjectId': c.existingProjectId,
              'existingUpdatedAt': c.existingUpdatedAt.toIso8601String(),
              'importUpdatedAt': c.importUpdatedAt.toIso8601String(),
            }).toList(),
            'sessionId': sessionId,
          }),
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        );
      } else {
        // Direct binary upload (for web client)
        debugPrint('[Import] Starting web import...');
        final bytes = await request.read().expand((chunk) => chunk).toList();
        final archiveBytes = Uint8List.fromList(bytes);
        debugPrint('[Import] Received ${archiveBytes.length} bytes');
        
        final password = request.url.queryParameters['password'] ?? '';
        debugPrint('[Import] Raw password: "$password"');
        debugPrint('[Import] URL decoded password: "${Uri.decodeComponent(password)}"');
        
        final decodedPassword = Uri.decodeComponent(password);
        
        try {
          debugPrint('[Import] Attempting to extract as encrypted archive...');
          final archiveService = ArchiveService();
          final exportData = await archiveService.extractArchive(archiveBytes, decodedPassword);
          debugPrint('[Import] Archive extracted, ${exportData.projects.length} projects found');
          
          // Use server database connection for conflict detection
          final db = await DatabaseConnection().database;
          debugPrint('[Import] Database connected');
          final conflicts = <ProjectConflict>[];
          
          for (final project in exportData.projects) {
            final projectName = project.project['name'] as String;
            debugPrint('[Import] Checking project: $projectName');
            final results = await db.query(
              'projects',
              where: 'name = ?',
              whereArgs: [projectName],
              limit: 1,
            );
            
            if (results.isNotEmpty) {
              final existing = results.first;
              debugPrint('[Import] Conflict found for: $projectName');
              conflicts.add(ProjectConflict(
                projectName: projectName,
                existingProjectId: existing['id'] as int,
                existingUpdatedAt: DateTime.parse(existing['updated_at'] as String),
                importUpdatedAt: DateTime.parse(project.project['updated_at'] as String),
              ));
            }
          }
          
          final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
          _tempStorage[sessionId] = {
            'exportData': exportData,
            'archiveBytes': archiveBytes,
            'password': password,
          };
          debugPrint('[Import] Session created: $sessionId');
          
          return Response.ok(
            jsonEncode({
              'success': true,
              'conflicts': conflicts.map((c) => {
                'projectName': c.projectName,
                'existingProjectId': c.existingProjectId,
                'existingUpdatedAt': c.existingUpdatedAt.toIso8601String(),
                'importUpdatedAt': c.importUpdatedAt.toIso8601String(),
              }).toList(),
              'sessionId': sessionId,
            }),
            headers: {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*',
            },
          );
        } catch (e) {
          debugPrint('[Import] Decryption failed, trying as raw file: $e');
          // If decryption fails, the file might not be encrypted properly
          // Return error asking user to use desktop version
          return Response.badRequest(
            body: jsonEncode({
              'error': 'Invalid archive format or wrong password. Please ensure the file was exported from PenPeeper desktop version.',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Import failed: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> handleImportConfirm(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body);
      
      final sessionId = json['sessionId'] as String;
      final resolutionsJson = json['resolutions'] as Map<String, dynamic>;
      
      final session = _tempStorage[sessionId];
      if (session == null) {
        return Response.notFound(
          jsonEncode({'error': 'Session not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      final resolutions = <String, ConflictResolution>{};
      resolutionsJson.forEach((key, value) {
        resolutions[key] = ConflictResolution.values.firstWhere(
          (e) => e.toString().split('.').last == value,
        );
      });
      
      final exportData = session['exportData'] as ExportData;
      final importedProjects = <String>[];
      final errors = <String>[];
      
      final db = await DatabaseConnection().database;
      
      for (final project in exportData.projects) {
        try {
          final projectName = project.project['name'] as String;
          final resolution = resolutions[projectName];
          
          if (resolution == ConflictResolution.cancel) {
            continue;
          }
          
          if (resolution == ConflictResolution.replace) {
            final existing = await db.query(
              'projects',
              where: 'name = ?',
              whereArgs: [projectName],
              limit: 1,
            );
            if (existing.isNotEmpty) {
              final projectRepo = ProjectRepository();
              await projectRepo.deleteProject(existing.first['id'] as int);
            }
          }
          
          String finalName = projectName;
          if (resolution == ConflictResolution.rename) {
            var counter = 1;
            var newName = '$projectName ($counter)';
            while (true) {
              final existing = await db.query(
                'projects',
                where: 'name = ?',
                whereArgs: [newName],
                limit: 1,
              );
              if (existing.isEmpty) break;
              counter++;
              newName = '$projectName ($counter)';
            }
            finalName = newName;
          }
          
          // Import full project data
          final projectData = Map<String, dynamic>.from(project.project);
          projectData['name'] = finalName;
          projectData.remove('id');
          final projectId = await db.insert('projects', projectData);
          
          // Import devices
          final deviceIdMap = <int, int>{};
          for (final device in project.devices) {
            final deviceData = Map<String, dynamic>.from(device);
            deviceData['project_id'] = projectId;
            final oldDeviceId = deviceData['id'];
            deviceData.remove('id');
            final newDeviceId = await db.insert('devices', deviceData);
            deviceIdMap[oldDeviceId] = newDeviceId;
          }
          
          // Import scans
          final allScans = [...project.nmapScans, ...project.niktoScans, ...project.searchsploitScans];
          for (final scan in allScans) {
            final scanData = Map<String, dynamic>.from(scan);
            final oldDeviceId = scanData['device_id'];
            scanData['device_id'] = deviceIdMap[oldDeviceId];
            scanData.remove('id');
            await db.insert('scans', scanData);
          }
          
          // Import nmap hosts
          final hostIdMap = <int, int>{};
          for (final host in project.nmapHosts) {
            final hostData = Map<String, dynamic>.from(host);
            final oldDeviceId = hostData['device_id'];
            final oldHostId = hostData['id'];
            hostData['device_id'] = deviceIdMap[oldDeviceId];
            hostData.remove('id');
            final newHostId = await db.insert('nmap_hosts', hostData);
            hostIdMap[oldHostId] = newHostId;
          }
          
          // Import nmap ports
          final portIdMap = <int, int>{};
          for (final port in project.nmapPorts) {
            final portData = Map<String, dynamic>.from(port);
            final oldHostId = portData['host_id'];
            final oldPortId = portData['id'];
            portData['host_id'] = hostIdMap[oldHostId];
            portData.remove('id');
            final newPortId = await db.insert('nmap_ports', portData);
            portIdMap[oldPortId] = newPortId;
          }
          
          // Import nmap scripts
          for (final script in project.nmapScripts) {
            final scriptData = Map<String, dynamic>.from(script);
            final oldPortId = scriptData['port_id'];
            scriptData['port_id'] = portIdMap[oldPortId];
            scriptData.remove('id');
            await db.insert('nmap_scripts', scriptData);
          }
          
          // Import findings
          final findingIdMap = <int, int>{};
          for (final finding in project.findings) {
            final findingData = Map<String, dynamic>.from(finding);
            final oldDeviceId = findingData['device_id'];
            final oldFindingId = findingData['id'];
            final newDeviceId = deviceIdMap[oldDeviceId];
            if (newDeviceId != null) {
              findingData['device_id'] = newDeviceId;
              findingData['project_id'] = projectId;
              findingData.remove('id');
              final newFindingId = await db.insert('flagged_findings', findingData);
              findingIdMap[oldFindingId] = newFindingId;
            }
          }
          
          // Import tags
          for (final tag in project.tags) {
            final tagData = Map<String, dynamic>.from(tag);
            final oldDeviceId = tagData['device_id'];
            tagData['device_id'] = deviceIdMap[oldDeviceId];
            tagData.remove('id');
            await db.insert('device_tags', tagData);
          }
          
          // Import nmap OS matches
          for (final osMatch in project.nmapOsMatches) {
            final osData = Map<String, dynamic>.from(osMatch);
            final oldHostId = osData['host_id'];
            final newHostId = hostIdMap[oldHostId];
            if (newHostId != null) {
              osData['host_id'] = newHostId;
              osData.remove('id');
              await db.insert('nmap_os_matches', osData);
            }
          }
          
          // Import classifications
          for (final classification in project.classifications) {
            final classData = Map<String, dynamic>.from(classification);
            final oldDeviceId = classData['device_id'];
            final oldFindingId = classData['finding_id'];
            final newDeviceId = deviceIdMap[oldDeviceId];
            final newFindingId = findingIdMap[oldFindingId];
            if (newDeviceId != null && newFindingId != null) {
              classData['project_id'] = projectId;
              classData['device_id'] = newDeviceId;
              classData['finding_id'] = newFindingId;
              classData.remove('id');
              classData.remove('recommendation'); // Remove unknown column
              await db.insert('vulnerability_classifications', classData);
            }
          }
          
          // Import report sections
          for (final section in project.reportSections) {
            final sectionData = Map<String, dynamic>.from(section);
            sectionData['project_id'] = projectId;
            sectionData.remove('id');
            await db.insert('report_sections', sectionData);
          }
          
          // Import scan findings (nikto, searchsploit, ffuf, whatweb, samba/ldap, snmp)
          for (final finding in project.niktoFindings) {
            final findingData = Map<String, dynamic>.from(finding);
            final oldDeviceId = findingData['device_id'];
            findingData['device_id'] = deviceIdMap[oldDeviceId];
            findingData.remove('id');
            await db.insert('nikto_findings', findingData);
          }
          
          for (final result in project.searchsploitResults) {
            final resultData = Map<String, dynamic>.from(result);
            final oldDeviceId = resultData['device_id'];
            resultData['device_id'] = deviceIdMap[oldDeviceId];
            resultData.remove('id');
            await db.insert('vulnerabilities', resultData);
          }
          
          for (final finding in project.ffufFindings) {
            final findingData = Map<String, dynamic>.from(finding);
            final oldDeviceId = findingData['device_id'];
            findingData['device_id'] = deviceIdMap[oldDeviceId];
            findingData.remove('id');
            await db.insert('ffuf_findings', findingData);
          }
          
          for (final finding in project.whatwebFindings) {
            final findingData = Map<String, dynamic>.from(finding);
            final oldDeviceId = findingData['device_id'];
            findingData['device_id'] = deviceIdMap[oldDeviceId];
            findingData.remove('id');
            await db.insert('whatweb_findings', findingData);
          }
          
          for (final finding in project.sambaLdapFindings) {
            final findingData = Map<String, dynamic>.from(finding);
            final oldDeviceId = findingData['device_id'];
            findingData['device_id'] = deviceIdMap[oldDeviceId];
            findingData.remove('id');
            await db.insert('samba_ldap_findings', findingData);
          }
          
          for (final finding in project.snmpFindings) {
            final findingData = Map<String, dynamic>.from(finding);
            final oldDeviceId = findingData['device_id'];
            findingData['device_id'] = deviceIdMap[oldDeviceId];
            findingData['project_id'] = projectId;
            findingData.remove('id');
            await db.insert('snmp_findings', findingData);
          }
          
          importedProjects.add(finalName);
        } catch (e) {
          errors.add('${project.project['name']}: $e');
        }
      }
      
      _tempStorage.remove(sessionId);
      
      return Response.ok(
        jsonEncode({
          'success': errors.isEmpty,
          'importedProjects': importedProjects,
          'errors': errors,
          'totalProjects': exportData.projects.length,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Import confirmation failed: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
