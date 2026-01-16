import 'dart:io';
import 'package:penpeeper/services/config_service.dart';

/// Utility class for handling WSL-specific operations on Windows
class WSLUtils {
  /// Generate a simple temp file path for WSL operations
  static String getWSLTempPath(String prefix, String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '/tmp/${prefix}_$timestamp.$extension';
  }

  /// Read a file from WSL filesystem
  static Future<String> readWSLFile(String wslPath) async {
    if (!ConfigService.isWindows) {
      throw Exception('WSL operations only supported on Windows');
    }
    
    final result = await Process.run('wsl.exe', ['cat', wslPath]);
    if (result.exitCode == 0) {
      return result.stdout;
    }
    throw Exception('Failed to read WSL file: ${result.stderr}');
  }

  /// Delete a file from WSL filesystem
  static Future<void> deleteWSLFile(String wslPath) async {
    if (!ConfigService.isWindows) return;
    
    try {
      await Process.run('wsl.exe', ['rm', '-f', wslPath]);
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Check if a file exists in WSL filesystem
  static Future<bool> wslFileExists(String wslPath) async {
    if (!ConfigService.isWindows) return false;
    
    try {
      final result = await Process.run('wsl.exe', ['test', '-f', wslPath]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}