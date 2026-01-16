import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:penpeeper/utils/debug_logger.dart';
import 'package:penpeeper/services/config_service.dart';
import 'package:penpeeper/services/app_paths_service.dart';

class ProcessMonitor {
  static final ProcessMonitor _instance = ProcessMonitor._internal();
  factory ProcessMonitor() => _instance;
  ProcessMonitor._internal();

  final _logger = DebugLogger();
  Timer? _monitorTimer;
  bool _isMonitoring = false;

  Future<void> startMonitoring({Duration interval = const Duration(seconds: 30)}) async {
    // Skip process monitoring entirely in Web mode
    if (kIsWeb) {
      return;
    }

    if (_isMonitoring) return;

    _isMonitoring = true;
    await _logger.log('PROCESS_MONITOR', 'Starting process monitoring with ${interval.inSeconds}s interval');

    _monitorTimer = Timer.periodic(interval, (timer) async {
      await _logSystemResources();
    });
  }

  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;
    await _logger.log('PROCESS_MONITOR', 'Process monitoring stopped');
  }

  Future<void> _logSystemResources() async {
    // Only run system resource monitoring on Windows
    // These commands use Windows-specific tools (tasklist, dir) that don't exist on macOS/Linux
    if (!ConfigService.isWindows) {
      return;
    }

    try {
      // Get memory usage for current process
      await _logMemoryUsage();

      // Get system-wide process count
      await _logProcessCount();

      // Check for temp files
      await _logTempFileCount();

      // Check disk space
      await _logDiskSpace();

    } catch (e) {
      await _logger.logError('PROCESS_MONITOR', 'Error monitoring resources: $e');
    }
  }

  Future<void> _logMemoryUsage() async {
    try {
      final result = await Process.run('tasklist', [
        '/FI', 'IMAGENAME eq flutter.exe',
        '/FO', 'CSV'
      ]);
      
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.contains('flutter.exe')) {
            final parts = line.split(',');
            if (parts.length >= 5) {
              final pid = parts[1].replaceAll('"', '');
              final memory = parts[4].replaceAll('"', '').replaceAll(' K', '');
              await _logger.log('MEMORY_USAGE', 'Flutter PID $pid: ${memory}KB');
            }
          }
        }
      }
    } catch (e) {
      await _logger.logError('MEMORY_USAGE', 'Failed to get memory usage: $e');
    }
  }

  Future<void> _logProcessCount() async {
    try {
      final result = await Process.run('tasklist', ['/FO', 'CSV']);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        final processCount = lines.where((line) => line.contains('.exe')).length;
        await _logger.log('PROCESS_COUNT', 'Total system processes: $processCount');
      }
    } catch (e) {
      await _logger.logError('PROCESS_COUNT', 'Failed to get process count: $e');
    }
  }

  Future<void> _logTempFileCount() async {
    try {
      final scanTempDir = Directory(AppPathsService().tempScanDir);
      int tempFiles = 0;
      if (await scanTempDir.exists()) {
        tempFiles = scanTempDir.listSync().where((f) =>
          f.path.contains('temp_scan_') || f.path.contains('temp_')).length;
      }

      final systemTempDir = Directory(AppPathsService().systemTempDir);
      int tempDirFiles = 0;
      if (await systemTempDir.exists()) {
        tempDirFiles = systemTempDir.listSync().length;
      }

      await _logger.log('TEMP_FILES', 'Scan temp files: $tempFiles, System temp files: $tempDirFiles');
    } catch (e) {
      await _logger.logError('TEMP_FILES', 'Failed to count temp files: $e');
    }
  }

  Future<void> _logDiskSpace() async {
    try {
      final result = await Process.run('dir', ['C:\\', '/-c']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.contains('bytes free')) {
            await _logger.log('DISK_SPACE', 'C: drive - $line');
            break;
          }
        }
      }
    } catch (e) {
      // Silently ignore disk space errors to reduce log spam
    }
  }

  Future<void> logCriticalEvent(String event) async {
    await _logger.log('CRITICAL_EVENT', event);
    await _logSystemResources(); // Log resources immediately on critical events
  }
}