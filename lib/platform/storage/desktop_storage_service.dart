import 'storage_service.dart';

/// Desktop implementation of storage service using in-memory storage
/// Note: For production, consider using a file-based storage solution
class DesktopStorageService implements StorageService {
  final Map<String, String> _storage = {};

  Map<String, String> get storage => _storage;

  @override
  Future<void> setString(String key, String value) async {
    storage[key] = value;
  }

  @override
  Future<String?> getString(String key) async {
    return storage[key];
  }

  @override
  Future<void> setInt(String key, int value) async {
    storage[key] = value.toString();
  }

  @override
  Future<int?> getInt(String key) async {
    final value = storage[key];
    return value != null ? int.tryParse(value) : null;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    storage[key] = value.toString();
  }

  @override
  Future<bool?> getBool(String key) async {
    final value = storage[key];
    if (value == null) return null;
    return value.toLowerCase() == 'true';
  }

  @override
  Future<void> remove(String key) async {
    storage.remove(key);
  }

  @override
  Future<void> clear() async {
    storage.clear();
  }
}
