import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:penpeeper/services/app_paths_service.dart';
import 'gradient_config.dart';

class ThemeLoader {
  static Future<List<String>> getAvailableThemes() async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('/api/themes'));
        if (response.statusCode == 200) {
          final List<dynamic> themes = json.decode(response.body);
          return themes.cast<String>();
        }
      } catch (e) {
        debugPrint('Error loading themes from API: $e');
      }
      return ['Default', 'BlueHint', 'burntorange', 'Crimson', 'DarkTeal', 'DeepOcean', 'GreenHint', 'Kermit', 'Office', 'ShadesOfGrey', 'Tron', 'WaterMelon'];
    }

    // Bundled themes that are always included with the app
    final Set<String> allThemes = {
      'Default',
      'BlueHint',
      'burntorange',
      'Crimson',
      'DarkTeal',
      'DeepOcean',
      'GreenHint',
      'Kermit',
      'Office',
      'ShadesOfGrey',
      'Tron',
      'WaterMelon',
    };

    // Try to discover additional themes from filesystem (only if AppPathsService is available)
    try {
      final pathsService = AppPathsService();
      // Check if initialized
      final _ = pathsService.appDataDir;

      // Add user themes from the user themes directory (writable, in app data dir)
      try {
        final userThemesDir = Directory(pathsService.themesDir);
        if (await userThemesDir.exists()) {
          debugPrint('Found user themes directory at: ${userThemesDir.path}');
          final files = await userThemesDir.list().toList();
          final themes = files
              .where((f) => f.path.endsWith('.penTheme'))
              .map((f) => f.path.split(Platform.pathSeparator).last.replaceAll('.penTheme', ''))
              .toSet();
          allThemes.addAll(themes);
          debugPrint('Added ${themes.length} user themes');
        }
      } catch (e) {
        debugPrint('Error checking user themes directory: $e');
      }

      // Try to discover additional bundled themes from filesystem (development mode)
      final bundledPaths = pathsService.getBundledThemesPaths();
      for (final themePath in bundledPaths) {
        try {
          final themesDir = Directory(themePath);
          if (await themesDir.exists()) {
            debugPrint('Found bundled themes directory at: $themePath');
            final files = await themesDir.list().toList();
            final themes = files
                .where((f) => f.path.endsWith('.penTheme'))
                .map((f) => f.path.split(Platform.pathSeparator).last.replaceAll('.penTheme', ''))
                .toSet();
            allThemes.addAll(themes);
            debugPrint('Added ${themes.length} bundled themes from $themePath');
          }
        } catch (e) {
          debugPrint('Error checking bundled themes directory $themePath: $e');
        }
      }
    } catch (e) {
      debugPrint('AppPathsService not available, using hardcoded theme list: $e');
    }

    final themeList = allThemes.toList()..sort();
    debugPrint('Total available themes: ${themeList.length}');
    return themeList;
  }
  
  static Future<Map<String, dynamic>> loadTheme(String themeName) async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('/api/themes/$themeName'));
        if (response.statusCode == 200) {
          return json.decode(response.body);
        }
      } catch (e) {
        debugPrint('Error loading theme from API: $e');
      }
      final String jsonString = await rootBundle.loadString('Themes/$themeName.penTheme');
      return _safeDecode(jsonString);
    }

    // 1. FIRST: Try loading from rootBundle (Flutter assets) - works in all packaged apps
    // This does NOT require AppPathsService and works in all environments
    debugPrint('🎨 Attempting to load theme: $themeName');
    debugPrint('Will try: Themes/$themeName.penTheme and Themes/${themeName.toLowerCase()}.penTheme');

    for (final name in [themeName, themeName.toLowerCase()]) {
      try {
        debugPrint('Trying rootBundle.loadString(Themes/$name.penTheme)...');
        final String jsonString = await rootBundle.loadString('Themes/$name.penTheme');
        debugPrint('✅ SUCCESS! Loaded theme from bundled assets: Themes/$name.penTheme');
        return _safeDecode(jsonString);
      } catch (e) {
        debugPrint('❌ Could not load theme from assets Themes/$name.penTheme: $e');
      }
    }

    debugPrint('⚠️  rootBundle failed for both attempts, falling back to filesystem...');

    // 2. Try loading from user themes directory (user-customizable themes)
    // Only attempt if AppPathsService is initialized
    try {
      final pathsService = AppPathsService();
      // Check if initialized by accessing appDataDir (will throw if not initialized)
      try {
        final _ = pathsService.appDataDir;
        debugPrint('AppPathsService is initialized, checking user themes...');
      } on StateError catch (e) {
        debugPrint('AppPathsService not initialized (expected): $e');
        throw e; // Re-throw to outer catch
      }

      for (final name in [themeName, themeName.toLowerCase()]) {
        try {
          final themePath = path.join(pathsService.themesDir, '$name.penTheme');
          final themeFile = File(themePath);

          if (await themeFile.exists()) {
            debugPrint('✓ Loading user theme from: $themePath');
            final String jsonString = await themeFile.readAsString();
            return _safeDecode(jsonString);
          }
        } catch (e) {
          debugPrint('Could not load user theme $name.penTheme: $e');
        }
      }

      // 3. FALLBACK: Try bundled themes directories via filesystem (development mode)
      final bundledPaths = pathsService.getBundledThemesPaths();
      debugPrint('Checking bundled theme paths: $bundledPaths');

      for (final name in [themeName, themeName.toLowerCase()]) {
        for (final basePath in bundledPaths) {
          try {
            final themePath = path.join(basePath, '$name.penTheme');
            final themeFile = File(themePath);

            if (await themeFile.exists()) {
              debugPrint('✓ Loading bundled theme from filesystem: $themePath');
              final String jsonString = await themeFile.readAsString();
              return _safeDecode(jsonString);
            }
          } catch (e) {
            debugPrint('Could not load bundled theme from $basePath/$name.penTheme: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('AppPathsService not available, skipping filesystem theme search: $e');
    }

    debugPrint('❌ Theme file not found: $themeName');
    throw Exception('Theme file not found: $themeName.penTheme');
  }

  static Map<String, dynamic> _safeDecode(String jsonString) {
    try {
      return json.decode(jsonString);
    } catch (e) {
      debugPrint('JSON Parsing Error: $e');
      // Print context around the error if possible
      if (e is FormatException) {
        debugPrint('Error at offset ${e.offset}');
        final start = (e.offset ?? 0) - 20;
        final end = (e.offset ?? 0) + 20;
        if (start >= 0 && end < jsonString.length) {
          debugPrint('Context: ...${jsonString.substring(start, end)}...');
        }
      }
      rethrow;
    }
  }

  static IconData getIconData(String iconName) {
    final iconMap = {
      'security': Icons.security,
      'folder': Icons.folder,
      'folder_outlined': Icons.folder_outlined,
      'add': Icons.add,
      'edit': Icons.edit,
      'delete': Icons.delete,
      'search': Icons.search,
      'flag': Icons.flag,
      'error': Icons.error,
      'terminal': Icons.terminal,
      'launch': Icons.launch,
      'close': Icons.close,
      'link': Icons.link,
      'save': Icons.save,
      'computer': Icons.computer,
      'business': Icons.business,
      'arrow_forward_ios': Icons.arrow_forward_ios,
      'device_unknown': Icons.device_unknown,
      'auto_fix_high': Icons.auto_fix_high,
      'web': Icons.web,
      'bug_report': Icons.bug_report,
      'language': Icons.language,
      'folder_shared': Icons.folder_shared,
      'find_in_page': Icons.find_in_page,
      'storage': Icons.storage,
      'dns': Icons.dns,
      'info_outline': Icons.info_outline,
      'file_download': Icons.file_download,
      'keyboard_arrow_up': Icons.keyboard_arrow_up,
      'keyboard_arrow_down': Icons.keyboard_arrow_down,
      'circle': Icons.circle,
      'arrow_drop_down': Icons.arrow_drop_down,
      'devices': Icons.devices,
      'list': Icons.list,
      'list_alt': Icons.list_alt,
      'location_on': Icons.location_on,
      'settings': Icons.settings,
      'label': Icons.label,
    };
    return iconMap[iconName] ?? Icons.help;
  }

  static Color parseColor(String colorString) {
    return Color(int.parse(colorString.replaceFirst('0x', ''), radix: 16));
  }

  static FontWeight parseFontWeight(int weight) {
    switch (weight) {
      case 400: return FontWeight.w400;
      case 500: return FontWeight.w500;
      case 600: return FontWeight.w600;
      case 700: return FontWeight.w700;
      default: return FontWeight.w400;
    }
  }
  
  static GradientConfig? parseGradientConfig(dynamic json) {
    if (json == null) return null;
    try {
      return GradientConfig.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error parsing gradient config: $e');
      return null;
    }
  }
}
