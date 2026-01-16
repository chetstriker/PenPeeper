import 'package:penpeeper/repositories/base_repository.dart';
import 'package:penpeeper/database/connection/database_connection.dart';
import 'package:penpeeper/api_database_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TagRepository extends BaseRepository {
  final _dbConnection = DatabaseConnection();

  Future<void> addDeviceTag(int deviceId, String tag) async {
    if (kIsWeb) {
      await ApiDatabaseHelper().addDeviceTag(deviceId, tag);
      return;
    }
    final db = await _dbConnection.database;
    await db.insert('device_tags', {
      'device_id': deviceId,
      'tag': tag,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeDeviceTag(int deviceId, String tag) async {
    if (kIsWeb) {
      await ApiDatabaseHelper().removeDeviceTag(deviceId, tag);
      return;
    }
    final db = await _dbConnection.database;
    await db.delete('device_tags',
      where: 'device_id = ? AND tag = ?',
      whereArgs: [deviceId, tag],
    );
  }

  Future<List<String>> getDeviceTags(int deviceId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDeviceTags(deviceId);
    }
    final db = await _dbConnection.database;
    final results = await db.query('device_tags',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at ASC',
    );
    return results.map((r) => r['tag'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> searchDevicesByTag(int projectId, String tag) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().searchDevicesByTag(projectId, tag);
    }
    final db = await _dbConnection.database;
    return await db.rawQuery('''
      SELECT DISTINCT d.id, d.name, d.ip_address, d.icon_type
      FROM devices d
      JOIN device_tags dt ON d.id = dt.device_id
      WHERE d.project_id = ? AND dt.tag = ?
    ''', [projectId, tag]);
  }

  Future<List<String>> getAllProjectTags(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getAllProjectTags(projectId);
    }
    final db = await _dbConnection.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT dt.tag
      FROM device_tags dt
      JOIN devices d ON dt.device_id = d.id
      WHERE d.project_id = ?
      ORDER BY dt.tag ASC
    ''', [projectId]);
    return results.map((r) => r['tag'] as String).toList();
  }
}
