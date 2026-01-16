import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path/path.dart' as path;
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/repositories/settings_repository.dart';
import 'package:penpeeper/server/terminal_server.dart';
import 'package:penpeeper/screens/home_screen.dart';
import 'package:penpeeper/database/isolate/database_isolate_manager.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'package:penpeeper/utils/debug_logger.dart';
import 'package:simple_spell_checker_en_lan/simple_spell_checker_en_lan.dart';

void main(List<String> args) async {
  // MUST initialize Flutter bindings first!
  WidgetsFlutterBinding.ensureInitialized();

  // Capture all Flutter errors in release mode
  FlutterError.onError = (FlutterErrorDetails details) async {
    FlutterError.presentError(details);
    debugPrint('❌ Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');

    // Write to debug log
    try {
      await DebugLogger().logError(
        'FLUTTER_ERROR',
        'Flutter Error: ${details.exception}',
        details.stack,
      );
      await DebugLogger().flush();
    } catch (e) {
      debugPrint('Failed to write Flutter error to log: $e');
    }
  };

  // Capture errors in async operations that aren't caught by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('❌ Platform Error: $error');
    debugPrint('Stack trace: $stack');

    // Write to debug log
    try {
      DebugLogger().logError(
        'PLATFORM_ERROR',
        'Platform Error: $error',
        stack,
      );
      DebugLogger().flush();
    } catch (e) {
      debugPrint('Failed to write platform error to log: $e');
    }

    return true; // Indicates error was handled
  };

  try {
    // Initialize application paths service (required for both GUI and terminal mode)
    // This MUST be after WidgetsFlutterBinding.ensureInitialized()
    await AppPathsService().initialize();

    final pathsService = AppPathsService();

    // Display all important paths (desktop only, not web)
    if (!kIsWeb) {
      debugPrint('===========================================');
      debugPrint('PenPeeper Application Paths');
      debugPrint('===========================================');
      debugPrint('Executable Path:        ${Platform.resolvedExecutable}');
      debugPrint('Executable Directory:   ${path.dirname(Platform.resolvedExecutable)}');
      debugPrint('');
      debugPrint('--- User Data Directory ---');
      debugPrint('App Data Directory:     ${pathsService.appDataDir}');
      debugPrint('');
      debugPrint('--- Writable Files & Folders ---');
      debugPrint('Database File:          ${pathsService.databasePath}');
      debugPrint('Uploads Directory:      ${pathsService.uploadsDir}');
      debugPrint('User Themes Directory:  ${pathsService.themesDir}');
      debugPrint('Config File:            ${pathsService.configPath}');
      debugPrint('Risk File:              ${pathsService.riskPath}');
      debugPrint('Debug Log File:         ${pathsService.debugLogPath}');
      debugPrint('Temp Scan Directory:    ${pathsService.tempScanDir}');
      debugPrint('System Temp Directory:  ${pathsService.systemTempDir}');
      debugPrint('');
      debugPrint('--- Read-Only (Bundled) Themes ---');
      final bundledPaths = pathsService.getBundledThemesPaths();
      for (int i = 0; i < bundledPaths.length; i++) {
        debugPrint('Bundled Themes [$i]:     ${bundledPaths[i]}');
      }
      debugPrint('');
      debugPrint('WSL Detected:           ${pathsService.isWSL}');
      debugPrint('===========================================');

    // Check for legacy data and offer migration (desktop only)
    if (await pathsService.hasLegacyData()) {
      debugPrint('');
      debugPrint('⚠️  Legacy data detected - starting migration...');
      await pathsService.migrateLegacyData();
      debugPrint('✅ Legacy data migration completed');
      debugPrint('');
    }
    } else {
      debugPrint('PenPeeper Web - Using API for data storage');
    }

    // Check for terminal mode
    if (args.contains('--term')) {
      await TerminalServer.run();
      return;
    }

    // Initialize database write isolate for concurrent operations (desktop only)
    if (!kIsWeb) {
      debugPrint('Initializing database write isolate...');
      await DatabaseIsolateManager().initialize();
      debugPrint('Database write isolate initialized successfully');
    } else {
      debugPrint('Web platform - skipping isolate initialization (using API calls)');
    }

    // Register enhanced English dictionary
    SimpleSpellCheckerEnRegister.registerLan(preferEnglish: 'en');

    // Load theme with error handling and fallback
    final settingsRepo = SettingsRepository();
    final savedTheme = await settingsRepo.getSetting('theme', 'Default');
    try {
      await AppTheme.loadTheme(savedTheme);
      debugPrint('Theme loaded: $savedTheme');
    } catch (e) {
      debugPrint('⚠️ Failed to load theme "$savedTheme": $e');
      debugPrint('Using default theme configuration');
      // App will continue with default theme colors already defined in AppTheme
    }

    debugPrint('Font family: ${AppTheme.defaultFontFamily}');
    debugPrint('Monospace font: ${AppTheme.monospaceFontFamily}');
    runApp(const PenPeeperApp());
  } catch (e, stack) {
    debugPrint('❌ FATAL ERROR during app initialization:');
    debugPrint('Error: $e');
    debugPrint('Stack trace: $stack');

    // Still try to run the app with defaults
    // WidgetsFlutterBinding already initialized above
    runApp(const PenPeeperApp());
  }
}


class PenPeeperApp extends StatefulWidget {
  const PenPeeperApp({super.key});

  static PenPeeperAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<PenPeeperAppState>();
  }

  @override
  State<PenPeeperApp> createState() => PenPeeperAppState();
}

class PenPeeperAppState extends State<PenPeeperApp> {
  Key _appKey = UniqueKey();

  void rebuildApp() {
    debugPrint('🔄 Rebuilding app with new theme: ${AppTheme.currentThemeName}');
    setState(() {
      _appKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building MaterialApp with theme: ${AppTheme.currentThemeName}');
    return MaterialApp(
      key: _appKey,
      title: 'PenPeeper',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
      ],
      theme: AppTheme.themeData.copyWith(
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: AppTheme.primaryColor.withValues(alpha: 0.3),
          selectionHandleColor: AppTheme.primaryColor,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
          ),
        ),
      ),
      home: HomePage(key: ValueKey(_appKey)),
    );
  }
}
