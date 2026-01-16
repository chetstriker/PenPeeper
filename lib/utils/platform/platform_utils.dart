import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform detection and abstraction utilities
class PlatformUtils {
  /// Check if running on web platform
  static bool get isWeb => kIsWeb;

  /// Check if running on desktop platform (not web)
  static bool get isDesktop => !kIsWeb;

  /// Check if running on Windows
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// Check if running on Linux
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  /// Check if running on macOS
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// Execute platform-specific code
  /// 
  /// Example:
  /// ```dart
  /// final result = await PlatformUtils.platformSpecific(
  ///   web: () async => await apiCall(),
  ///   desktop: () async => await databaseCall(),
  /// );
  /// ```
  static Future<T> platformSpecific<T>({
    required Future<T> Function() web,
    required Future<T> Function() desktop,
  }) async {
    if (isWeb) {
      return await web();
    } else {
      return await desktop();
    }
  }

  /// Execute platform-specific code synchronously
  /// 
  /// Example:
  /// ```dart
  /// final result = PlatformUtils.platformSpecificSync(
  ///   web: () => 'Web value',
  ///   desktop: () => 'Desktop value',
  /// );
  /// ```
  static T platformSpecificSync<T>({
    required T Function() web,
    required T Function() desktop,
  }) {
    if (isWeb) {
      return web();
    } else {
      return desktop();
    }
  }

  /// Execute code only on web platform
  /// 
  /// Example:
  /// ```dart
  /// await PlatformUtils.onWeb(() async => await apiCall());
  /// ```
  static Future<T?> onWeb<T>(Future<T> Function() action) async {
    if (isWeb) {
      return await action();
    }
    return null;
  }

  /// Execute code only on desktop platform
  /// 
  /// Example:
  /// ```dart
  /// await PlatformUtils.onDesktop(() async => await databaseCall());
  /// ```
  static Future<T?> onDesktop<T>(Future<T> Function() action) async {
    if (isDesktop) {
      return await action();
    }
    return null;
  }

  /// Get platform name as string
  static String get platformName {
    if (isWeb) return 'Web';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    if (isMacOS) return 'macOS';
    return 'Unknown';
  }
}
