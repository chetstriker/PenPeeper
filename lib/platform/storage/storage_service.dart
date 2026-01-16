/// Abstract interface for platform-specific storage operations
abstract class StorageService {
  /// Store a string value
  Future<void> setString(String key, String value);

  /// Retrieve a string value
  Future<String?> getString(String key);

  /// Store an integer value
  Future<void> setInt(String key, int value);

  /// Retrieve an integer value
  Future<int?> getInt(String key);

  /// Store a boolean value
  Future<void> setBool(String key, bool value);

  /// Retrieve a boolean value
  Future<bool?> getBool(String key);

  /// Remove a value by key
  Future<void> remove(String key);

  /// Clear all stored values
  Future<void> clear();
}
