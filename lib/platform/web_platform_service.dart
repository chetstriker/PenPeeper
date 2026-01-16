import 'platform_service.dart';
import 'database/database_service.dart';
import 'database/web_database_service.dart';
import 'file/file_service.dart';
import 'file/web_file_service.dart';
import 'storage/storage_service.dart';
import 'storage/web_storage_service.dart';

/// Web platform service implementation
class WebPlatformService implements PlatformService {
  final DatabaseService _database = WebDatabaseService();
  final FileService _file = WebFileService();
  final StorageService _storage = WebStorageService();

  @override
  bool get isWeb => true;

  @override
  bool get isDesktop => false;

  @override
  String get platformName => 'Web';

  @override
  DatabaseService get database => _database;

  @override
  FileService get file => _file;

  @override
  StorageService get storage => _storage;
}
