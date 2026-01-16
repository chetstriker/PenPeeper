import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:penpeeper/database/schema/schema_manager.dart';
import 'package:penpeeper/database/operations/deletion_manager.dart';
import 'package:penpeeper/utils/error/error_handler.dart';
import 'package:penpeeper/services/app_paths_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (kIsWeb) {
      throw Exception('Database not available on web - use API calls');
    }
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      if (kIsWeb) {
        throw Exception('Database not available on web - use API calls');
      }
      debugPrint('Initializing desktop database...');
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dbPath = AppPathsService().databasePath;
      final db = await openDatabase(
        dbPath,
        version: SchemaManager.currentVersion,
        onCreate: SchemaManager.onCreate,
        onUpgrade: SchemaManager.onUpgrade,
        onOpen: (db) async {
          await db.execute('PRAGMA journal_mode=WAL');
          await db.execute('PRAGMA busy_timeout=30000');
          debugPrint('WAL mode enabled, busy timeout set to 30s');
        },
      );
      debugPrint('Desktop database initialized successfully');
      return db;
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Database initialization');
      rethrow;
    }
  }































  Future<void> deleteReportSectionsByProject(int projectId) async {
    final db = await database;
    await DeletionManager.deleteReportSectionsByProject(db, projectId);
  }

  Future<void> deleteNmapCvesByDevice(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteNmapCvesByDevice(db, deviceId);
  }

  Future<void> deleteNmapScriptsByDevice(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteNmapScriptsByDevice(db, deviceId);
  }

  Future<void> deleteNmapPortsByDevice(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteNmapPortsByDevice(db, deviceId);
  }

  Future<void> deleteNmapOsMatchesByDevice(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteNmapOsMatchesByDevice(db, deviceId);
  }

  Future<void> deleteNmapHostsByDevice(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteNmapHostsByDevice(db, deviceId);
  }

  Future<void> deleteDeviceData(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteDeviceData(db, deviceId);
  }

  Future<void> deleteDeviceTags(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteDeviceTags(db, deviceId);
  }

  Future<void> deleteFlaggedFindingsByDevice(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteFlaggedFindingsByDevice(db, deviceId);
  }

  Future<void> deleteFfufFindingsByDevice(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteFfufFindingsByDevice(db, deviceId);
  }

  Future<void> deleteSambaLdapFindingsByDevice(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteSambaLdapFindingsByDevice(db, deviceId);
  }

  Future<void> deleteScansByDevice(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteScansByDevice(db, deviceId);
  }

  Future<void> deleteSnmpFindingsByDevice(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteSnmpFindingsByDevice(db, deviceId);
  }

  Future<void> deleteVulnerabilitiesByDevice(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteVulnerabilitiesByDevice(db, deviceId);
  }

  Future<void> deleteVulnerabilityClassificationsByDevice(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteVulnerabilityClassificationsByDevice(db, deviceId);
  }

  Future<void> deleteWhatwebFindingsByDevice(int deviceId) async {
    final db = await database;
    await DeletionManager.deleteWhatwebFindingsByDevice(db, deviceId);
  }

  Future<void> deleteDevicesByProject(int projectId) async {
    final db = await database;
    await DeletionManager.deleteDevicesByProject(db, projectId);
  }
}
