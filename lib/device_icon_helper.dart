import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:penpeeper/icon_list.dart';
import 'package:penpeeper/services/app_paths_service.dart';

class DeviceIconHelper {
  static String _getIconDirectory() {
    if (kIsWeb) {
      return 'assets/icons'; // Web platform uses assets
    }

    // Try multiple locations for icons in order of preference:

    // 1. Check user's data directory (custom icons or copied defaults)
    //    This is the safe location that works in all packaged apps
    try {
      final userIconDir = AppPathsService().iconsDir;
      if (Directory(userIconDir).existsSync()) {
        return userIconDir;
      }
    } catch (e) {
      // AppPathsService not initialized yet, continue to next option
    }

    // 2. Check bundled icon locations (default icons shipped with app)
    final exePath = Platform.resolvedExecutable;
    final exeDir = path.dirname(exePath);

    final bundledPaths = [
      path.join(exeDir, 'IconLocation'), // Windows/Linux development
      path.join(exeDir, 'data', 'flutter_assets', 'IconLocation'), // Linux package
      path.join(exeDir, '..', 'Resources', 'IconLocation'), // macOS bundle
      path.join(exeDir, '..', 'Resources', 'flutter_assets', 'IconLocation'), // macOS bundle alt
      path.join(exeDir, '..', 'Frameworks', 'App.framework', 'Versions', 'A', 'Resources', 'flutter_assets', 'IconLocation'), // macOS deep bundle
    ];

    for (final bundlePath in bundledPaths) {
      if (Directory(bundlePath).existsSync()) {
        return bundlePath;
      }
    }

    // 3. Last resort - return user's icon directory even if it doesn't exist yet
    //    (it will be created by AppPathsService initialization)
    try {
      return AppPathsService().iconsDir;
    } catch (e) {
      // If AppPathsService isn't initialized, return the first bundled path as fallback
      return bundledPaths[0];
    }
  }

  static String getIconPath(String iconType) {
    final filename = iconList[iconType] ?? 'default.png';
    final iconDir = _getIconDirectory();
    return path.join(iconDir, filename);
  }

  static String getLabel(String iconType) {
    return iconLabels[iconType] ?? 'Unknown';
  }

  static Widget getIconWidget(String iconType, {double size = 24, Color? color}) {
    if (kIsWeb) {
      // On web, use Image.asset to load PNG files
      final filename = iconList[iconType] ?? 'default.png';
      final assetPath = 'IconLocation/$filename';
      
      return Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.device_unknown,
            size: size,
            color: color ?? const Color(0xFF888888),
          );
        },
      );
    }
    
    final iconPath = getIconPath(iconType);
    final filename = iconList[iconType] ?? 'default.png';
    
    return Image.file(
      File(iconPath),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to bundled assets using Image.asset
        return Image.asset(
          'IconLocation/$filename',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to default asset
             return Image.asset(
               'IconLocation/default.png',
               width: size,
               height: size,
               fit: BoxFit.contain,
               errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.device_unknown,
                    size: size,
                    color: color ?? const Color(0xFF888888),
                  );
               }
             );
          },
        );
      },
    );
  }
}
