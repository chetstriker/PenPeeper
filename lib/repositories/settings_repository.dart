import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/database/database_read_service.dart';
import 'package:penpeeper/database/isolate/database_isolate_manager.dart';
import 'package:penpeeper/utils/platform/platform_utils.dart';
import 'package:http/http.dart' as http;

class SettingsRepository {
  final _readService = DatabaseReadService();
  final _writeManager = DatabaseIsolateManager();

  /// Gets a setting value by key
  Future<String> getSetting(String key, String defaultValue) async {
    if (kIsWeb) {
      try {
        final response = await http.get(
          Uri.parse('/api/settings/$key?default=$defaultValue'),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['value'] as String? ?? defaultValue;
        }
      } catch (e) {
        debugPrint('Error getting setting from API: $e');
      }
      return defaultValue;
    }

    final result = await _readService.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (result.isEmpty) {
      return defaultValue;
    }

    return result.first['value'] as String? ?? defaultValue;
  }

  /// Gets an integer setting value
  Future<int> getIntSetting(String key, int defaultValue) async {
    final value = await getSetting(key, defaultValue.toString());
    return int.tryParse(value) ?? defaultValue;
  }

  /// Sets a setting value (write operation - goes through isolate)
  Future<void> setSetting(String key, String value) async {
    if (kIsWeb) {
      try {
        await http.post(
          Uri.parse('/api/settings/$key'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'value': value}),
        );
      } catch (e) {
        debugPrint('Error setting value via API: $e');
      }
      return;
    }

    await _writeManager.insert('settings', {'key': key, 'value': value});
  }

  /// Initializes default settings (web only)
  Future<void> initializeDefaults() async {
    if (kIsWeb) {
      try {
        await http.post(Uri.parse('/api/settings/init'));
      } catch (e) {
        debugPrint('Error initializing defaults via API: $e');
      }
    }
  }

  /// Sets an integer setting value
  Future<void> setIntSetting(String key, int value) async {
    await setSetting(key, value.toString());
  }

  /// Deletes a setting (write operation - goes through isolate)
  Future<void> deleteSetting(String key) async {
    return await PlatformUtils.platformSpecific(
      web: () async {
        // Web implementation if needed
      },
      desktop: () async {
        await _writeManager.delete(
          'settings',
          where: 'key = ?',
          whereArgs: [key],
        );
      },
    );
  }

  /// Gets all settings
  Future<Map<String, String>> getAllSettings() async {
    return await PlatformUtils.platformSpecific(
      web: () async => <String, String>{},
      desktop: () async {
        final result = await _readService.query('settings');

        return Map.fromEntries(
          result.map((row) => MapEntry(
            row['key'] as String,
            row['value'] as String,
          )),
        );
      },
    );
  }
}
