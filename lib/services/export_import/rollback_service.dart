import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/database_helper.dart';
import 'package:path/path.dart' as path;

class RollbackService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> rollbackImport(List<int> importedProjectIds) async {
    for (var projectId in importedProjectIds.reversed) {
      try {
        await deleteProjectData(projectId);
      } catch (e) {
        debugPrint('Failed to rollback project $projectId: $e');
      }
    }
  }

  Future<void> deleteProjectData(int projectId) async {
    if (kIsWeb) {
      debugPrint('Web platform: project deletion handled by API');
      return;
    }

    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      final project = await txn.query('projects', where: 'id = ?', whereArgs: [projectId]);
      if (project.isEmpty) return;
      
      final projectName = project.first['name'] as String;
      
      await txn.delete('vulnerability_classifications', where: 'project_id = ?', whereArgs: [projectId]);
      await txn.delete('report_sections', where: 'project_id = ?', whereArgs: [projectId]);
      await txn.delete('flagged_findings', where: 'project_id = ?', whereArgs: [projectId]);
      
      final devices = await txn.query('devices', where: 'project_id = ?', whereArgs: [projectId]);
      for (var device in devices) {
        final deviceId = device['id'] as int;
        
        final hosts = await txn.query('nmap_hosts', where: 'device_id = ?', whereArgs: [deviceId]);
        for (var host in hosts) {
          final hostId = host['id'] as int;
          
          final ports = await txn.query('nmap_ports', where: 'host_id = ?', whereArgs: [hostId]);
          for (var port in ports) {
            final portId = port['id'] as int;
            await txn.delete('nmap_scripts', where: 'port_id = ?', whereArgs: [portId]);
          }
          
          await txn.delete('nmap_ports', where: 'host_id = ?', whereArgs: [hostId]);
        }
        
        await txn.delete('nmap_hosts', where: 'device_id = ?', whereArgs: [deviceId]);
        await txn.delete('scans', where: 'device_id = ?', whereArgs: [deviceId]);
        await txn.delete('device_tags', where: 'device_id = ?', whereArgs: [deviceId]);
      }
      
      await txn.delete('devices', where: 'project_id = ?', whereArgs: [projectId]);
      await txn.delete('projects', where: 'id = ?', whereArgs: [projectId]);
      
      await removeUploadFiles(projectName);
    });
  }

  Future<void> removeUploadFiles(String projectName) async {
    if (kIsWeb) return;

    try {
      final uploadsDir = Directory(path.join('uploads', projectName));
      if (await uploadsDir.exists()) {
        await uploadsDir.delete(recursive: true);
        debugPrint('Removed upload files for project: $projectName');
      }
    } catch (e) {
      debugPrint('Failed to remove upload files for $projectName: $e');
    }
  }
}
