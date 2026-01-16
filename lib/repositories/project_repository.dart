import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:penpeeper/repositories/base_repository.dart';
import 'package:penpeeper/database_helper.dart';
import 'package:penpeeper/api_database_helper.dart';
import 'package:penpeeper/models.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class ProjectRepository extends BaseRepository {
  final _dbHelper = DatabaseHelper();

  Future<Project> insertProject(String name) async {
    if (kIsWeb) {
      final id = await ApiDatabaseHelper().insertProject(name);
      final now = DateTime.now();
      return Project(id: id, name: name, createdAt: now, updatedAt: now);
    }
    try {
      debugPrint('Getting database instance...');
      final db = await _dbHelper.database;
      debugPrint('Database instance obtained, inserting project: $name');
      final now = DateTime.now().toIso8601String();
      final id = await db.insert('projects', {
        'name': name,
        'created_at': now,
        'updated_at': now,
      });
      debugPrint('Project inserted with ID: $id');
      return Project(id: id, name: name, createdAt: DateTime.parse(now), updatedAt: DateTime.parse(now));
    } catch (e) {
      debugPrint('Error inserting project: $e');
      rethrow;
    }
  }

  Future<List<Project>> getProjects() async {
    if (kIsWeb) {
      final maps = await ApiDatabaseHelper().getProjects();
      return maps.map((map) => Project.fromMap(map)).toList();
    }
    final db = await _dbHelper.database;
    final maps = await db.query('projects', orderBy: 'updated_at DESC');
    return maps.map((map) => Project.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getProjectsRaw() async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getProjects();
    }
    final db = await _dbHelper.database;
    return await db.query('projects', orderBy: 'updated_at DESC');
  }

  Future<void> renameProject(int projectId, String newName) async {
    if (kIsWeb) {
      await ApiDatabaseHelper().renameProject(projectId, newName);
      return;
    }

    final db = await _dbHelper.database;

    // Get old project name
    final projects = await db.query('projects', where: 'id = ?', whereArgs: [projectId]);
    if (projects.isEmpty) return;
    final oldName = projects.first['name'] as String;

    if (oldName == newName) return;
    
    // Update image paths in flagged_findings
    if (!kIsWeb) {
      final dbDir = Directory.current.path;
      final oldPath = path.join(dbDir, 'uploads', oldName);
      final newPath = path.join(dbDir, 'uploads', newName);
      
      final findings = await db.query('flagged_findings', where: 'project_id = ?', whereArgs: [projectId]);
      
      for (final finding in findings) {
        final id = finding['id'] as int;
        final comment = finding['comment'] as String?;
        final recommendation = finding['recommendation'] as String?;
        final evidence = finding['evidence'] as String?;
        
        final updatedComment = comment?.replaceAll(oldPath, newPath);
        final updatedRecommendation = recommendation?.replaceAll(oldPath, newPath);
        final updatedEvidence = evidence?.replaceAll(oldPath, newPath);
        
        if (updatedComment != comment || updatedRecommendation != recommendation || updatedEvidence != evidence) {
          await db.update('flagged_findings',
            {
              if (updatedComment != null) 'comment': updatedComment,
              if (updatedRecommendation != null) 'recommendation': updatedRecommendation,
              if (updatedEvidence != null) 'evidence': updatedEvidence,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      
      // Update image paths in report_sections
      final sections = await db.query('report_sections', where: 'project_id = ?', whereArgs: [projectId]);
      
      for (final section in sections) {
        final id = section['id'] as int;
        final content = section['content'] as String?;
        
        final updatedContent = content?.replaceAll(oldPath, newPath);
        
        if (updatedContent != content && updatedContent != null) {
          await db.update('report_sections',
            {'content': updatedContent},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      
      // Rename uploads folder
      final oldDir = Directory(oldPath);
      if (await oldDir.exists()) {
        await oldDir.rename(newPath);
      }
    }
    
    // Update project name
    await db.update('projects', 
      {
        'name': newName,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [projectId],
    );
  }

  Future<void> deleteProject(int projectId) async {
    debugPrint('=== ProjectRepository.deleteProject START ===');
    debugPrint('Project ID: $projectId');
    debugPrint('Platform: ${kIsWeb ? "Web" : "Desktop"}');
    
    if (kIsWeb) {
      await ApiDatabaseHelper().deleteProject(projectId);
      return;
    }
    
    try {
      debugPrint('Getting database connection...');
      final db = await _dbHelper.database;
      debugPrint('Database connection obtained');
      
      // DEBUG: Check database file path and size before deletion
      final dbPath = AppPathsService().databasePath;
      final dbFile = File(dbPath);
      final sizeBefore = await dbFile.length();
      debugPrint('Database file: $dbPath');
      debugPrint('Database size before deletion: $sizeBefore bytes');
      
      // DEBUG: Count projects before deletion
      final projectCountBefore = await db.rawQuery('SELECT COUNT(*) as count FROM projects');
      debugPrint('Projects count before deletion: ${projectCountBefore.first['count']}');
      
      // Get project name before deletion for uploads folder
      debugPrint('Querying project details...');
      final projectList = await db.query('projects', where: 'id = ?', whereArgs: [projectId]);
      debugPrint('Project query result: ${projectList.length} rows');
      final projectName = projectList.isNotEmpty ? projectList.first['name'] as String : null;
      debugPrint('Project name: $projectName');
      
      // Wrap entire deletion in a transaction for atomicity
      await db.transaction((txn) async {
        // Delete report sections first
        debugPrint('Deleting report sections...');
        final reportSectionsDeleted = await txn.delete('report_sections', where: 'project_id = ?', whereArgs: [projectId]);
        debugPrint('Deleted $reportSectionsDeleted report sections');
        
        // Get all devices for this project
        debugPrint('Querying devices for project...');
        final devices = await txn.query('devices', 
          where: 'project_id = ?', 
          whereArgs: [projectId]
        );
        debugPrint('Found ${devices.length} devices');
        
        // Delete all device-related data
        for (final device in devices) {
          final deviceId = device['id'] as int;
          debugPrint('Processing device ID: $deviceId');
          
          // Delete nmap data (deepest level first)
          debugPrint('  Deleting nmap_cves...');
          final cvesDeleted = await txn.rawDelete('''
            DELETE FROM nmap_cves WHERE script_id IN (
              SELECT s.id FROM nmap_scripts s 
              JOIN nmap_ports p ON s.port_id = p.id 
              JOIN nmap_hosts h ON p.host_id = h.id 
              WHERE h.device_id = ?
            )
          ''', [deviceId]);
          debugPrint('  Deleted $cvesDeleted nmap_cves');
          
          debugPrint('  Deleting nmap_scripts...');
          final scriptsDeleted = await txn.rawDelete('''
            DELETE FROM nmap_scripts WHERE port_id IN (
              SELECT p.id FROM nmap_ports p 
              JOIN nmap_hosts h ON p.host_id = h.id 
              WHERE h.device_id = ?
            )
          ''', [deviceId]);
          debugPrint('  Deleted $scriptsDeleted nmap_scripts');
          
          debugPrint('  Deleting nmap_ports...');
          final portsDeleted = await txn.rawDelete('''
            DELETE FROM nmap_ports WHERE host_id IN (
              SELECT id FROM nmap_hosts WHERE device_id = ?
            )
          ''', [deviceId]);
          debugPrint('  Deleted $portsDeleted nmap_ports');
          
          debugPrint('  Deleting nmap_os_matches...');
          final osMatchesDeleted = await txn.rawDelete('''
            DELETE FROM nmap_os_matches WHERE host_id IN (
              SELECT id FROM nmap_hosts WHERE device_id = ?
            )
          ''', [deviceId]);
          debugPrint('  Deleted $osMatchesDeleted nmap_os_matches');
          
          debugPrint('  Deleting nmap_hosts...');
          final hostsDeleted = await txn.delete('nmap_hosts', where: 'device_id = ?', whereArgs: [deviceId]);
          debugPrint('  Deleted $hostsDeleted nmap_hosts');
          
          // Delete other device-related tables
          debugPrint('  Deleting device_data...');
          final deviceDataDeleted = await txn.delete('device_data', where: 'device_id = ?', whereArgs: [deviceId]);
          debugPrint('  Deleted $deviceDataDeleted device_data');
          
          debugPrint('  Deleting device_tags...');
          final deviceTagsDeleted = await txn.delete('device_tags', where: 'device_id = ?', whereArgs: [deviceId]);
          debugPrint('  Deleted $deviceTagsDeleted device_tags');
          
          debugPrint('  Deleting flagged_findings...');
          final findingsDeleted = await txn.delete('flagged_findings', where: 'device_id = ?', whereArgs: [deviceId]);
          debugPrint('  Deleted $findingsDeleted flagged_findings');
          
          debugPrint('  Deleting ffuf_findings...');
          final ffufDeleted = await txn.delete('ffuf_findings', where: 'device_id = ?', whereArgs: [deviceId]);
          debugPrint('  Deleted $ffufDeleted ffuf_findings');
          
          debugPrint('  Deleting samba_ldap_findings...');
          final sambaDeleted = await txn.delete('samba_ldap_findings', where: 'device_id = ?', whereArgs: [deviceId]);
          debugPrint('  Deleted $sambaDeleted samba_ldap_findings');
          
          debugPrint('  Deleting scans...');
          final scansDeleted = await txn.delete('scans', where: 'device_id = ?', whereArgs: [deviceId]);
          debugPrint('  Deleted $scansDeleted scans');
          
          debugPrint('  Deleting snmp_findings...');
          final snmpDeleted = await txn.delete('snmp_findings', where: 'device_id = ?', whereArgs: [deviceId]);
          debugPrint('  Deleted $snmpDeleted snmp_findings');
          
          debugPrint('  Deleting vulnerabilities...');
          final vulnDeleted = await txn.delete('vulnerabilities', where: 'device_id = ?', whereArgs: [deviceId]);
          debugPrint('  Deleted $vulnDeleted vulnerabilities');
          
          debugPrint('  Deleting vulnerability_classifications...');
          final classDeleted = await txn.delete('vulnerability_classifications', where: 'device_id = ?', whereArgs: [deviceId]);
          debugPrint('  Deleted $classDeleted vulnerability_classifications');
          
          debugPrint('  Deleting whatweb_findings...');
          final whatwebDeleted = await txn.delete('whatweb_findings', where: 'device_id = ?', whereArgs: [deviceId]);
          debugPrint('  Deleted $whatwebDeleted whatweb_findings');
        }
        
        // Delete devices
        debugPrint('Deleting devices...');
        final devicesDeleted = await txn.delete('devices', where: 'project_id = ?', whereArgs: [projectId]);
        debugPrint('Deleted $devicesDeleted devices');
        
        // Delete project
        debugPrint('Deleting project...');
        final projectDeleted = await txn.delete('projects', where: 'id = ?', whereArgs: [projectId]);
        debugPrint('Deleted $projectDeleted projects');
        
        debugPrint('Transaction completed successfully');
      });
      
      // Force WAL checkpoint to ensure changes are written to main database file
      debugPrint('Forcing WAL checkpoint...');
      await db.execute('PRAGMA wal_checkpoint(FULL)');
      debugPrint('WAL checkpoint completed');
      
      // DEBUG: Check database file size and project count after deletion
      final sizeAfter = await dbFile.length();
      final projectCountAfter = await db.rawQuery('SELECT COUNT(*) as count FROM projects');
      debugPrint('Database size after deletion: $sizeAfter bytes (change: ${sizeAfter - sizeBefore})');
      debugPrint('Projects count after deletion: ${projectCountAfter.first['count']}');
      
      // Delete uploads folder outside transaction
      if (projectName != null && !kIsWeb) {
        try {
          debugPrint('Attempting to delete uploads folder...');
          await AppPathsService().deleteProjectUploadsDir(projectName);
          debugPrint('Deleted uploads folder for project: $projectName');
        } catch (e) {
          debugPrint('Failed to delete uploads folder: $e');
        }
      }
      
      debugPrint('=== ProjectRepository.deleteProject SUCCESS ===');
    } catch (e, stack) {
      debugPrint('=== ProjectRepository.deleteProject ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  Future<void> updateProjectTimestamp(int projectId) async {
    final db = await _dbHelper.database;
    await db.update('projects',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [projectId],
    );
  }

  /// Check if any NMap scan results exist for the project
  Future<bool> hasNmapResults(int projectId) async {
    if (kIsWeb) {
      // For web, check via API
      final result = await ApiDatabaseHelper().hasNmapResults(projectId);
      return result;
    }

    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM nmap_hosts h
      JOIN devices d ON h.device_id = d.id
      WHERE d.project_id = ?
    ''', [projectId]);

    final count = results.first['count'] as int;
    return count > 0;
  }
}
