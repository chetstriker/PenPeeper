import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/services/config_service.dart';

/// Resolves full paths to command-line tools on macOS/Linux
/// Caches paths to avoid repeated lookups
class CommandPathResolver {
  static final CommandPathResolver _instance = CommandPathResolver._internal();
  factory CommandPathResolver() => _instance;
  CommandPathResolver._internal();

  final Map<String, String> _pathCache = {};

  /// Find the full path to a command on macOS/Linux
  /// Returns the cached path if available, otherwise searches PATH
  Future<String?> findCommandPath(String command) async {
    // Return cached path if available
    if (_pathCache.containsKey(command)) {
      return _pathCache[command];
    }

    // Skip path resolution for Windows (uses WSL) or Web
    if (!ConfigService.isLinux && !ConfigService.isMacOS) {
      return command; // Just return the command name
    }

    String? path;

    if (ConfigService.isMacOS) {
      try {
        final homeDir = Platform.environment['HOME'] ?? '/tmp';
        // Comprehensive PATH for macOS including common tool installation locations
        final expandedPath = [
          '$homeDir/.local/bin',
          '/opt/homebrew/bin',
          '/opt/homebrew/sbin', 
          '/usr/local/bin',
          '/usr/local/sbin',
          '/usr/bin',
          '/usr/sbin',
          '/bin',
          '/sbin',
          '$homeDir/bin',
          '/opt/local/bin', // MacPorts
          '/sw/bin', // Fink
        ].join(':');
        
        final result = await Process.run('/bin/zsh', [
          '-c',
          'export PATH="$expandedPath" && command -v $command'
        ]);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          path = result.stdout.toString().trim();
          debugPrint('✓ Found $command at: $path');
        } else {
          debugPrint('✗ $command not found in expanded PATH');
        }
      } catch (e) {
        debugPrint('Error finding $command: $e');
      }
    } else if (ConfigService.isLinux) {
      try {
        final result = await Process.run('bash', ['-c', 'command -v $command']);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          path = result.stdout.toString().trim();
          debugPrint('✓ Found $command at: $path');
        }
      } catch (e) {
        debugPrint('Error finding $command: $e');
      }
    }

    // Cache the path (even if null) to avoid repeated failed lookups
    if (path != null) {
      _pathCache[command] = path;
    }

    return path;
  }

  /// Get a command path, throwing an error if not found
  Future<String> requireCommandPath(String command) async {
    final path = await findCommandPath(command);
    if (path == null) {
      throw Exception('$command not found in PATH. Please install $command.');
    }
    return path;
  }

  /// Clear the cache (useful for testing or after tool installation)
  void clearCache() {
    _pathCache.clear();
    debugPrint('Command path cache cleared');
  }

  /// Clear cache for a specific command
  void clearCommandCache(String command) {
    _pathCache.remove(command);
    debugPrint('Cleared cache for $command');
  }
}
