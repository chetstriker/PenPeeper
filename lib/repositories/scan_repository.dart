import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:penpeeper/repositories/base_repository.dart';
import 'package:penpeeper/database/connection/database_connection.dart';
import 'package:penpeeper/database/database_read_service.dart';
import 'package:penpeeper/database/isolate/database_isolate_manager.dart';
import 'package:penpeeper/api_database_helper.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/models.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class ScanRepository extends BaseRepository {
  final _dbConnection = DatabaseConnection();
  final _readService = DatabaseReadService();
  final _writeManager = DatabaseIsolateManager();
  Future<int> insertScan(int deviceId, String name, String content) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('/api/devices/$deviceId/scans'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'name': name, 'data': content}),
        );
        return response.statusCode == 200 ? 1 : 0;
      } catch (e) {
        return 0;
      }
    }

    // Check if scan already exists (read operation)
    final existing = await _readService.query('scans',
      where: 'device_id = ? AND name = ?',
      whereArgs: [deviceId, name],
      limit: 1,
    );

    // Perform write operation through isolate
    if (existing.isNotEmpty) {
      await _writeManager.update('scans',
        {
          'content': content,
          'created_at': DateTime.now().toIso8601String(),
        },
        where: 'device_id = ? AND name = ?',
        whereArgs: [deviceId, name],
      );
      return existing.first['id'] as int;
    } else {
      return await _writeManager.insert('scans', {
        'device_id': deviceId,
        'name': name,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<List<Scan>> getScans(int deviceId) async {
    if (kIsWeb) {
      final maps = await ApiDatabaseHelper().getScans(deviceId);
      return maps.map((map) => Scan.fromMap(map)).toList();
    }
    final maps = await _readService.query('scans',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Scan.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getScansRaw(int deviceId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getScans(deviceId);
    }
    return await _readService.query('scans',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteScan(int scanId) async {
    if (kIsWeb) return;
    await _writeManager.delete('scans', where: 'id = ?', whereArgs: [scanId]);
  }

  Future<void> updateScan(int scanId, String name, String content) async {
    if (kIsWeb) return;
    await _writeManager.update('scans',
      {'name': name, 'content': content},
      where: 'id = ?',
      whereArgs: [scanId],
    );
  }

  Future<List<Map<String, dynamic>>> getAutoNmapScans(int projectId) async {
    return await _readService.rawQuery('''
      SELECT s.*, d.project_id
      FROM scans s
      JOIN devices d ON s.device_id = d.id
      WHERE d.project_id = ? AND s.name = 'AUTO NMAP'
    ''', [projectId]);
  }

  Future<void> deleteNiktoAutoScans(int deviceId) async {
    await _writeManager.delete('scans',
      where: 'device_id = ? AND name = ?',
      whereArgs: [deviceId, 'NIKTO AUTO'],
    );
  }

  Future<void> deleteSearchsploitAutoScans(int deviceId) async {
    // Use transaction for multiple deletes
    await _writeManager.transaction([
      _writeManager.createDeleteCommand('scans',
        where: 'device_id = ? AND name = ?',
        whereArgs: [deviceId, 'AUTO SEARCHSPLOIT'],
      ),
      _writeManager.createDeleteCommand('vulnerabilities',
        where: 'device_id = ? AND type = ?',
        whereArgs: [deviceId, 'SearchSploit'],
      ),
    ]);

    final cache = ProjectDataCache();
    cache.removeDeviceFromScanType('SearchSploit', deviceId);
  }

  Future<void> deleteWhatwebAutoScans(int deviceId) async {
    // Use transaction for multiple deletes
    await _writeManager.transaction([
      _writeManager.createDeleteCommand('scans',
        where: 'device_id = ? AND name = ?',
        whereArgs: [deviceId, 'AUTO WHATWEB'],
      ),
      _writeManager.createDeleteCommand('whatweb_findings',
        where: 'device_id = ?',
        whereArgs: [deviceId],
      ),
    ]);
  }

  Future<void> deleteFfufAutoScans(int deviceId) async {
    await _writeManager.delete('scans',
      where: 'device_id = ? AND name = ?',
      whereArgs: [deviceId, 'AUTO FUZZER'],
    );
  }

  Future<void> deleteSambaLdapAutoScans(int deviceId) async {
    // Use transaction for multiple deletes
    await _writeManager.transaction([
      _writeManager.createDeleteCommand('scans',
        where: 'device_id = ? AND name = ?',
        whereArgs: [deviceId, 'AUTO SAMBA/LDAP'],
      ),
      _writeManager.createDeleteCommand('samba_ldap_findings',
        where: 'device_id = ?',
        whereArgs: [deviceId],
      ),
    ]);
  }
}
