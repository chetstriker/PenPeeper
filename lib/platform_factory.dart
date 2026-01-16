import 'package:flutter/foundation.dart';
import 'platform/platform_service.dart';
import 'platform/desktop_platform_service.dart';
import 'platform/web_platform_service.dart';

/// Factory for creating platform-specific services
class PlatformFactory {
  static PlatformService? _instance;

  /// Get the platform service instance
  static PlatformService get instance {
    _instance ??= kIsWeb ? WebPlatformService() : DesktopPlatformService();
    return _instance!;
  }

  /// Initialize with a specific platform service (for testing)
  static void initialize(PlatformService service) {
    _instance = service;
  }

  /// Reset the instance (for testing)
  static void reset() {
    _instance = null;
  }
}
