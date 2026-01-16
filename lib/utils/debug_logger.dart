import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:penpeeper/api_database_helper.dart';
import 'package:penpeeper/services/app_paths_service.dart';

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();

  factory DebugLogger() => _instance;

  DebugLogger._internal();

  File? _logFile;
  IOSink? _sink;
  bool _enabled = false;

  // Original handlers
  DebugPrintCallback? _originalDebugPrint;
  FlutterExceptionHandler? _originalOnError;

  bool get isEnabled => _enabled;

  Future<void> enable() async {
    if (_enabled) return;
    
    if (kIsWeb) {
      await _enableWeb();
    } else {
      await _enableNative();
    }
  }

  Future<void> _enableWeb() async {
    try {
      final baseUrl = ApiDatabaseHelper.baseUrl;
      // Tell server to initialize log file (overwrite if exists)
      final response = await http.post(
        Uri.parse('$baseUrl/debug/init'),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _enabled = true;
        _setupInterception();
        _log('Debug logging enabled (Web). Session started: ${DateTime.now()}');
      } else {
        debugPrint('Failed to enable remote debug logging. Server responded: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to enable debug logger (Web): $e');
      _enabled = false;
    }
  }

  Future<void> _enableNative() async {
    try {
      // Initialize file logging (now safe with Hardened Runtime entitlements)
      final logPath = AppPathsService().debugLogPath;
      _logFile = File(logPath);

      // Overwrite existing log file to start fresh for this session
      _sink = _logFile!.openWrite(mode: FileMode.write);

      _enabled = true;
      _setupInterception();

      _log('Debug logging enabled (File: $logPath)');
      _log('Session started: ${DateTime.now()}');

    } catch (e) {
      debugPrint('Failed to enable debug logger: $e');
      _enabled = false;
      _logFile = null;
      _sink = null;
    }
  }

  void _setupInterception() {
    _originalDebugPrint = debugPrint;
    debugPrint = _customDebugPrint;

    _originalOnError = FlutterError.onError;
    FlutterError.onError = _customOnError;
  }

  Future<void> disable() async {
    if (!_enabled) return;

    // Restore handlers
    if (_originalDebugPrint != null) {
      debugPrint = _originalDebugPrint!;
      _originalDebugPrint = null;
    }

    if (_originalOnError != null) {
      FlutterError.onError = _originalOnError;
      _originalOnError = null;
    }

    _log('Debug logging disabled.');
    _log('Session ended: ${DateTime.now()}');

    // Close file sink
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (e) {
      debugPrint('Error closing log file: $e');
    }

    _sink = null;
    _logFile = null;
    _enabled = false;
  }

  void _customDebugPrint(String? message, {int? wrapWidth}) {
    // Write to log, but don't print to console to avoid recursion/duplication
    if (message != null) {
      _log(message, printToConsole: false);
    }

    // Call original
    if (_originalDebugPrint != null) {
      _originalDebugPrint!(message, wrapWidth: wrapWidth);
    } else {
      debugPrintThrottled(message, wrapWidth: wrapWidth);
    }
  }

  void _customOnError(FlutterErrorDetails details) {
    // Write to log, don't print to console
    _log('Flutter Error: ${details.exception}', printToConsole: false);
    if (details.stack != null) {
      _log('Stack trace: ${details.stack}', printToConsole: false);
    }

    // Call original
    if (_originalOnError != null) {
      _originalOnError!(details);
    } else {
      FlutterError.presentError(details);
    }
  }

  /// Public log method used by services
  Future<void> log(String category, String message) async {
    final formattedMessage = '[$category] $message';
    _log(formattedMessage);
  }

  /// Public logError method used by services
  Future<void> logError(String category, String error, [StackTrace? stackTrace]) async {
    _log('[$category] ERROR: $error');
    if (stackTrace != null) {
      _log('[$category] STACK_TRACE: $stackTrace');
    }
    await flush();
  }

  /// Public flush method used by services
  /// Flushes the log file sink to ensure all buffered data is written
  Future<void> flush() async {
    if (!_enabled || _sink == null) return;

    try {
      await _sink!.flush();
    } catch (e) {
      if (_originalDebugPrint != null) {
        _originalDebugPrint!('Error flushing log file: $e');
      } else {
        debugPrintThrottled('Error flushing log file: $e');
      }
    }
  }

  /// Public initialize method (no-op, enable() should be called instead)
  Future<void> initialize() async {
    // No-op - the enable() method handles initialization
  }

  /// Specialized logging methods for backwards compatibility
  Future<void> logScanStart(String scanType, int deviceId, String deviceName, String ip) async {
    await log('SCAN_START', '$scanType - Device $deviceId ($deviceName - $ip)');
  }

  Future<void> logScanComplete(String scanType, int deviceId, String deviceName, bool success) async {
    await log('SCAN_COMPLETE', '$scanType - Device $deviceId ($deviceName) - Success: $success');
  }

  Future<void> logProcessStart(String command, List<String> args, int deviceId) async {
    await log('PROCESS_START', 'Device $deviceId - Command: $command ${args.join(' ')}');
  }

  Future<void> logProcessComplete(String command, int deviceId, int exitCode) async {
    await log('PROCESS_COMPLETE', 'Device $deviceId - Command: $command - Exit Code: $exitCode');
  }

  Future<void> logMemoryUsage() async {
    // No-op for now - memory logging not critical for debug mode
  }

  Future<void> logActiveProcesses(Set<Process> processes) async {
    await log('ACTIVE_PROCESSES', 'Active process count: ${processes.length}');
  }

  Future<void> logTempFiles(Set<String> tempFiles) async {
    await log('TEMP_FILES', 'Temp file count: ${tempFiles.length}');
    for (final file in tempFiles) {
      await log('TEMP_FILES', 'File: $file');
    }
  }

  void _log(String message, {bool printToConsole = true}) {
    // Only log if enabled
    if (!_enabled) return;

    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';

    // ALWAYS write to console (stderr) - provides real-time feedback
    // Use the original debugPrint if available to avoid recursion
    if (printToConsole) {
      if (_originalDebugPrint != null) {
        _originalDebugPrint!(logMessage);
      } else {
        debugPrintThrottled(logMessage);
      }
    }

    // Write to file if sink is available (desktop)
    if (_sink != null) {
      try {
        _sink!.writeln(logMessage);
      } catch (e) {
        // Silently ignore file write errors to avoid recursive logging
      }
    } else if (kIsWeb) {
      // Send to server in web mode
      _logWeb(logMessage);
    }
  }

  void _logWeb(String message) {
    // Fire and forget HTTP request
    final baseUrl = ApiDatabaseHelper.baseUrl;
    http.post(
      Uri.parse('$baseUrl/debug/log'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'message': message}),
    ).catchError((e) {
      // Avoid recursive logging if logging fails
      // Just ignore or print to console (which will be intercepted, so be careful!)
      if (_originalDebugPrint != null) {
        _originalDebugPrint!('Failed to send remote log: $e');
      }
    });
  }
}
