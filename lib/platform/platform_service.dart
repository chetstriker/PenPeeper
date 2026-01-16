import 'database/database_service.dart';
import 'file/file_service.dart';
import 'storage/storage_service.dart';

/// Abstract interface for platform-specific services
abstract class PlatformService {
  /// Check if running on web platform
  bool get isWeb;

  /// Check if running on desktop platform
  bool get isDesktop;

  /// Get the platform name
  String get platformName;

  /// Get the database service
  DatabaseService get database;

  /// Get the file service
  FileService get file;

  /// Get the storage service
  StorageService get storage;
}
