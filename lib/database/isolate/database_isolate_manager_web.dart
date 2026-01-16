import 'dart:async';
import 'package:penpeeper/database/isolate/database_commands.dart';

/// Web stub for DatabaseIsolateManager
/// On web, all database operations go through API calls, so this is just a no-op stub
class DatabaseIsolateManager {
  static final DatabaseIsolateManager _instance = DatabaseIsolateManager._internal();
  factory DatabaseIsolateManager() => _instance;
  DatabaseIsolateManager._internal();

  bool _isInitialized = false;

  /// Initialize (no-op on web)
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    return;
  }

  /// Inserts a row into a table (no-op on web - use API)
  Future<int> insert(
    String table,
    Map<String, dynamic> values,
  ) async {
    throw UnsupportedError('Database operations not supported on web - use API calls');
  }

  /// Updates rows in a table (no-op on web - use API)
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    throw UnsupportedError('Database operations not supported on web - use API calls');
  }

  /// Deletes rows from a table (no-op on web - use API)
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    throw UnsupportedError('Database operations not supported on web - use API calls');
  }

  /// Executes raw SQL (no-op on web - use API)
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    throw UnsupportedError('Database operations not supported on web - use API calls');
  }

  /// Executes multiple commands in a transaction (no-op on web - use API)
  Future<List<dynamic>> transaction(List<DatabaseCommand> commands) async {
    throw UnsupportedError('Database operations not supported on web - use API calls');
  }

  /// Creates an insert command (for use in transactions)
  DatabaseCommand createInsertCommand(
    String table,
    Map<String, dynamic> values,
  ) {
    return DatabaseCommand(
      type: DatabaseCommandType.insert,
      table: table,
      values: values,
      requestId: 0,
    );
  }

  /// Creates an update command (for use in transactions)
  DatabaseCommand createUpdateCommand(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) {
    return DatabaseCommand(
      type: DatabaseCommandType.update,
      table: table,
      values: values,
      where: where,
      whereArgs: whereArgs,
      requestId: 0,
    );
  }

  /// Creates a delete command (for use in transactions)
  DatabaseCommand createDeleteCommand(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) {
    return DatabaseCommand(
      type: DatabaseCommandType.delete,
      table: table,
      where: where,
      whereArgs: whereArgs,
      requestId: 0,
    );
  }

  /// Creates an execute command (for use in transactions)
  DatabaseCommand createExecuteCommand(String sql, [List<dynamic>? arguments]) {
    return DatabaseCommand(
      type: DatabaseCommandType.execute,
      sql: sql,
      arguments: arguments,
      requestId: 0,
    );
  }

  /// Shuts down the write isolate (no-op on web)
  Future<void> shutdown() async {
    return;
  }

  /// Gets the initialization status
  bool get isInitialized => _isInitialized;

  /// Gets whether running on web platform
  bool get isWeb => true;
}
