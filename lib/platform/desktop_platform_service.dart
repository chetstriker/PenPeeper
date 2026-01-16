import 'dart:io';
import 'platform_service.dart';
import 'database/database_service.dart';
import 'database/desktop_database_service.dart';
import 'file/file_service.dart';
import 'file/desktop_file_service.dart';
import 'storage/storage_service.dart';
import 'storage/desktop_storage_service.dart';

/// Desktop platform service implementation
class DesktopPlatformService implements PlatformService {
  final DatabaseService _database = DesktopDatabaseService();
  final FileService _file = DesktopFileService();
  final StorageService _storage = DesktopStorageService();

  @override
  bool get isWeb => false;

  @override
  bool get isDesktop => true;

  @override
  String get platformName {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    return 'Desktop';
  }

  @override
  DatabaseService get database => _database;

  @override
  FileService get file => _file;

  @override
  StorageService get storage => _storage;
}
