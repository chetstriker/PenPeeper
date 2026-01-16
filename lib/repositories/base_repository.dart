import 'package:sqflite_common/sqlite_api.dart';
import 'package:penpeeper/database_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/repositories/base/repository_interface.dart';

abstract class BaseRepository implements Repository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  Future<Database> get database async {
    if (kIsWeb) {
      throw Exception('Use DatabaseHelper methods directly on web');
    }
    return await _dbHelper.database;
  }
  
  DatabaseHelper get dbHelper => _dbHelper;

  @override
  Future<void> initialize() async {
    // Ensure database is initialized
    await database;
  }

  @override
  Future<void> dispose() async {
    // Cleanup if needed
  }

  /// Execute operation within a transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  /// Execute batch operations
  Future<List<Object?>> batch(void Function(Batch batch) operations) async {
    final db = await database;
    final batch = db.batch();
    operations(batch);
    return await batch.commit(noResult: false);
  }
}
