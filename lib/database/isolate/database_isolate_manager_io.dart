import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:penpeeper/database/isolate/database_commands.dart';
import 'package:penpeeper/database_helper.dart';

/// Manages the database write isolate and provides API for write operations
/// This is a singleton that should be initialized at app startup
class DatabaseIsolateManager {
  static final DatabaseIsolateManager _instance = DatabaseIsolateManager._internal();
  factory DatabaseIsolateManager() => _instance;
  DatabaseIsolateManager._internal();

  Isolate? _isolate;
  SendPort? _isolateSendPort;
  final ReceivePort _receivePort = ReceivePort();
  final Map<int, Completer<dynamic>> _pendingRequests = {};
  int _nextRequestId = 0;
  bool _isInitialized = false;
  bool _isWeb = false;

  /// Initializes the database write isolate
  /// Disabled on all platforms to avoid sqflite_ffi isolate conflicts
  /// Uses direct database access via DatabaseHelper instead
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isWeb = kIsWeb;

    // Disable isolate on all platforms to avoid sqflite_ffi multi-isolate issues
    debugPrint('[DB Isolate Manager] Using direct database access (no isolate)');
    _isInitialized = true;
    return;

    /* Isolate code disabled due to sqflite_ffi conflicts
    if (_isWeb) {
      debugPrint('[DB Isolate Manager] Web platform detected - isolate not used');
      _isInitialized = true;
      return;
    }

    debugPrint('[DB Isolate Manager] Spawning database write isolate...');

    // Spawn the database write isolate
    _isolate = await Isolate.spawn(
      databaseWriteIsolateEntry,
      _receivePort.sendPort,
      debugName: 'DatabaseWriteIsolate',
    );

    // Create a completer to wait for the SendPort
    final completer = Completer<void>();

    // Listen for responses from the isolate
    _receivePort.listen((message) {
      if (message is SendPort) {
        // First message is the isolate's SendPort
        _isolateSendPort = message;
        debugPrint('[DB Isolate Manager] Connected to write isolate');
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else if (message is Map<String, dynamic>) {
        // Subsequent messages are responses
        _handleResponse(DatabaseResponse.fromJson(message));
      }
    });

    // Wait for isolate to send back its SendPort (with timeout)
    try {
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Timeout waiting for database write isolate to connect');
        },
      );
    } catch (e) {
      throw Exception('Failed to connect to database write isolate: $e');
    }

    _isInitialized = true;
    debugPrint('[DB Isolate Manager] Initialization complete');
    */
  }

  /// Handles responses from the write isolate
  void _handleResponse(DatabaseResponse response) {
    final completer = _pendingRequests.remove(response.requestId);

    if (completer == null) {
      debugPrint('[DB Isolate Manager] WARNING: No pending request for ID ${response.requestId}');
      return;
    }

    if (response.isSuccess) {
      completer.complete(response.result);
    } else {
      completer.completeError(
        Exception(response.error),
        response.stackTrace != null ? StackTrace.fromString(response.stackTrace!) : null,
      );
    }
  }

  /// Sends a command to the write isolate and waits for response
  Future<T> _sendCommand<T>(DatabaseCommand command) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isWeb || _isolateSendPort == null) {
      // No isolate - execute directly using DatabaseHelper
      return await _executeDirectly<T>(command);
    }

    final completer = Completer<T>();
    _pendingRequests[command.requestId] = completer;

    _isolateSendPort!.send(command.toJson());

    return completer.future;
  }

  /// Executes database command directly without isolate
  Future<T> _executeDirectly<T>(DatabaseCommand command) async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;

    switch (command.type) {
      case DatabaseCommandType.insert:
        return await db.insert(
          command.table!,
          command.values!,
          conflictAlgorithm: ConflictAlgorithm.replace,
        ) as T;

      case DatabaseCommandType.update:
        return await db.update(
          command.table!,
          command.values!,
          where: command.where,
          whereArgs: command.whereArgs,
        ) as T;

      case DatabaseCommandType.delete:
        return await db.delete(
          command.table!,
          where: command.where,
          whereArgs: command.whereArgs,
        ) as T;

      case DatabaseCommandType.execute:
        await db.execute(command.sql!, command.arguments ?? []);
        return null as T;

      case DatabaseCommandType.transaction:
        final results = <dynamic>[];
        await db.transaction((txn) async {
          for (final cmd in command.transactionCommands!) {
            switch (cmd.type) {
              case DatabaseCommandType.insert:
                results.add(await txn.insert(
                  cmd.table!,
                  cmd.values!,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                ));
                break;
              case DatabaseCommandType.update:
                results.add(await txn.update(
                  cmd.table!,
                  cmd.values!,
                  where: cmd.where,
                  whereArgs: cmd.whereArgs,
                ));
                break;
              case DatabaseCommandType.delete:
                results.add(await txn.delete(
                  cmd.table!,
                  where: cmd.where,
                  whereArgs: cmd.whereArgs,
                ));
                break;
              case DatabaseCommandType.execute:
                await txn.execute(cmd.sql!, cmd.arguments ?? []);
                results.add(null);
                break;
              default:
                throw Exception('Unsupported command type in transaction');
            }
          }
        });
        return results as T;

      case DatabaseCommandType.shutdown:
        return null as T;
    }
  }

  /// Inserts a row into a table
  Future<int> insert(
    String table,
    Map<String, dynamic> values,
  ) async {
    final command = DatabaseCommand(
      type: DatabaseCommandType.insert,
      table: table,
      values: values,
      requestId: _nextRequestId++,
    );

    return await _sendCommand<int>(command);
  }

  /// Updates rows in a table
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final command = DatabaseCommand(
      type: DatabaseCommandType.update,
      table: table,
      values: values,
      where: where,
      whereArgs: whereArgs,
      requestId: _nextRequestId++,
    );

    return await _sendCommand<int>(command);
  }

  /// Deletes rows from a table
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final command = DatabaseCommand(
      type: DatabaseCommandType.delete,
      table: table,
      where: where,
      whereArgs: whereArgs,
      requestId: _nextRequestId++,
    );

    return await _sendCommand<int>(command);
  }

  /// Executes raw SQL
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    final command = DatabaseCommand(
      type: DatabaseCommandType.execute,
      sql: sql,
      arguments: arguments,
      requestId: _nextRequestId++,
    );

    await _sendCommand<void>(command);
  }

  /// Executes multiple commands in a transaction
  /// Returns a list of results, one for each command
  Future<List<dynamic>> transaction(List<DatabaseCommand> commands) async {
    // Assign request IDs to all commands
    for (final command in commands) {
      // Note: Individual commands don't need request IDs in a transaction
      // but we keep the field for consistency
    }

    final transactionCommand = DatabaseCommand(
      type: DatabaseCommandType.transaction,
      transactionCommands: commands,
      requestId: _nextRequestId++,
    );

    return await _sendCommand<List<dynamic>>(transactionCommand);
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
      requestId: 0, // Will be set by transaction
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
      requestId: 0, // Will be set by transaction
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
      requestId: 0, // Will be set by transaction
    );
  }

  /// Creates an execute command (for use in transactions)
  DatabaseCommand createExecuteCommand(String sql, [List<dynamic>? arguments]) {
    return DatabaseCommand(
      type: DatabaseCommandType.execute,
      sql: sql,
      arguments: arguments,
      requestId: 0, // Will be set by transaction
    );
  }

  /// Shuts down the write isolate
  Future<void> shutdown() async {
    if (!_isInitialized || _isWeb) return;

    debugPrint('[DB Isolate Manager] Shutting down...');

    final command = DatabaseCommand(
      type: DatabaseCommandType.shutdown,
      requestId: _nextRequestId++,
    );

    try {
      _isolateSendPort?.send(command.toJson());
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('[DB Isolate Manager] Error during shutdown: $e');
    }

    _isolate?.kill(priority: Isolate.immediate);
    _receivePort.close();
    _pendingRequests.clear();
    _isInitialized = false;

    debugPrint('[DB Isolate Manager] Shutdown complete');
  }

  /// Gets the initialization status
  bool get isInitialized => _isInitialized;

  /// Gets whether running on web platform
  bool get isWeb => _isWeb;
}
