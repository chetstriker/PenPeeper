import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Centralized service for managing application data directories across platforms.
///
/// Platform-specific paths:
/// - Linux: ~/.local/share/penpeeper/
/// - macOS: ~/Library/Application Support/com.penpeeper.app/
/// - Windows: %APPDATA%\penpeeper\
/// - Web: IndexedDB (database) and memory/local storage (files)
class AppPathsService {
  static final AppPathsService _instance = AppPathsService._internal();
  factory AppPathsService() => _instance;
  AppPathsService._internal();

  String? _appDataDir;
  String? _tempDir;
  bool _initialized = false;

  /// Initialize the path service and create necessary directories.
  /// Must be called before any path getters are used.
  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      // Web platform doesn't have a traditional filesystem
      _appDataDir = '/penpeeper'; // Virtual path for web
      _tempDir = '/tmp';
      _initialized = true;
      return;
    }

    try {
      // Get platform-specific application support directory
      final appSupportDir = await getApplicationSupportDirectory();
      _appDataDir = appSupportDir.path;

      // Get temp directory
      final tempDirectory = await getTemporaryDirectory();
      _tempDir = tempDirectory.path;

      // Create required subdirectories
      await _createRequiredDirectories();

      // Copy bundled risk.png if it doesn't exist
      await _ensureRiskImageExists();

      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize app paths: $e');
    }
  }

  /// Create all required subdirectories for the application.
  Future<void> _createRequiredDirectories() async {
    if (kIsWeb) return;

    // Build directory paths directly without using getters (which check _initialized)
    final dirs = [
      path.join(_appDataDir!, 'uploads'),
      path.join(_appDataDir!, 'Themes'),
      path.join(_appDataDir!, 'IconLocation'),
      path.join(_tempDir!, 'penpeeper_scans'),
    ];

    for (final dir in dirs) {
      final directory = Directory(dir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
  }

  /// Copy the bundled risk.png asset to AppData if it doesn't exist.
  Future<void> _ensureRiskImageExists() async {
    if (kIsWeb) return;

    try {
      final riskFile = File(path.join(_appDataDir!, 'risk.png'));

      // Only copy if the file doesn't exist
      if (!await riskFile.exists()) {
        debugPrint('📋 [AppPathsService] Copying bundled risk.png to AppData...');

        // Load the asset
        final assetData = await rootBundle.load('risk.png');
        final bytes = assetData.buffer.asUint8List();

        // Write to AppData directory
        await riskFile.writeAsBytes(bytes);

        debugPrint('✅ [AppPathsService] risk.png copied successfully to: ${riskFile.path}');
      } else {
        debugPrint('✓ [AppPathsService] risk.png already exists at: ${riskFile.path}');
      }
    } catch (e) {
      debugPrint('⚠️  [AppPathsService] Warning: Could not copy risk.png: $e');
      // Don't throw - this is not critical for app functionality
    }
  }

  /// Ensure the service is initialized.
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'AppPathsService not initialized. Call initialize() first.',
      );
    }
  }

  /// Base application data directory.
  /// - Linux: ~/.local/share/penpeeper/
  /// - macOS: ~/Library/Application Support/com.penpeeper.app/
  /// - Windows: %APPDATA%\penpeeper\
  String get appDataDir {
    _ensureInitialized();
    return _appDataDir!;
  }

  /// Database file path.
  String get databasePath {
    _ensureInitialized();
    return path.join(_appDataDir!, 'penpeeper.db');
  }

  /// Uploads directory for project images.
  String get uploadsDir {
    _ensureInitialized();
    return path.join(_appDataDir!, 'uploads');
  }

  /// Get uploads directory for a specific project.
  String getProjectUploadsDir(String projectName) {
    _ensureInitialized();
    return path.join(uploadsDir, projectName);
  }

  /// Themes directory for .penTheme files.
  String get themesDir {
    _ensureInitialized();
    return path.join(_appDataDir!, 'Themes');
  }

  /// Configuration file path.
  String get configPath {
    _ensureInitialized();
    return path.join(_appDataDir!, 'config.json');
  }

  /// Configuration file path.
  String get riskPath {
    _ensureInitialized();
    return path.join(_appDataDir!, 'risk.png');
  }

  /// Debug log file path.
  String get debugLogPath {
    _ensureInitialized();
    return path.join(_appDataDir!, 'debug.logs');
  }

  /// Custom device icons directory.
  String get iconsDir {
    _ensureInitialized();
    return path.join(_appDataDir!, 'IconLocation');
  }

  /// Temporary directory for scan results.
  String get tempScanDir {
    _ensureInitialized();
    return path.join(_tempDir!, 'penpeeper_scans');
  }

  /// System temporary directory.
  String get systemTempDir {
    _ensureInitialized();
    return _tempDir!;
  }

  /// Generate a unique temporary file path for scan results.
  String getTempScanPath(String prefix, String extension) {
    _ensureInitialized();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '${prefix}_$timestamp.$extension';

    // Ensure temp scan directory exists
    final dir = Directory(tempScanDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    return path.join(tempScanDir, filename);
  }

  /// Check if running on Windows Subsystem for Linux (WSL).
  bool get isWSL {
    if (!Platform.isLinux) return false;
    try {
      final result = Process.runSync('uname', ['-r']);
      return result.stdout.toString().toLowerCase().contains('microsoft');
    } catch (_) {
      return false;
    }
  }

  /// For WSL, use /tmp/ for certain operations.
  String getWSLTempPath(String prefix, String extension) {
    if (!isWSL) return getTempScanPath(prefix, extension);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '${prefix}_$timestamp.$extension';
    return '/tmp/$filename';
  }

  /// Get the bundled themes directory (for read-only default themes).
  /// This searches for themes bundled with the application.
  List<String> getBundledThemesPaths() {
    if (kIsWeb) {
      return ['assets/Themes']; // Web uses assets
    }

    final executablePath = Platform.resolvedExecutable;
    final execDir = path.dirname(executablePath);

    return [
      path.join(execDir, 'data', 'flutter_assets', 'Themes'), // Linux package
      path.join(execDir, 'Themes'), // Development/Windows
      path.join(execDir, '..', 'Resources', 'Themes'), // macOS bundle (old)
      path.join(execDir, '..', 'Resources', 'flutter_assets', 'Themes'), // macOS bundle alt (old)
      path.join(execDir, '..', 'Frameworks', 'App.framework', 'Versions', 'A', 'Resources', 'flutter_assets', 'Themes'), // macOS actual location
    ];
  }

  /// Create uploads directory for a specific project if it doesn't exist.
  Future<void> ensureProjectUploadsDir(String projectName) async {
    if (kIsWeb) return;

    final dir = Directory(getProjectUploadsDir(projectName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Delete uploads directory for a specific project.
  Future<void> deleteProjectUploadsDir(String projectName) async {
    if (kIsWeb) return;

    final dir = Directory(getProjectUploadsDir(projectName));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Clean up temporary scan files.
  Future<void> cleanupTempScans() async {
    if (kIsWeb) return;

    try {
      final dir = Directory(tempScanDir);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// For migration: check if old data exists in the current directory.
  Future<bool> hasLegacyData() async {
    if (kIsWeb) return false;

    final currentDir = Directory.current.path;
    final legacyDb = File(path.join(currentDir, 'penpeeper.db'));
    final legacyUploads = Directory(path.join(currentDir, 'uploads'));

    return await legacyDb.exists() || await legacyUploads.exists();
  }

  /// Migrate data from legacy location (current directory) to new location.
  Future<void> migrateLegacyData() async {
    if (kIsWeb) return;

    final currentDir = Directory.current.path;

    // Skip database migration - let app create fresh database
    // Database migration disabled

    // Migrate uploads directory only if it doesn't exist in new location
    final oldUploads = Directory(path.join(currentDir, 'uploads'));
    final newUploads = Directory(uploadsDir);
    if (await oldUploads.exists() && !await newUploads.exists()) {
      await _copyDirectory(oldUploads, newUploads);
      debugPrint('Migrated uploads from ${oldUploads.path} to ${newUploads.path}');
    }

    // Migrate config only if it doesn't exist in new location
    final oldConfig = File(path.join(currentDir, 'config.json'));
    final newConfig = File(configPath);
    if (await oldConfig.exists() && !await newConfig.exists()) {
      await oldConfig.copy(configPath);
      debugPrint('Migrated config from $currentDir to $configPath');
    }

    // Migrate risk only if it doesn't exist in new location
    final oldRisk = File(path.join(currentDir, 'risk.png'));
    final newRisk = File(riskPath);
    if (await oldRisk.exists() && !await newRisk.exists()) {
      await oldRisk.copy(riskPath);
      debugPrint('Migrated risk from $currentDir to $riskPath');
    }

    // Migrate themes only if they don't exist in new location
    final oldThemes = Directory(path.join(currentDir, 'Themes'));
    final newThemes = Directory(themesDir);
    if (await oldThemes.exists() && !await newThemes.exists()) {
      await _copyDirectory(oldThemes, newThemes);
      debugPrint('Migrated themes from ${oldThemes.path} to ${newThemes.path}');
    }
  }

  /// Helper to copy directory contents recursively.
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      if (entity is File) {
        final newPath = path.join(destination.path, path.basename(entity.path));
        await entity.copy(newPath);
      } else if (entity is Directory) {
        final newPath = path.join(destination.path, path.basename(entity.path));
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }
}
