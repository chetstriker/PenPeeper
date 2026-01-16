import 'package:flutter/foundation.dart';

/// Platform-agnostic execution wrapper
/// Eliminates direct kIsWeb checks from business logic
class PlatformExecutor {
  /// Execute platform-specific code
  static Future<T> execute<T>({
    required Future<T> Function() web,
    required Future<T> Function() desktop,
  }) async {
    if (kIsWeb) {
      return await web();
    } else {
      return await desktop();
    }
  }

  /// Execute platform-specific code synchronously
  static T executeSync<T>({
    required T Function() web,
    required T Function() desktop,
  }) {
    if (kIsWeb) {
      return web();
    } else {
      return desktop();
    }
  }

  /// Check if running on web
  static bool get isWeb => kIsWeb;

  /// Check if running on desktop
  static bool get isDesktop => !kIsWeb;
}
