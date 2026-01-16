import 'package:flutter/foundation.dart';
import 'storage_service.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation of storage service using localStorage
class WebStorageService implements StorageService {
  html.Storage get _storage => html.window.localStorage;

  @override
  Future<void> setString(String key, String value) async {
    try {
      _storage[key] = value;
    } catch (e) {
      debugPrint('Error setting string: $e');
      rethrow;
    }
  }

  @override
  Future<String?> getString(String key) async {
    try {
      return _storage[key];
    } catch (e) {
      debugPrint('Error getting string: $e');
      return null;
    }
  }

  @override
  Future<void> setInt(String key, int value) async {
    try {
      _storage[key] = value.toString();
    } catch (e) {
      debugPrint('Error setting int: $e');
      rethrow;
    }
  }

  @override
  Future<int?> getInt(String key) async {
    try {
      final value = _storage[key];
      return value != null ? int.tryParse(value) : null;
    } catch (e) {
      debugPrint('Error getting int: $e');
      return null;
    }
  }

  @override
  Future<void> setBool(String key, bool value) async {
    try {
      _storage[key] = value.toString();
    } catch (e) {
      debugPrint('Error setting bool: $e');
      rethrow;
    }
  }

  @override
  Future<bool?> getBool(String key) async {
    try {
      final value = _storage[key];
      if (value == null) return null;
      return value.toLowerCase() == 'true';
    } catch (e) {
      debugPrint('Error getting bool: $e');
      return null;
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      _storage.remove(key);
    } catch (e) {
      debugPrint('Error removing key: $e');
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    try {
      _storage.clear();
    } catch (e) {
      debugPrint('Error clearing storage: $e');
      rethrow;
    }
  }
}
