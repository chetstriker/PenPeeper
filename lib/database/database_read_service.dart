import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:penpeeper/database_helper.dart';
import 'package:penpeeper/database/isolate/database_isolate_manager.dart';

/// Read-only database service for UI isolate
/// Uses shared DatabaseHelper connection and waits for write isolate to initialize
/// This is safe because WAL mode allows concurrent reads
class DatabaseReadService {
  static final DatabaseReadService _instance = DatabaseReadService._internal();
  factory DatabaseReadService() => _instance;
  DatabaseReadService._internal();

  final _dbHelper = DatabaseHelper();
  final _writeManager = DatabaseIsolateManager();

  /// Gets the read-only database instance
  Future<Database> get database async {
    if (kIsWeb) {
      throw Exception('Database not available on web - use API calls');
    }
    return await _dbHelper.database;
  }

  /// Queries the database (read-only)
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Executes a raw read-only query
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }
}
