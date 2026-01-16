import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common/sqlite_api.dart';
import 'database_service.dart';
import '../../api_database_helper_web.dart'
    if (dart.library.io) '../../api_database_helper_stub.dart';

/// Web implementation of database service using HTTP API calls
class WebDatabaseService implements DatabaseService {
  static String get baseUrl => getBaseUrl();

  @override
  Future<void> initialize() async {
    debugPrint('Web database service initialized (API-based)');
  }

  @override
  Future<Database> getDatabase() async {
    throw UnsupportedError('Direct database access not available on web - use API methods');
  }

  @override
  Future<void> close() async {
    // No-op for web
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? args]) async {
    throw UnsupportedError('Raw SQL queries not supported on web - use specific API endpoints');
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> values, {ConflictAlgorithm? conflictAlgorithm}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/db/$table'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(values),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['id'];
      }
      throw Exception('Failed to insert into $table');
    } catch (e) {
      debugPrint('Error inserting into $table: $e');
      rethrow;
    }
  }

  @override
  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<dynamic>? whereArgs}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/db/$table'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'values': values,
          'where': where,
          'whereArgs': whereArgs,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['affected'];
      }
      throw Exception('Failed to update $table');
    } catch (e) {
      debugPrint('Error updating $table: $e');
      rethrow;
    }
  }

  @override
  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/db/$table'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'where': where,
          'whereArgs': whereArgs,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['affected'];
      }
      throw Exception('Failed to delete from $table');
    } catch (e) {
      debugPrint('Error deleting from $table: $e');
      rethrow;
    }
  }

  @override
  Future<void> execute(String sql, [List<dynamic>? args]) async {
    throw UnsupportedError('Raw SQL execution not supported on web - use specific API endpoints');
  }

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    throw UnsupportedError('Transactions not supported on web - use specific API endpoints');
  }
}
