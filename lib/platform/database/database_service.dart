import 'package:sqflite_common/sqlite_api.dart';

/// Abstract interface for platform-specific database operations
abstract class DatabaseService {
  /// Initialize the database service
  Future<void> initialize();

  /// Get the database instance
  Future<Database> getDatabase();

  /// Close the database connection
  Future<void> close();

  /// Execute a raw query
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<dynamic>? args,
  ]);

  /// Insert a record
  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    ConflictAlgorithm? conflictAlgorithm,
  });

  /// Update records
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  });

  /// Delete records
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  });

  /// Execute a raw SQL statement
  Future<void> execute(String sql, [List<dynamic>? args]);

  /// Begin a transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action);
}
