import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:penpeeper/database/isolate/database_commands.dart';
import 'package:penpeeper/database/schema/schema_manager.dart';
import 'package:penpeeper/services/app_paths_service.dart';

/// Entry point for database write isolate
/// This isolate handles ALL write operations sequentially
void databaseWriteIsolateEntry(SendPort sendPort) {
  final service = DatabaseWriteService(sendPort);
  service.start();
}

/// Service that runs in background isolate to handle all database writes
class DatabaseWriteService {
  final SendPort _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  Database? _database;
  bool _isShuttingDown = false;

  DatabaseWriteService(this._sendPort);

  /// Starts the write service
  void start() async {
    // Send the ReceivePort back to the main isolate
    _sendPort.send(_receivePort.sendPort);

    // Initialize database immediately to prevent race conditions with read service
    try {
      await _initDatabase();
      debugPrint('[DB Write Isolate] Database initialized proactively');
    } catch (e, stack) {
      debugPrint('[DB Write Isolate] Error during proactive initialization: $e\n$stack');
    }

    // Listen for commands
    _receivePort.listen((message) async {
      if (_isShuttingDown) return;

      if (message is Map<String, dynamic>) {
        final command = DatabaseCommand.fromJson(message);
        await _handleCommand(command);
      }
    });

    debugPrint('[DB Write Isolate] Started and listening for commands');
  }

  /// Handles incoming database commands
  Future<void> _handleCommand(DatabaseCommand command) async {
    try {
      // Initialize database on first command
      if (_database == null) {
        await _initDatabase();
      }

      if (command.type == DatabaseCommandType.shutdown) {
        await _shutdown();
        return;
      }

      final result = await _executeCommand(command);
      _sendResponse(DatabaseResponse.success(command.requestId, result));
    } catch (e, stack) {
      debugPrint('[DB Write Isolate] Error executing command: $e\n$stack');
      _sendResponse(DatabaseResponse.error(
        command.requestId,
        e.toString(),
        stackTrace: stack.toString(),
      ));
    }
  }

  /// Initializes the database connection
  Future<void> _initDatabase() async {
    debugPrint('[DB Write Isolate] Initializing database...');

    // Initialize app paths service in isolate
    await AppPathsService().initialize();

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = AppPathsService().databasePath;
    _database = await openDatabase(
      dbPath,
      version: SchemaManager.currentVersion,
      onCreate: SchemaManager.onCreate,
      onUpgrade: SchemaManager.onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA busy_timeout=30000');
        debugPrint('[DB Write Isolate] WAL mode enabled, busy timeout set to 30s');
      },
    );

    debugPrint('[DB Write Isolate] Database initialized successfully');
  }

  /// Executes a database command and returns result
  Future<dynamic> _executeCommand(DatabaseCommand command) async {
    final db = _database!;

    switch (command.type) {
      case DatabaseCommandType.insert:
        return await db.insert(
          command.table!,
          command.values!,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

      case DatabaseCommandType.update:
        return await db.update(
          command.table!,
          command.values!,
          where: command.where,
          whereArgs: command.whereArgs,
        );

      case DatabaseCommandType.delete:
        return await db.delete(
          command.table!,
          where: command.where,
          whereArgs: command.whereArgs,
        );

      case DatabaseCommandType.execute:
        return await db.execute(command.sql!, command.arguments);

      case DatabaseCommandType.transaction:
        return await _executeTransaction(db, command.transactionCommands!);

      case DatabaseCommandType.shutdown:
        // Handled in _handleCommand
        return null;
    }
  }

  /// Executes multiple commands in a single transaction
  Future<List<dynamic>> _executeTransaction(
    Database db,
    List<DatabaseCommand> commands,
  ) async {
    final results = <dynamic>[];

    await db.transaction((txn) async {
      for (final command in commands) {
        dynamic result;

        switch (command.type) {
          case DatabaseCommandType.insert:
            result = await txn.insert(
              command.table!,
              command.values!,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            break;

          case DatabaseCommandType.update:
            result = await txn.update(
              command.table!,
              command.values!,
              where: command.where,
              whereArgs: command.whereArgs,
            );
            break;

          case DatabaseCommandType.delete:
            result = await txn.delete(
              command.table!,
              where: command.where,
              whereArgs: command.whereArgs,
            );
            break;

          case DatabaseCommandType.execute:
            await txn.execute(command.sql!, command.arguments);
            result = null;
            break;

          case DatabaseCommandType.transaction:
          case DatabaseCommandType.shutdown:
            throw Exception('Nested transactions not supported');
        }

        results.add(result);
      }
    });

    return results;
  }

  /// Sends response back to main isolate
  void _sendResponse(DatabaseResponse response) {
    _sendPort.send(response.toJson());
  }

  /// Shuts down the isolate
  Future<void> _shutdown() async {
    _isShuttingDown = true;
    debugPrint('[DB Write Isolate] Shutting down...');

    if (_database != null) {
      await _database!.close();
      debugPrint('[DB Write Isolate] Database closed');
    }

    _receivePort.close();
    debugPrint('[DB Write Isolate] Shutdown complete');
  }
}
