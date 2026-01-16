import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:penpeeper/models.dart';
import 'package:penpeeper/database_helper.dart';
import 'package:penpeeper/repositories/scan_repository.dart' as scan_repo;
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/metadata_repository.dart';
import 'package:penpeeper/repositories/settings_repository.dart';
import 'package:penpeeper/services/nmap_scan_service.dart';
import 'package:penpeeper/services/nikto_scan_service.dart';
import 'package:penpeeper/services/searchsploit_scan_service.dart';
import 'package:penpeeper/services/whatweb_scan_service.dart';
import 'package:penpeeper/services/ffuf_scan_service.dart';
import 'package:penpeeper/services/enum4linux_scan_service.dart';
import 'package:penpeeper/services/snmp_scan_service.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/services/scan_service.dart';
import 'package:penpeeper/services/config_service.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'package:penpeeper/utils/debug_logger.dart';
import 'package:penpeeper/services/process_monitor.dart';
import 'package:penpeeper/services/scan_status_service.dart';
import 'package:penpeeper/api_database_helper.dart';

class ScanOrchestrator {
  final nmapService = NmapScanService();
  final niktoService = NiktoScanService();
  final searchsploitService = SearchsploitScanService();
  final whatwebService = WhatwebScanService();
  final ffufService = FfufScanService();
  final enum4linuxService = Enum4linuxScanService();
  final snmpService = SnmpScanService();
  final deviceRepo = DeviceRepository();
  final scanRepo = scan_repo.ScanRepository();
  final configService = ConfigService();
  final _metadataRepo = MetadataRepository();
  final _logger = DebugLogger();
  final _processMonitor = ProcessMonitor();
  final _settingsRepo = SettingsRepository();

  final List<String> tempFiles = [];
  final Map<String, bool> _cancelRequested = {};

  // Database write lock to prevent concurrent writes
  Future<void>? _databaseWriteLock;

  /// Serialize database write operations to prevent lock contention
  Future<T> _withDatabaseLock<T>(Future<T> Function() operation) async {
    await _logger.log('DATABASE_LOCK', 'Attempting to acquire database lock...');

    // Wait for any pending write operation to complete with timeout
    int waitCount = 0;
    while (_databaseWriteLock != null) {
      waitCount++;
      if (waitCount > 100) {
        await _logger.logError('DATABASE_LOCK', 'Lock acquisition timed out after 100 iterations');
        throw Exception('Database lock acquisition timed out - possible deadlock');
      }
      await _logger.log('DATABASE_LOCK', 'Waiting for lock (iteration $waitCount)...');

      try {
        await _databaseWriteLock!.timeout(Duration(seconds: 5));
      } catch (e) {
        await _logger.logError('DATABASE_LOCK', 'Lock wait timed out: $e');
        // Force release the stale lock
        _databaseWriteLock = null;
        break;
      }
    }

    await _logger.log('DATABASE_LOCK', 'Lock acquired, creating new lock...');

    // Create a new lock for this operation
    final completer = Completer<void>();
    _databaseWriteLock = completer.future;

    try {
      await _logger.log('DATABASE_LOCK', 'Executing locked operation...');

      // Execute the operation
      final result = await operation();

      await _logger.log('DATABASE_LOCK', 'Operation completed successfully');

      return result;
    } catch (e, stack) {
      await _logger.logError('DATABASE_LOCK', 'Operation failed: $e', stack);
      rethrow;
    } finally {
      // Release the lock
      await _logger.log('DATABASE_LOCK', 'Releasing lock...');

      completer.complete();
      _databaseWriteLock = null;

      await _logger.log('DATABASE_LOCK', 'Lock released');
    }
  }

  void requestCancel(String scanType) {
    _cancelRequested[scanType.toUpperCase()] = true;
  }

  void resetCancel(String scanType) {
    _cancelRequested[scanType.toUpperCase()] = false;
  }

  void resetAllCancels() {
    _cancelRequested.clear();
  }

  bool _isCancelRequested(String scanType) {
    return _cancelRequested[scanType.toUpperCase()] ?? false;
  }

  Future<void> cleanup() async {
    await _logger.log(
      'CLEANUP',
      'Starting cleanup - ${tempFiles.length} temp files',
    );

    // Only kill processes if cancel was requested for that scan type
    if (_isCancelRequested('NMAP')) {
      await nmapService.killAllProcesses();
    }
    if (_isCancelRequested('SNMP')) {
      await snmpService.killAllProcesses();
    }

    // Clean up temp files
    for (final path in tempFiles) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          await _logger.log('CLEANUP', 'Deleted temp file: $path');
        }
      } catch (e) {
        await _logger.logError(
          'CLEANUP',
          'Failed to delete temp file $path: $e',
        );
      }
    }
    tempFiles.clear();

    await _logger.log('CLEANUP', 'Cleanup completed');
  }

  // Unified Nmap scan - works for single device or multiple devices
  Future<bool> runNmapScan(
    Device device,
    int projectId, {
    bool replaceExisting = true,
  }) async {
    return await _runCompleteScan(device, projectId, replaceExisting);
  }

  // New helper method that ensures complete scan lifecycle
  Future<bool> _runCompleteScan(
    Device device,
    int projectId,
    bool replaceExisting,
  ) async {
    await _logger.logScanStart(
      'NMAP',
      device.id,
      device.name,
      device.ipAddress,
    );

    await _logger.log('COMPLETE_SCAN', 'About to log memory usage...');
    await _logger.logMemoryUsage();

    await _logger.log('COMPLETE_SCAN', 'Memory usage logged, entering try block...');

    try {
      await _logger.log(
        'COMPLETE_SCAN',
        'Starting complete scan for device ${device.id} (${device.name})',
      );

      // Step 1: Delete existing scans if needed
      if (replaceExisting) {
        await _logger.log('COMPLETE_SCAN', 'Device ${device.id} - Checking for existing scans to delete...');
        final existingScans = await scanRepo.getScans(device.id);
        await _logger.log('COMPLETE_SCAN', 'Device ${device.id} - Found ${existingScans.length} existing scans');
        for (final scan in existingScans) {
          if (scan.scanType == 'AUTO NMAP') {
            await _logger.log('COMPLETE_SCAN', 'Device ${device.id} - Deleting existing scan ${scan.id}');
            await scanRepo.deleteScan(scan.id);
          }
        }
        await _logger.log('COMPLETE_SCAN', 'Device ${device.id} - Finished deleting existing scans');
      }

      // Step 2: Run nmap scan and get XML
      final uniqueId = '${device.id}_${DateTime.now().millisecondsSinceEpoch}';
      await _logger.log(
        'COMPLETE_SCAN',
        'Device ${device.id} - Running nmap scan with uniqueId: $uniqueId',
      );

      await _logger.log('COMPLETE_SCAN', 'Device ${device.id} - About to call nmapService.runDeviceScan...');

      final scanResult = await nmapService.runDeviceScan(
        device.ipAddress,
        uniqueId,
      );

      await _logger.log('COMPLETE_SCAN', 'Device ${device.id} - nmapService.runDeviceScan completed, result length: ${scanResult.length}');

      // Only proceed if we have valid scan results
      if (scanResult.trim().isEmpty) {
        await _logger.logError(
          'COMPLETE_SCAN',
          'Device ${device.id} - Empty scan result, skipping processing',
        );
        await _logger.logScanComplete('NMAP', device.id, device.name, false);
        return false;
      }

      await _logger.log(
        'COMPLETE_SCAN',
        'Device ${device.id} - Scan completed, XML length: ${scanResult.length}',
      );

      // Step 3: Insert scan to database
      await _logger.log('COMPLETE_SCAN', 'Device ${device.id} - About to insert scan to database...');
      await scanRepo.insertScan(device.id, 'AUTO NMAP', scanResult);
      await _logger.log(
        'COMPLETE_SCAN',
        'Device ${device.id} - Scan inserted to database',
      );

      // Step 4: Process XML in background (non-blocking) only if not cancelled
      // This allows the scan pool to immediately start the next scan
      await _logger.log('COMPLETE_SCAN', 'Device ${device.id} - Checking if scan was cancelled...');
      if (!_isCancelRequested('NMAP')) {
        await _logger.log('COMPLETE_SCAN', 'Device ${device.id} - Starting background processing...');
        _processResultsInBackground(device.id, device.name, projectId, scanResult);
        await _logger.log('COMPLETE_SCAN', 'Device ${device.id} - Background processing initiated');
      }

      await _logger.log('COMPLETE_SCAN', 'Device ${device.id} - About to log scan complete...');
      await _logger.logScanComplete('NMAP', device.id, device.name, true);
      await _logger.log('COMPLETE_SCAN', 'Device ${device.id} - Returning true (success)');
      return true;
    } catch (e, stackTrace) {
      await _logger.logError(
        'COMPLETE_SCAN',
        'Device ${device.id} (${device.name}) failed: $e',
        stackTrace,
      );
      await _logger.logScanComplete('NMAP', device.id, device.name, false);
      return false;
    }
  }

  /// Processes scan results in background without blocking scan pool
  /// This allows the next scan to start immediately while processing continues
  void _processResultsInBackground(
    int deviceId,
    String deviceName,
    int projectId,
    String xmlContent,
  ) {
    // Fire and forget - process asynchronously
    // IMPORTANT: No flush() calls in this synchronous method to avoid crashes on macOS packaged apps
    // Logs will be queued and written asynchronously by DebugLogger
    _logger.log('BACKGROUND_PROCESS', 'Device $deviceId - Starting background processing for $deviceName');

    try {
      // Call async processing - this returns immediately with a Future
      final future = _processResultsAsync(deviceId, deviceName, projectId, xmlContent);

      // Attach handlers without blocking
      future.then((_) {
        _logger.log('SCAN_PROCESSING', 'Device $deviceId processing completed successfully');
      }).catchError((error, stackTrace) {
        // logError flushes automatically, but in a fire-and-forget manner
        _logger.logError('SCAN_PROCESSING', 'Device $deviceId ($deviceName) processing failed: $error', stackTrace);
      });

      _logger.log('BACKGROUND_PROCESS', 'Device $deviceId - Background processing initiated');
    } catch (e, stack) {
      // Synchronous error - log but don't flush
      _logger.log('BACKGROUND_PROCESS', 'Device $deviceId - ERROR in background processing setup: $e');
      _logger.log('BACKGROUND_PROCESS', 'Stack trace: $stack');
    }
  }

  /// Async processing of scan results
  Future<void> _processResultsAsync(
    int deviceId,
    String deviceName,
    int projectId,
    String xmlContent,
  ) async {
    try {
      await _logger.log('ASYNC_PROCESS', 'Device $deviceId - Starting processing for $deviceName');

      // Check if scan was cancelled before processing
      if (_isCancelRequested('NMAP')) {
        await _logger.log('SCAN_PROCESSING', 'Device $deviceId skipped - scan cancelled');
        return;
      }

      // Process XML and update cache with database lock
      final processed = await _withDatabaseLock(() async {
        return await nmapService.processNmapResults(
          deviceId,
          projectId,
          xmlContent,
        );
      });

      await _logger.log('SCAN_PROCESSING', 'Device $deviceId - Processing result: $processed');
    } catch (e, stackTrace) {
      // logError automatically flushes
      await _logger.logError('SCAN_PROCESSING', 'Device $deviceId ($deviceName) processing error: $e', stackTrace);
      rethrow;
    }
  }

  /// Processes SNMP results in background without blocking scan pool
  void _processSnmpResultsInBackground(
    int deviceId,
    String deviceName,
    int projectId,
    String xmlContent,
  ) {
    _logger.log('SNMP_PROCESSING', 'Device $deviceId - Starting background processing for $deviceName');

    _processSnmpResultsAsync(deviceId, deviceName, projectId, xmlContent).then((_) {
      _logger.log('SNMP_PROCESSING', 'Device $deviceId processing completed successfully');
    }).catchError((error, stackTrace) {
      _logger.logError('SNMP_PROCESSING', 'Device $deviceId ($deviceName) processing failed: $error', stackTrace);
    });
  }

  Future<void> _processSnmpResultsAsync(
    int deviceId,
    String deviceName,
    int projectId,
    String xmlContent,
  ) async {
    try {
      // Check if scan was cancelled before processing
      if (_isCancelRequested('SNMP')) {
        await _logger.log('SNMP_PROCESSING', 'Device $deviceId skipped - scan cancelled');
        return;
      }

      await _logger.log('SNMP_PROCESSING', 'Device $deviceId - Processing SNMP results');

      final processed = await _withDatabaseLock(() async {
        return await snmpService.processSnmpResults(
          deviceId,
          projectId,
          xmlContent,
          DatabaseHelper(),
        );
      });

      await _logger.log('SNMP_PROCESSING', 'Device $deviceId - Processing completed: $processed');
    } catch (e, stackTrace) {
      await _logger.logError('SNMP_PROCESSING', 'Device $deviceId processing error: $e', stackTrace);
      rethrow;
    }
  }

  /// Processes SearchSploit results in background without blocking scan pool
  void _processSearchsploitResultsInBackground(int deviceId, String result) {
    _logger.log('SEARCHSPLOIT_PROCESSING', 'Device $deviceId - Starting background processing');

    _processSearchsploitResultsAsync(deviceId, result).then((_) {
      _logger.log('SEARCHSPLOIT_PROCESSING', 'Device $deviceId processing completed');
    }).catchError((error, stackTrace) {
      _logger.logError('SEARCHSPLOIT_PROCESSING', 'Device $deviceId processing failed: $error', stackTrace);
    });
  }

  Future<void> _processSearchsploitResultsAsync(int deviceId, String result) async {
    try {
      // Check if scan was cancelled before processing
      if (_isCancelRequested('SEARCHSPLOIT')) {
        await _logger.log('SEARCHSPLOIT_PROCESSING', 'Device $deviceId skipped - scan cancelled');
        return;
      }

      await _withDatabaseLock(() async {
        await searchsploitService.parseAndStoreResults(deviceId, result);
        final cache = ProjectDataCache();
        cache.addDeviceToScanType('SearchSploit', deviceId);
      });

    } catch (e, stackTrace) {
      await _logger.logError('SEARCHSPLOIT_PROCESSING', 'Device $deviceId error: $e', stackTrace);
      rethrow;
    }
  }

  /// Processes WhatWeb results in background without blocking scan pool
  void _processWhatWebResultsInBackground(int deviceId, String result) {
    _logger.log('WHATWEB_PROCESSING', 'Device $deviceId - Starting background processing');

    _processWhatWebResultsAsync(deviceId, result).then((_) {
      _logger.log('WHATWEB_PROCESSING', 'Device $deviceId processing completed');
    }).catchError((error, stackTrace) {
      _logger.logError('WHATWEB_PROCESSING', 'Device $deviceId processing failed: $error', stackTrace);
    });
  }

  Future<void> _processWhatWebResultsAsync(int deviceId, String result) async {
    try {
      // Check if scan was cancelled before processing
      if (_isCancelRequested('WHATWEB')) {
        await _logger.log('WHATWEB_PROCESSING', 'Device $deviceId skipped - scan cancelled');
        return;
      }

      await _withDatabaseLock(() async {
        await whatwebService.parseAndStoreResults(deviceId, result);
      });

    } catch (e, stackTrace) {
      await _logger.logError('WHATWEB_PROCESSING', 'Device $deviceId error: $e', stackTrace);
      rethrow;
    }
  }

  /// Processes FFUF results in background without blocking scan pool
  void _processFfufResultsInBackground(int deviceId, String result) {
    _logger.log('FFUF_PROCESSING', 'Device $deviceId - Starting background processing');

    _processFfufResultsAsync(deviceId, result).then((_) {
      _logger.log('FFUF_PROCESSING', 'Device $deviceId processing completed');
    }).catchError((error, stackTrace) {
      _logger.logError('FFUF_PROCESSING', 'Device $deviceId processing failed: $error', stackTrace);
    });
  }

  Future<void> _processFfufResultsAsync(int deviceId, String result) async {
    try {
      // Check if scan was cancelled before processing
      if (_isCancelRequested('FFUF')) {
        await _logger.log('FFUF_PROCESSING', 'Device $deviceId skipped - scan cancelled');
        return;
      }

      await _withDatabaseLock(() async {
        await ffufService.parseAndStoreResults(deviceId, result);
      });

    } catch (e, stackTrace) {
      await _logger.logError('FFUF_PROCESSING', 'Device $deviceId error: $e', stackTrace);
      rethrow;
    }
  }

  /// Processes Enum4Linux results in background without blocking scan pool
  void _processEnum4linuxResultsInBackground(int deviceId, String result) {
    _logger.log('ENUM4LINUX_PROCESSING', 'Device $deviceId - Starting background processing');

    _processEnum4linuxResultsAsync(deviceId, result).then((_) {
      _logger.log('ENUM4LINUX_PROCESSING', 'Device $deviceId processing completed');
    }).catchError((error, stackTrace) {
      _logger.logError('ENUM4LINUX_PROCESSING', 'Device $deviceId processing failed: $error', stackTrace);
    });
  }

  Future<void> _processEnum4linuxResultsAsync(int deviceId, String result) async {
    try {
      // Check if scan was cancelled before processing
      if (_isCancelRequested('ENUM4LINUX')) {
        await _logger.log('ENUM4LINUX_PROCESSING', 'Device $deviceId skipped - scan cancelled');
        return;
      }

      await _withDatabaseLock(() async {
        await enum4linuxService.parseAndStoreResults(deviceId, result);
      });

    } catch (e, stackTrace) {
      await _logger.logError('ENUM4LINUX_PROCESSING', 'Device $deviceId error: $e', stackTrace);
      rethrow;
    }
  }

  /// Runs a single scan in the pool with timeout and progress tracking
  Future<bool> _runPooledScan(
    Device device,
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
    int totalDevices,
    Function()? onScanComplete,
  ) async {
    await _logger.log('POOLED_SCAN', 'Starting scan for device ${device.id} (${device.name})');

    try {
      await _logger.log('POOLED_SCAN', 'Calling _runCompleteScan for device ${device.id}');
      final success = await _runCompleteScan(device, projectId, replaceExisting).timeout(
        Duration(minutes: 20), // 20 minute timeout per device
        onTimeout: () {
          _logger.logError(
            'POOL_SCAN',
            'Device ${device.id} (${device.name}) timed out after 20 minutes',
          );
          return false;
        },
      );

      if (success) {
        await _logger.log(
          'POOL_SCAN',
          'Device ${device.id} (${device.name}) completed successfully',
        );
        onScanComplete?.call();
      } else {
        await _logger.log(
          'POOL_SCAN',
          'Device ${device.id} (${device.name}) failed',
        );
      }

      return success;
    } catch (e, stackTrace) {
      await _logger.logError(
        'POOL_SCAN',
        'Device ${device.id} (${device.name}) error: $e',
        stackTrace,
      );
      return false;
    }
  }

  // Unified Nikto scan - works for single device or multiple devices
  // Accepts either a target map with {id, ip_address, ports} or builds it from device metadata
  Future<bool> runNiktoScan(
    Map<String, dynamic> target, {
    bool replaceExisting = true,
  }) async {
    try {
      final ip = target['ip_address'];
      final ports = target['ports'];
      final deviceId = target['id'];

      if (replaceExisting) {
        await scanRepo.deleteNiktoAutoScans(deviceId);
      }

      final portList = ports.split(',').map((p) => p.trim()).toList();
      final sslPorts = portList
          .where((p) => p == '443' || p == '8443')
          .toList();
      final nonSslPorts = portList
          .where((p) => p != '443' && p != '8443')
          .toList();

      String combinedResult = '';

      if (nonSslPorts.isNotEmpty) {
        final result = await niktoService.runNiktoScan(
          ip,
          nonSslPorts.join(','),
          false,
        );
        combinedResult += result;
      }

      if (sslPorts.isNotEmpty) {
        final result = await niktoService.runNiktoScan(
          ip,
          sslPorts.join(','),
          true,
        );
        if (combinedResult.isNotEmpty) {
          combinedResult += '\n\n<!-- SSL SCAN RESULTS -->\n\n$result';
        } else {
          combinedResult = result;
        }
      }

      await scanRepo.insertScan(deviceId, 'NIKTO AUTO', combinedResult);

      // Parse and store Nikto findings
      if (combinedResult.isNotEmpty) {
        try {
          await _withDatabaseLock(() async {
            await niktoService.parseAndStoreResults(deviceId, combinedResult);
          });
        } catch (e) {
          debugPrint('Failed to parse Nikto results: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Nikto scan failed: $e');
      return false;
    }
  }

  // Unified Searchsploit scan - works for single device or multiple devices
  Future<bool> runSearchsploitScan(
    Device device, {
    bool replaceExisting = true,
  }) async {
    try {
      if (replaceExisting) {
        await scanRepo.deleteSearchsploitAutoScans(device.id);
      }

      final scans = await scanRepo.getScans(device.id);
      final nmapScan = scans.firstWhere(
        (scan) => scan.scanType == 'AUTO NMAP',
        orElse: () => throw Exception('No AUTO NMAP scan found'),
      );

      final result = await searchsploitService.runSearchsploitScan(
        nmapScan.result,
      );
      await scanRepo.insertScan(device.id, 'AUTO SEARCHSPLOIT', result);

      // Process results in background (non-blocking) only if not cancelled
      if (!_isCancelRequested('SEARCHSPLOIT')) {
        _processSearchsploitResultsInBackground(device.id, result);
      }

      return true;
    } catch (e) {
      debugPrint('Searchsploit scan failed: $e');
      return false;
    }
  }

  // Unified WhatWeb scan - works for single device or multiple devices
  Future<bool> runWhatwebScan(
    Device device, {
    bool replaceExisting = true,
  }) async {
    try {
      if (replaceExisting) {
        await scanRepo.deleteWhatwebAutoScans(device.id);
      }

      final scans = await scanRepo.getScans(device.id);
      final nmapScan = scans.firstWhere(
        (scan) => scan.scanType == 'AUTO NMAP',
        orElse: () => throw Exception('No AUTO NMAP scan found'),
      );

      final httpPorts = await whatwebService.parseNmapForHttpPorts(
        nmapScan.result,
        device.ipAddress,
      );

      if (httpPorts.isEmpty) {
        return true;
      }

      String combinedResult = '';
      int failedCount = 0;
      for (final portInfo in httpPorts) {
        try {
          final result = await whatwebService.runWhatwebScan(portInfo);
          if (combinedResult.isNotEmpty) {
            combinedResult += '\n\n';
          }
          combinedResult += result;
        } catch (e) {
          failedCount++;
          debugPrint('WhatWeb scan failed for $portInfo: $e');
        }
      }

      if (combinedResult.isNotEmpty) {
        await scanRepo.insertScan(device.id, 'AUTO WHATWEB', combinedResult);

        // Process results in background (non-blocking) only if not cancelled
        if (!_isCancelRequested('WHATWEB')) {
          _processWhatWebResultsInBackground(device.id, combinedResult);
        }
      } else if (failedCount == httpPorts.length) {
        // All scans failed - throw the last error
        throw Exception('All WhatWeb scans failed. Check that WhatWeb is installed correctly and the target URLs are accessible.');
      }

      return true;
    } catch (e) {
      debugPrint('WhatWeb scan failed: $e');
      return false;
    }
  }

  // Unified FFUF scan - works for single device or multiple devices
  // Accepts either a target map with {id, ip_address, ports} or builds it from device metadata
  Future<bool> runFfufScan(
    Map<String, dynamic> target, {
    bool replaceExisting = true,
  }) async {
    try {
      final ip = target['ip_address'];
      final ports = target['ports'];
      final deviceId = target['id'];

      if (replaceExisting) {
        await scanRepo.deleteFfufAutoScans(deviceId);
      }

      final portList = ports.split(',').map((p) => p.trim()).toList();
      String combinedResult = '';

      for (final port in portList) {
        try {
          final result = await ffufService.runFfufScan(ip, port);
          if (combinedResult.isNotEmpty) {
            combinedResult += '\n\n<!-- PORT $port SCAN RESULTS -->\n\n$result';
          } else {
            combinedResult = result;
          }
        } catch (e) {
          debugPrint('FFUF scan failed for $ip:$port - $e');
        }
      }

      if (combinedResult.isNotEmpty) {
        await scanRepo.insertScan(deviceId, 'AUTO FUZZER', combinedResult);

        // Process results in background (non-blocking) only if not cancelled
        if (!_isCancelRequested('FFUF')) {
          _processFfufResultsInBackground(deviceId, combinedResult);
        }
      }

      return true;
    } catch (e) {
      debugPrint('FFUF scan failed: $e');
      return false;
    }
  }

  // Unified Enum4linux scan - works for single device or multiple devices
  // Accepts either a target map with {id, ip_address} or builds it from device metadata
  Future<bool> runEnum4linuxScan(
    Map<String, dynamic> target, {
    bool replaceExisting = true,
  }) async {
    try {
      final ip = target['ip_address'];
      final deviceId = target['id'];

      if (replaceExisting) {
        await scanRepo.deleteSambaLdapAutoScans(deviceId);
      }

      final result = await enum4linuxService.runEnum4linuxScan(ip);
      await scanRepo.insertScan(deviceId, 'AUTO SAMBA/LDAP', result);

      // Process results in background (non-blocking) only if not cancelled
      if (!_isCancelRequested('ENUM4LINUX')) {
        _processEnum4linuxResultsInBackground(deviceId, result);
      }

      return true;
    } catch (e) {
      debugPrint('enum4linux-ng scan failed: $e');
      return false;
    }
  }

  // Host Discovery
  Future<String> runHostDiscoveryScan(String target) async {
    return await ScanService.runNmapScan(target);
  }

  Future<List<Map<String, String>>> processHostDiscoveryResults(
    String jsonResults,
    List<Device> existingDevices,
  ) async {
    final data = json.decode(jsonResults);
    final hosts = data['hosts'] as List;
    final existingIps = existingDevices.map((d) => d.ipAddress).toSet();

    final newHosts = <Map<String, String>>[];
    for (final host in hosts) {
      final ip = host['ip'] as String;
      if (!existingIps.contains(ip)) {
        newHosts.add({'ip': ip, 'hostname': host['hostname'] as String? ?? ip});
      }
    }
    return newHosts;
  }

  Future<void> addDiscoveredHosts(
    int projectId,
    List<Map<String, String>> hosts,
  ) async {
    for (final host in hosts) {
      await deviceRepo.insertDevice(projectId, host['hostname']!, host['ip']!);
    }
  }

  // Automated Device Scans with pool-based concurrency
  Future<Map<String, dynamic>> runAutomatedDeviceScans(
    int projectId,
    List<Device> devices,
    bool replaceExisting,
    Function(String)? onProgress, {
    int? concurrency,
    Function()? onScanComplete,
  }) async {
    await _logger.log('SCAN_ORCHESTRATOR', 'Entered runAutomatedDeviceScans - ${devices.length} devices');
    if (kIsWeb) {
      try {
        // Start the scan
        final response = await http.post(
          Uri.parse('${ApiDatabaseHelper.baseUrl}/projects/$projectId/nmap-scans'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'replaceExisting': replaceExisting}),
        );
        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          final taskId = result['taskId'] as String;
          final total = result['total'] as int;

          // Poll for progress
          return await _pollScanProgress(projectId, taskId, 'Nmap', total, onProgress);
        }
        return {'completed': 0, 'failed': 0, 'total': 0};
      } catch (e) {
        return {'completed': 0, 'failed': 0, 'total': 0};
      }
    }

    // Load concurrency from settings if not explicitly provided
    final effectiveConcurrency = concurrency ??
        await _settingsRepo.getIntSetting('concurrent_scan_count', 3);

    await _logger.log(
      'POOL_SCAN',
      'Starting pool scan - ${devices.length} devices, concurrency: $effectiveConcurrency',
    );

    await _logger.log('POOL_SCAN', 'About to start process monitoring...');
    await _processMonitor.startMonitoring(interval: Duration(seconds: 15));

    await _logger.log('POOL_SCAN', 'Process monitoring started, logging critical event...');
    await _processMonitor.logCriticalEvent(
      'POOL_SCAN_START - ${devices.length} devices',
    );

    await _logger.log('POOL_SCAN', 'About to call ScanStatusService().startScan...');
    // Start tracking in ScanStatusService
    final statusId = ScanStatusService().startScan(
      scanType: 'NMAP',
      totalDevices: devices.length,
    );

    await _logger.log('POOL_SCAN', 'ScanStatusService startScan completed, statusId: $statusId');

    int completed = 0;
    int failed = 0;
    int deviceIndex = 0;
    final activeScans = <int, Future<bool>>{};  // deviceId -> Future
    final activeDevices = <int, Device>{};  // deviceId -> Device

    await _logger.log('POOL_SCAN', 'Entering main scan loop try block...');

    try {
      await _logger.log('POOL_SCAN', 'In try block, about to start while loop...');
      // Pool pattern: maintain exactly 'concurrency' active scans
      while (deviceIndex < devices.length || activeScans.isNotEmpty) {
        try {
          if (_isCancelRequested('NMAP')) break;

          await _logger.log('POOL_SCAN', 'Loop iteration - deviceIndex: $deviceIndex, activeScans: ${activeScans.length}');

        // Fill the pool up to concurrency limit
        while (activeScans.length < effectiveConcurrency &&
               deviceIndex < devices.length &&
               !_isCancelRequested('NMAP')) {
          final device = devices[deviceIndex++];

          await _logger.log('POOL_SCAN', 'Starting scan for device ${device.id} (${device.name}, ${device.ipAddress})');

          final scanFuture = _runPooledScan(
            device,
            projectId,
            replaceExisting,
            onProgress,
            devices.length,
            onScanComplete,
          );

          activeScans[device.id] = scanFuture;
          activeDevices[device.id] = device;

          await _logger.log('POOL_SCAN', 'Device ${device.id} added to active scans (${activeScans.length} active)');

          // Update status with currently active devices
          ScanStatusService().updateScanProgress(
            id: statusId,
            activeDevices: activeDevices.values.map((d) => d.ipAddress).toList(),
            completed: completed,
          );

          onProgress?.call(
            'Nmap: Scanning ${activeDevices.values.map((d) => d.ipAddress).join(', ')} ($completed/${devices.length} completed)',
          );
        }

        // If there are active scans, wait for any one to complete
        if (activeScans.isNotEmpty) {
          await _logger.log('POOL_SCAN', 'Waiting for scans (${activeScans.length} active)...');

          // Wait for any scan to complete and identify which one
          final completedEntry = await Future.any(
            activeScans.entries.map((entry) =>
              entry.value.then((success) => MapEntry(entry.key, success))
            ),
          );

          final deviceId = completedEntry.key;
          final success = completedEntry.value;

          // Update counters
          if (success) {
            completed++;
          } else {
            failed++;
          }

          await _logger.log('POOL_SCAN', 'Device $deviceId completed (${success ? "success" : "failed"}): $completed/${devices.length} done');

          // Remove from active scans
          activeScans.remove(deviceId);
          activeDevices.remove(deviceId);

          // Update status
          ScanStatusService().updateScanProgress(
            id: statusId,
            activeDevices: activeDevices.values.map((d) => d.ipAddress).toList(),
            completed: completed,
          );

          // Update progress
          onProgress?.call(
            activeDevices.isNotEmpty
                ? 'Nmap: Scanning ${activeDevices.values.map((d) => d.ipAddress).join(', ')} ($completed/${devices.length} completed)'
                : 'Nmap: $completed/${devices.length} completed',
          );
        }
        } catch (loopError, loopStack) {
          await _logger.logError('POOL_SCAN', 'Error in scan loop iteration: $loopError', loopStack);
          // Continue to next iteration
        }
      }

      await _logger.log('POOL_SCAN', 'Exited main while loop - all scans complete');

      if (_isCancelRequested('NMAP')) {
        await _logger.log('POOL_SCAN', 'Scan was cancelled, cleaning up...');
        ScanStatusService().completeScan(statusId);
        await _logger.log('POOL_SCAN', 'Nmap scan cancelled by user');
        onProgress?.call('Nmap scan cancelled');
        await nmapService.killAllProcesses();
      }

      await _logger.log('POOL_SCAN', 'Starting final cleanup...');
      // Final cleanup
      await _cleanupTempFiles();

      await _logger.log('POOL_SCAN', 'Completing scan status...');
      ScanStatusService().completeScan(statusId);

      await _logger.log(
        'POOL_SCAN',
        'Pool scan completed - $completed successful, $failed failed',
      );
      await _processMonitor.logCriticalEvent(
        'POOL_SCAN_COMPLETE - $completed/$failed/${devices.length}',
      );
      return {
        'completed': completed,
        'failed': failed,
        'total': devices.length,
      };
    } catch (e, stackTrace) {
      ScanStatusService().completeScan(statusId);
      await _logger.logError('POOL_SCAN', 'Pool scan error: $e', stackTrace);
      await _processMonitor.logCriticalEvent('BATCH_SCAN_ERROR - $e');
      return {
        'completed': completed,
        'failed': failed,
        'total': devices.length,
      };
    } finally {
      // Final cleanup
      await _cleanupTempFiles();
      await _processMonitor.stopMonitoring();
      resetCancel('NMAP');
    }
  }

  Future<void> _cleanupTempFiles() async {
    try {
      // Clean up any orphaned temp files from temp directory
      final tempDir = Directory(AppPathsService().tempScanDir);
      if (!await tempDir.exists()) {
        return; // Nothing to clean up
      }
      final tempFilesList = tempDir
          .listSync()
          .where((f) => f.path.contains('temp_scan_'))
          .toList();
      for (final file in tempFilesList) {
        try {
          if (file is File) {
            await file.delete();
            await _logger.log(
              'CLEANUP',
              'Deleted orphaned temp file: ${file.path}',
            );
          }
        } catch (e) {
          await _logger.logError(
            'CLEANUP',
            'Failed to delete orphaned temp file ${file.path}: $e',
          );
        }
      }

      // Clean up WSL temp files
      try {
        final wslCleanup = await Process.run('wsl.exe', [
          '-u',
          'root',
          '--',
          'rm',
          '-f',
          '/tmp/temp_scan_*',
        ]);
        if (wslCleanup.exitCode == 0) {
          await _logger.log('CLEANUP', 'Cleaned up WSL temp files');
        }
      } catch (e) {
        await _logger.logError('CLEANUP', 'Failed to clean WSL temp files: $e');
      }

      // Force garbage collection and wait
      await Future.delayed(Duration(milliseconds: 500));
    } catch (e) {
      await _logger.logError('CLEANUP', 'Temp file cleanup error: $e');
    }
  }

  // Process Nmap Results
  Future<Map<String, dynamic>> processNmapResults(
    int projectId,
    Function(String)? onProgress,
  ) async {
    onProgress?.call('Processing nmap results...');

    final autoScans = await scanRepo.getAutoNmapScans(projectId);
    const batchSize = 1;
    int processed = 0;
    int failed = 0;

    for (int i = 0; i < autoScans.length; i += batchSize) {
      final batch = autoScans.skip(i).take(batchSize).toList();
      onProgress?.call(
        'Processing batch ${(i ~/ batchSize) + 1}/${(autoScans.length / batchSize).ceil()}: ${batch.length} scans',
      );

      final futures = batch
          .map((scan) => _processSingleScan(scan, projectId))
          .toList();
      final results = await Future.wait(futures);

      for (final success in results) {
        if (success) {
          processed++;
        } else {
          failed++;
        }
      }
    }

    return {'processed': processed, 'failed': failed};
  }

  Future<bool> _processSingleScan(
    Map<String, dynamic> scan,
    int projectId,
  ) async {
    try {
      final deviceId = scan['device_id'];
      final content = scan['content'];

      await nmapService.processNmapResults(deviceId, projectId, content);
      return true;
    } catch (e) {
      debugPrint('Error processing scan: $e');
      return false;
    }
  }

  // Helper function to poll for scan progress in Web mode
  Future<Map<String, dynamic>> _pollScanProgress(
    int projectId,
    String taskId,
    String scanType,
    int totalDevices,
    Function(String)? onProgress,
  ) async {
    // Start tracking in ScanStatusService
    final statusId = ScanStatusService().startScan(
      scanType: scanType.toUpperCase(),
      totalDevices: totalDevices,
    );

    try {
      while (true) {
        try {
          final response = await http.get(
            Uri.parse('${ApiDatabaseHelper.baseUrl}/projects/$projectId/scan-tasks/$taskId'),
          );

          if (response.statusCode == 200) {
            final progress = json.decode(response.body);
            final status = progress['status'] as String;
            final completed = progress['completed'] as int;
            final total = progress['total'] as int;
            final currentDevice = progress['currentDevice'] as String?;

            // Build status message
            String message;
            if (currentDevice != null) {
              message = '$scanType: Scanning $currentDevice ($completed/$total completed)';
            } else {
              message = '$scanType: $completed/$total completed';
            }

            // Update ScanStatusService for status bar
            ScanStatusService().updateScanProgress(
              id: statusId,
              activeDevices: currentDevice != null ? [currentDevice] : [],
              completed: completed,
            );

            // Update progress callback
            onProgress?.call(message);

            // Check if completed
            if (status == 'completed') {
              ScanStatusService().completeScan(statusId);
              return {
                'completed': completed,
                'failed': progress['failed'] as int,
                'total': total,
              };
            }
          } else {
            // Task not found or error
            ScanStatusService().completeScan(statusId);
            return {'completed': 0, 'failed': 0, 'total': 0};
          }
        } catch (e) {
          ScanStatusService().completeScan(statusId);
          return {'completed': 0, 'failed': 0, 'total': 0};
        }

        // Wait before next poll
        await Future.delayed(const Duration(seconds: 2));
      }
    } finally {
      // Ensure cleanup
      ScanStatusService().completeScan(statusId);
    }
  }

  // Nikto Scans
  Future<Map<String, dynamic>> runNiktoScans(
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  ) async {
    if (kIsWeb) {
      try {
        // Start the scan
        final response = await http.post(
          Uri.parse('${ApiDatabaseHelper.baseUrl}/projects/$projectId/nikto-scans'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'replaceExisting': replaceExisting}),
        );
        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          final taskId = result['taskId'] as String;
          final total = result['total'] as int;

          // Poll for progress
          return await _pollScanProgress(projectId, taskId, 'Nikto', total, onProgress);
        }
        return {'completed': 0, 'failed': 0, 'total': 0};
      } catch (e) {
        return {'completed': 0, 'failed': 0, 'total': 0};
      }
    }

    final deviceMaps = await deviceRepo.getDevices(projectId);
    final targets = <Map<String, dynamic>>[];

    for (final deviceMap in deviceMaps.map((d) => d.toMap())) {
      final scans = await scanRepo.getScans(deviceMap['id']);
      final nmapScan = scans.where((s) => s.scanType == 'AUTO NMAP').firstOrNull;
      if (nmapScan != null) {
        final ports = await _extractHttpPorts(nmapScan.result);
        if (ports.isNotEmpty) {
          targets.add({
            'id': deviceMap['id'],
            'ip_address': deviceMap['ip_address'],
            'ports': ports.join(','),
          });
        }
      }
    }

    // Load concurrency from settings
    final effectiveConcurrency = await _settingsRepo.getIntSetting('concurrent_scan_count', 3);

    await _logger.log('NIKTO_POOL_SCAN', 'Starting pool scan - ${targets.length} targets, concurrency: $effectiveConcurrency');

    // Start tracking in ScanStatusService
    final statusId = ScanStatusService().startScan(
      scanType: 'NIKTO',
      totalDevices: targets.length,
    );

    int completed = 0;
    int failed = 0;
    int targetIndex = 0;
    final activeScans = <int, Future<bool>>{};  // deviceId -> Future
    final activeTargets = <int, Map<String, dynamic>>{};  // deviceId -> target info

    try {
      // Pool pattern: maintain exactly 'concurrency' active scans
      while (targetIndex < targets.length || activeScans.isNotEmpty) {
        if (_isCancelRequested('NIKTO')) break;

        // Fill the pool up to concurrency limit
        while (activeScans.length < effectiveConcurrency &&
               targetIndex < targets.length &&
               !_isCancelRequested('NIKTO')) {
          final target = targets[targetIndex++];

          final scanFuture = runNiktoScan(
            target,
            replaceExisting: replaceExisting,
          );

          activeScans[target['id']] = scanFuture;
          activeTargets[target['id']] = target;

          // Update status with currently active devices
          ScanStatusService().updateScanProgress(
            id: statusId,
            activeDevices: activeTargets.values.map((t) => t['ip_address'] as String).toList(),
            completed: completed,
          );

          onProgress?.call(
            'Nikto: Scanning ${activeTargets.values.map((t) => t['ip_address']).join(', ')} ($completed/${targets.length} completed)',
          );
        }

        // If there are active scans, wait for any one to complete
        if (activeScans.isNotEmpty) {
          final completedEntry = await Future.any(
            activeScans.entries.map((entry) =>
              entry.value.then((success) => MapEntry(entry.key, success))
            ),
          );

          final deviceId = completedEntry.key;
          final success = completedEntry.value;

          if (success) {
            completed++;
          } else {
            failed++;
          }

          activeScans.remove(deviceId);
          activeTargets.remove(deviceId);

          // Update status
          ScanStatusService().updateScanProgress(
            id: statusId,
            activeDevices: activeTargets.values.map((t) => t['ip_address'] as String).toList(),
            completed: completed,
          );

          onProgress?.call(
            activeTargets.isNotEmpty
                ? 'Nikto: Scanning ${activeTargets.values.map((t) => t['ip_address']).join(', ')} ($completed/${targets.length} completed)'
                : 'Nikto: $completed/${targets.length} completed',
          );
        }
      }

      if (_isCancelRequested('NIKTO')) {
        onProgress?.call('Nikto scan cancelled');
        // Note: Nikto uses Process.run() which completes immediately, no need to kill processes
      }

      ScanStatusService().completeScan(statusId);

      await _logger.log('NIKTO_POOL_SCAN', 'Pool scan completed - $completed successful, $failed failed');
      return {'completed': completed, 'failed': failed, 'total': targets.length};
    } catch (e, stackTrace) {
      ScanStatusService().completeScan(statusId);
      await _logger.logError('NIKTO_POOL_SCAN', 'Pool scan error: $e', stackTrace);
      return {'completed': completed, 'failed': failed, 'total': targets.length};
    } finally {
      resetCancel('NIKTO');
    }
  }

  Future<List<String>> _extractHttpPorts(String nmapXml) async {
    final ports = <String>[];
    final portRegex = RegExp(
      r'<port protocol="tcp" portid="(\d+)">.*?<service name="([^"]*?)".*?</port>',
      dotAll: true,
    );
    final matches = portRegex.allMatches(nmapXml);

    for (final match in matches) {
      final port = match.group(1)!;
      final service = match.group(2)?.toLowerCase() ?? '';

      if (port == '80' ||
          port == '443' ||
          port == '8080' ||
          port == '8443' ||
          service.contains('http') ||
          service == 'ms-wbt-server') {
        ports.add(port);
      }
    }
    return ports;
  }

  // Searchsploit Scans
  Future<Map<String, dynamic>> runSearchsploitScans(
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  ) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('${ApiDatabaseHelper.baseUrl}/projects/$projectId/searchsploit-scans'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'replaceExisting': replaceExisting}),
        );
        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          final taskId = result['taskId'] as String;
          final total = result['total'] as int;
          return await _pollScanProgress(projectId, taskId, 'SearchSploit', total, onProgress);
        }
        return {'completed': 0, 'failed': 0, 'total': 0};
      } catch (e) {
        return {'completed': 0, 'failed': 0, 'total': 0};
      }
    }

    final devices = await deviceRepo.getDevices(projectId);

    // Load concurrency from settings
    final effectiveConcurrency = await _settingsRepo.getIntSetting('concurrent_scan_count', 3);

    await _logger.log('SEARCHSPLOIT_POOL_SCAN', 'Starting pool scan - ${devices.length} devices, concurrency: $effectiveConcurrency');

    final statusId = ScanStatusService().startScan(
      scanType: 'SEARCHSPLOIT',
      totalDevices: devices.length,
    );

    int completed = 0;
    int failed = 0;
    int deviceIndex = 0;
    final activeScans = <int, Future<bool>>{};  // deviceId -> Future
    final activeDevices = <int, Device>{};

    try {
      // Pool pattern: maintain exactly 'concurrency' active scans
      while (deviceIndex < devices.length || activeScans.isNotEmpty) {
        if (_isCancelRequested('SEARCHSPLOIT')) break;

        // Fill the pool up to concurrency limit
        while (activeScans.length < effectiveConcurrency &&
               deviceIndex < devices.length &&
               !_isCancelRequested('SEARCHSPLOIT')) {
          final device = devices[deviceIndex++];

          final scanFuture = runSearchsploitScan(
            device,
            replaceExisting: replaceExisting,
          );

          activeScans[device.id] = scanFuture;
          activeDevices[device.id] = device;

          ScanStatusService().updateScanProgress(
            id: statusId,
            activeDevices: activeDevices.values.map((d) => d.ipAddress).toList(),
            completed: completed,
          );

          onProgress?.call(
            'SearchSploit: Scanning ${activeDevices.values.map((d) => d.ipAddress).join(', ')} ($completed/${devices.length} completed)',
          );
        }

        // If there are active scans, wait for any one to complete
        if (activeScans.isNotEmpty) {
          final completedEntry = await Future.any(
            activeScans.entries.map((entry) =>
              entry.value.then((success) => MapEntry(entry.key, success))
            ),
          );

          final deviceId = completedEntry.key;
          final success = completedEntry.value;

          if (success) {
            completed++;
          } else {
            failed++;
          }

          activeScans.remove(deviceId);
          activeDevices.remove(deviceId);

          ScanStatusService().updateScanProgress(
            id: statusId,
            activeDevices: activeDevices.values.map((d) => d.ipAddress).toList(),
            completed: completed,
          );

          onProgress?.call(
            activeDevices.isNotEmpty
                ? 'SearchSploit: Scanning ${activeDevices.values.map((d) => d.ipAddress).join(', ')} ($completed/${devices.length} completed)'
                : 'SearchSploit: $completed/${devices.length} completed',
          );
        }
      }

      if (_isCancelRequested('SEARCHSPLOIT')) {
        onProgress?.call('SearchSploit scan cancelled');
        // Note: SearchSploit uses Process.run() which completes immediately, no need to kill processes
      }

      ScanStatusService().completeScan(statusId);

      await _logger.log('SEARCHSPLOIT_POOL_SCAN', 'Pool scan completed - $completed successful, $failed failed');
      return {'completed': completed, 'failed': failed, 'total': devices.length};
    } catch (e, stackTrace) {
      ScanStatusService().completeScan(statusId);
      await _logger.logError('SEARCHSPLOIT_POOL_SCAN', 'Pool scan error: $e', stackTrace);
      return {'completed': completed, 'failed': failed, 'total': devices.length};
    } finally {
      resetCancel('SEARCHSPLOIT');
    }
  }

  // WhatWeb Scans
  Future<Map<String, dynamic>> runWhatwebScans(
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  ) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('${ApiDatabaseHelper.baseUrl}/projects/$projectId/whatweb-scans'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'replaceExisting': replaceExisting}),
        );
        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          final taskId = result['taskId'] as String;
          final total = result['total'] as int;
          return await _pollScanProgress(projectId, taskId, 'WhatWeb', total, onProgress);
        }
        return {'completed': 0, 'failed': 0, 'total': 0};
      } catch (e) {
        return {'completed': 0, 'failed': 0, 'total': 0};
      }
    }

    final devices = await deviceRepo.getDevices(projectId);

    // Load concurrency from settings
    final effectiveConcurrency = await _settingsRepo.getIntSetting('concurrent_scan_count', 3);

    await _logger.log('WHATWEB_POOL_SCAN', 'Starting pool scan - ${devices.length} devices, concurrency: $effectiveConcurrency');

    final statusId = ScanStatusService().startScan(scanType: 'WHATWEB', totalDevices: devices.length);
    int completed = 0;
    int failed = 0;
    int deviceIndex = 0;
    final activeScans = <int, Future<bool>>{};
    final activeDevices = <int, Device>{};

    try {
      while (deviceIndex < devices.length || activeScans.isNotEmpty) {
        if (_isCancelRequested('WHATWEB')) break;
        while (activeScans.length < effectiveConcurrency && deviceIndex < devices.length && !_isCancelRequested('WHATWEB')) {
          final device = devices[deviceIndex++];
          final scanFuture = runWhatwebScan(device, replaceExisting: replaceExisting);
          activeScans[device.id] = scanFuture;
          activeDevices[device.id] = device;
          ScanStatusService().updateScanProgress(id: statusId, activeDevices: activeDevices.values.map((d) => d.ipAddress).toList(), completed: completed);
          onProgress?.call('WhatWeb: Scanning ${activeDevices.values.map((d) => d.ipAddress).join(', ')} ($completed/${devices.length} completed)');
        }
        if (activeScans.isNotEmpty) {
          final completedEntry = await Future.any(activeScans.entries.map((entry) => entry.value.then((success) => MapEntry(entry.key, success))));
          final deviceId = completedEntry.key;
          final success = completedEntry.value;
          if (success) { completed++; } else { failed++; }
          activeScans.remove(deviceId);
          activeDevices.remove(deviceId);
          ScanStatusService().updateScanProgress(id: statusId, activeDevices: activeDevices.values.map((d) => d.ipAddress).toList(), completed: completed);
          onProgress?.call(activeDevices.isNotEmpty ? 'WhatWeb: Scanning ${activeDevices.values.map((d) => d.ipAddress).join(', ')} ($completed/${devices.length} completed)' : 'WhatWeb: $completed/${devices.length} completed');
        }
      }
      if (_isCancelRequested('WHATWEB')) { onProgress?.call('WhatWeb scan cancelled'); }
      ScanStatusService().completeScan(statusId);
      await _logger.log('WHATWEB_POOL_SCAN', 'Pool scan completed - $completed successful, $failed failed');
      return {'completed': completed, 'failed': failed, 'total': devices.length};
    } catch (e, stackTrace) {
      ScanStatusService().completeScan(statusId);
      await _logger.logError('WHATWEB_POOL_SCAN', 'Pool scan error: $e', stackTrace);
      return {'completed': completed, 'failed': failed, 'total': devices.length};
    } finally {
      resetCancel('WHATWEB');
    }
  }

  // FFUF Scans
  Future<Map<String, dynamic>> runFfufScans(
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  ) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('${ApiDatabaseHelper.baseUrl}/projects/$projectId/ffuf-scans'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'replaceExisting': replaceExisting}),
        );
        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          final taskId = result['taskId'] as String;
          final total = result['total'] as int;
          return await _pollScanProgress(projectId, taskId, 'FFUF', total, onProgress);
        }
        return {'completed': 0, 'failed': 0, 'total': 0};
      } catch (e) {
        return {'completed': 0, 'failed': 0, 'total': 0};
      }
    }

    final deviceMaps = await deviceRepo.getDevices(projectId);
    final targets = <Map<String, dynamic>>[];

    for (final deviceMap in deviceMaps.map((d) => d.toMap())) {
      final scans = await scanRepo.getScans(deviceMap['id']);
      final nmapScan = scans.where((s) => s.scanType == 'AUTO NMAP').firstOrNull;
      if (nmapScan != null) {
        final ports = await _extractHttpPorts(nmapScan.result);
        if (ports.isNotEmpty) {
          targets.add({
            'id': deviceMap['id'],
            'ip_address': deviceMap['ip_address'],
            'ports': ports.join(','),
          });
        }
      }
    }

    // Load concurrency from settings
    final effectiveConcurrency = await _settingsRepo.getIntSetting('concurrent_scan_count', 3);

    await _logger.log('FFUF_POOL_SCAN', 'Starting pool scan - ${targets.length} targets, concurrency: $effectiveConcurrency');
    final statusId = ScanStatusService().startScan(scanType: 'FFUF', totalDevices: targets.length);
    int completed = 0; int failed = 0; int targetIndex = 0;
    final activeScans = <int, Future<bool>>{}; final activeTargets = <int, Map<String, dynamic>>{};
    try {
      while (targetIndex < targets.length || activeScans.isNotEmpty) {
        if (_isCancelRequested('FFUF')) break;
        while (activeScans.length < effectiveConcurrency && targetIndex < targets.length && !_isCancelRequested('FFUF')) {
          final target = targets[targetIndex++];
          final scanFuture = runFfufScan(target, replaceExisting: replaceExisting);
          activeScans[target['id']] = scanFuture; activeTargets[target['id']] = target;
          ScanStatusService().updateScanProgress(id: statusId, activeDevices: activeTargets.values.map((t) => t['ip_address'] as String).toList(), completed: completed);
          onProgress?.call('FFUF: Scanning ${activeTargets.values.map((t) => t['ip_address']).join(', ')} ($completed/${targets.length} completed)');
        }
        if (activeScans.isNotEmpty) {
          final completedEntry = await Future.any(activeScans.entries.map((entry) => entry.value.then((success) => MapEntry(entry.key, success))));
          final deviceId = completedEntry.key; final success = completedEntry.value;
          if (success) { completed++; } else { failed++; }
          activeScans.remove(deviceId); activeTargets.remove(deviceId);
          ScanStatusService().updateScanProgress(id: statusId, activeDevices: activeTargets.values.map((t) => t['ip_address'] as String).toList(), completed: completed);
          onProgress?.call(activeTargets.isNotEmpty ? 'FFUF: Scanning ${activeTargets.values.map((t) => t['ip_address']).join(', ')} ($completed/${targets.length} completed)' : 'FFUF: $completed/${targets.length} completed');
        }
      }
      if (_isCancelRequested('FFUF')) { onProgress?.call('FFUF scan cancelled'); }
      ScanStatusService().completeScan(statusId);
      await _logger.log('FFUF_POOL_SCAN', 'Pool scan completed - $completed successful, $failed failed');
      return {'completed': completed, 'failed': failed, 'total': targets.length};
    } catch (e, stackTrace) {
      ScanStatusService().completeScan(statusId);
      await _logger.logError('FFUF_POOL_SCAN', 'Pool scan error: $e', stackTrace);
      return {'completed': completed, 'failed': failed, 'total': targets.length};
    } finally {
      resetCancel('FFUF');
    }
  }

  // Samba/LDAP Scans
  Future<Map<String, dynamic>> runSambaLdapScans(
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  ) async {
    debugPrint('');
    debugPrint('╔═══════════════════════════════════════════════════════════════════╗');
    debugPrint('║  SAMBA/LDAP (ENUM4LINUX) BATCH SCAN - START                      ║');
    debugPrint('╚═══════════════════════════════════════════════════════════════════╝');
    debugPrint('Project ID: $projectId');
    debugPrint('Replace existing: $replaceExisting');
    debugPrint('');

    if (kIsWeb) {
      debugPrint('Web mode - using API endpoint');
      try {
        final response = await http.post(
          Uri.parse('${ApiDatabaseHelper.baseUrl}/projects/$projectId/enum4linux-scans'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'replaceExisting': replaceExisting}),
        );
        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          final taskId = result['taskId'] as String;
          final total = result['total'] as int;
          return await _pollScanProgress(projectId, taskId, 'Enum4Linux', total, onProgress);
        }
        return {'completed': 0, 'failed': 0, 'total': 0};
      } catch (e) {
        return {'completed': 0, 'failed': 0, 'total': 0};
      }
    }

    debugPrint('Desktop mode - extracting targets from NMAP scan results');
    final deviceMaps = await deviceRepo.getDevices(projectId);
    debugPrint('Total devices in project: ${deviceMaps.length}');
    debugPrint('');
    debugPrint('>>> Parsing NMAP results for each device to find SAMBA/LDAP ports...');

    final targets = <Map<String, dynamic>>[];

    for (final deviceMap in deviceMaps.map((d) => d.toMap())) {
      final scans = await scanRepo.getScans(deviceMap['id']);
      final nmapScan = scans.where((s) => s.scanType == 'AUTO NMAP').firstOrNull;
      if (nmapScan != null) {
        final ports = await _extractSmbLdapPorts(nmapScan.result);
        if (ports.isNotEmpty) {
          debugPrint('  Device ${deviceMap['id']} (${deviceMap['ip_address']}): Found SAMBA/LDAP ports ${ports.join(', ')}');
          targets.add({
            'id': deviceMap['id'],
            'ip_address': deviceMap['ip_address'],
            'ports': ports.join(','),
          });
        } else {
          debugPrint('  Device ${deviceMap['id']} (${deviceMap['ip_address']}): No SAMBA/LDAP ports found in NMAP results');
        }
      } else {
        debugPrint('  Device ${deviceMap['id']} (${deviceMap['ip_address']}): No AUTO NMAP scan found');
      }
    }

    debugPrint('');
    debugPrint('>>> Target extraction complete: ${targets.length} device(s) have SAMBA/LDAP ports');

    if (targets.isEmpty) {
      debugPrint('');
      debugPrint('⚠️  NO TARGETS FOUND ⚠️');
      debugPrint('No devices have SAMBA/LDAP ports in their NMAP scan results');
      debugPrint('');
      debugPrint('╔═══════════════════════════════════════════════════════════════════╗');
      debugPrint('║  SAMBA/LDAP BATCH SCAN - END (NO TARGETS)                        ║');
      debugPrint('╚═══════════════════════════════════════════════════════════════════╝');
      debugPrint('');
      return {'completed': 0, 'failed': 0, 'total': 0};
    }

    debugPrint('Devices to scan:');
    for (int i = 0; i < targets.length; i++) {
      debugPrint('  ${i + 1}. Device ${targets[i]['id']} - ${targets[i]['ip_address']} (ports: ${targets[i]['ports']})');
    }
    debugPrint('');

    // Load concurrency from settings
    final effectiveConcurrency = await _settingsRepo.getIntSetting('concurrent_scan_count', 3);
    debugPrint('Concurrency setting: $effectiveConcurrency');
    debugPrint('');

    await _logger.log('ENUM4LINUX_POOL_SCAN', 'Starting pool scan - ${targets.length} targets, concurrency: $effectiveConcurrency');
    final statusId = ScanStatusService().startScan(scanType: 'ENUM4LINUX', totalDevices: targets.length);
    int completed = 0; int failed = 0; int targetIndex = 0;
    final activeScans = <int, Future<bool>>{}; final activeTargets = <int, Map<String, dynamic>>{};
    try {
      while (targetIndex < targets.length || activeScans.isNotEmpty) {
        if (_isCancelRequested('ENUM4LINUX')) break;
        while (activeScans.length < effectiveConcurrency && targetIndex < targets.length && !_isCancelRequested('ENUM4LINUX')) {
          final target = targets[targetIndex++];
          final scanFuture = runEnum4linuxScan(target, replaceExisting: replaceExisting);
          activeScans[target['id']] = scanFuture; activeTargets[target['id']] = target;
          ScanStatusService().updateScanProgress(id: statusId, activeDevices: activeTargets.values.map((t) => t['ip_address'] as String).toList(), completed: completed);
          onProgress?.call('Enum4Linux: Scanning ${activeTargets.values.map((t) => t['ip_address']).join(', ')} ($completed/${targets.length} completed)');
        }
        if (activeScans.isNotEmpty) {
          final completedEntry = await Future.any(activeScans.entries.map((entry) => entry.value.then((success) => MapEntry(entry.key, success))));
          final deviceId = completedEntry.key; final success = completedEntry.value;
          if (success) { completed++; } else { failed++; }
          activeScans.remove(deviceId); activeTargets.remove(deviceId);
          ScanStatusService().updateScanProgress(id: statusId, activeDevices: activeTargets.values.map((t) => t['ip_address'] as String).toList(), completed: completed);
          onProgress?.call(activeTargets.isNotEmpty ? 'Enum4Linux: Scanning ${activeTargets.values.map((t) => t['ip_address']).join(', ')} ($completed/${targets.length} completed)' : 'Enum4Linux: $completed/${targets.length} completed');
        }
      }
      if (_isCancelRequested('ENUM4LINUX')) { onProgress?.call('Enum4Linux scan cancelled'); }
      ScanStatusService().completeScan(statusId);
      await _logger.log('ENUM4LINUX_POOL_SCAN', 'Pool scan completed - $completed successful, $failed failed');

      debugPrint('');
      debugPrint('╔═══════════════════════════════════════════════════════════════════╗');
      debugPrint('║  SAMBA/LDAP BATCH SCAN - END (SUCCESS)                           ║');
      debugPrint('╚═══════════════════════════════════════════════════════════════════╝');
      debugPrint('Results: $completed completed, $failed failed, ${targets.length} total');
      debugPrint('');

      return {'completed': completed, 'failed': failed, 'total': targets.length};
    } catch (e, stackTrace) {
      ScanStatusService().completeScan(statusId);
      await _logger.logError('ENUM4LINUX_POOL_SCAN', 'Pool scan error: $e', stackTrace);

      debugPrint('');
      debugPrint('╔═══════════════════════════════════════════════════════════════════╗');
      debugPrint('║  SAMBA/LDAP BATCH SCAN - END (ERROR)                             ║');
      debugPrint('╚═══════════════════════════════════════════════════════════════════╝');
      debugPrint('Error: $e');
      debugPrint('');

      return {'completed': completed, 'failed': failed, 'total': targets.length};
    } finally {
      resetCancel('ENUM4LINUX');
    }
  }

  Future<List<String>> _extractSmbLdapPorts(String nmapXml) async {
    final ports = <String>[];
    final portRegex = RegExp(
      r'<port protocol="tcp" portid="(\d+)">.*?<service name="([^"]*?)".*?</port>',
      dotAll: true,
    );
    final matches = portRegex.allMatches(nmapXml);

    for (final match in matches) {
      final port = match.group(1)!;
      final service = match.group(2)?.toLowerCase() ?? '';

      if (port == '139' ||
          port == '445' ||
          port == '389' ||
          port == '636' ||
          service.contains('smb') ||
          service.contains('ldap') ||
          service.contains('microsoft-ds') ||
          service.contains('netbios')) {
        ports.add(port);
      }
    }
    return ports;
  }

  // Helper methods for single-device scans (used by SCANS tab)
  // These build the target maps automatically from device metadata

  Future<bool> runNiktoScanForDevice(
    int deviceId, {
    bool replaceExisting = true,
  }) async {
    final targets = await _metadataRepo.getHttpTargetsForDevice(deviceId);
    if (targets.isEmpty) return false;

    for (final target in targets) {
      final success = await runNiktoScan(
        target,
        replaceExisting: replaceExisting,
      );
      if (!success) return false;
    }
    return true;
  }

  Future<bool> runFfufScanForDevice(
    int deviceId, {
    bool replaceExisting = true,
  }) async {
    final targets = await _metadataRepo.getHttpTargetsForDevice(deviceId);
    if (targets.isEmpty) return false;

    for (final target in targets) {
      final success = await runFfufScan(
        target,
        replaceExisting: replaceExisting,
      );
      if (!success) return false;
    }
    return true;
  }

  Future<bool> runEnum4linuxScanForDevice(
    int deviceId, {
    bool replaceExisting = true,
  }) async {
    debugPrint('');
    debugPrint('╔═══════════════════════════════════════════════════════════════════╗');
    debugPrint('║  ENUM4LINUX SCAN FOR DEVICE - START                              ║');
    debugPrint('╚═══════════════════════════════════════════════════════════════════╝');
    debugPrint('Device ID: $deviceId');
    debugPrint('Replace existing: $replaceExisting');
    debugPrint('');
    debugPrint('>>> Calling getSambaLdapTargetsForDevice...');

    final targets = await _metadataRepo.getSambaLdapTargetsForDevice(deviceId);

    debugPrint('>>> getSambaLdapTargetsForDevice returned ${targets.length} target(s)');
    if (targets.isEmpty) {
      debugPrint('');
      debugPrint('⚠️  NO TARGETS FOUND - SCAN WILL FAIL ⚠️');
      debugPrint('This means no SAMBA/LDAP ports (139, 389, 445, 636) were found open for this device');
      debugPrint('');
      debugPrint('╔═══════════════════════════════════════════════════════════════════╗');
      debugPrint('║  ENUM4LINUX SCAN FOR DEVICE - END (NO TARGETS)                   ║');
      debugPrint('╚═══════════════════════════════════════════════════════════════════╝');
      debugPrint('');
      return false;
    }

    debugPrint('Targets to scan:');
    for (int i = 0; i < targets.length; i++) {
      debugPrint('  ${i + 1}. ${targets[i]}');
    }
    debugPrint('');

    for (final target in targets) {
      debugPrint('>>> Running enum4linux scan for target: $target');
      final success = await runEnum4linuxScan(
        target,
        replaceExisting: replaceExisting,
      );
      debugPrint('>>> Scan completed for target $target - success: $success');
      if (!success) {
        debugPrint('');
        debugPrint('╔═══════════════════════════════════════════════════════════════════╗');
        debugPrint('║  ENUM4LINUX SCAN FOR DEVICE - END (SCAN FAILED)                  ║');
        debugPrint('╚═══════════════════════════════════════════════════════════════════╝');
        debugPrint('');
        return false;
      }
    }

    debugPrint('');
    debugPrint('╔═══════════════════════════════════════════════════════════════════╗');
    debugPrint('║  ENUM4LINUX SCAN FOR DEVICE - END (SUCCESS)                      ║');
    debugPrint('╚═══════════════════════════════════════════════════════════════════╝');
    debugPrint('');
    return true;
  }

  // Unified SNMP scan - works for single device or multiple devices
  Future<bool> runSnmpScan(
    Device device,
    int projectId, {
    bool replaceExisting = true,
  }) async {
    await _logger.log('SNMP_ORCHESTRATOR', '========================================');
    await _logger.log('SNMP_ORCHESTRATOR', 'Starting SNMP scan for device ${device.id}');
    await _logger.log('SNMP_ORCHESTRATOR', 'Device name: ${device.name}');
    await _logger.log('SNMP_ORCHESTRATOR', 'Device IP: ${device.ipAddress}');
    await _logger.log('SNMP_ORCHESTRATOR', 'Project ID: $projectId');
    await _logger.log('SNMP_ORCHESTRATOR', 'Replace existing: $replaceExisting');
    await _logger.flush();

    await _logger.logScanStart(
      'SNMP',
      device.id,
      device.name,
      device.ipAddress,
    );

    try {
      if (replaceExisting) {
        await _logger.log('SNMP_ORCHESTRATOR', 'Checking for existing scans to delete...');
        await _logger.flush();
        final existingScans = await scanRepo.getScans(device.id);
        await _logger.log('SNMP_ORCHESTRATOR', 'Found ${existingScans.length} existing scans');
        await _logger.flush();

        int deletedCount = 0;
        for (final scan in existingScans) {
          if (scan.scanType == 'SNMP AUTO') {
            await scanRepo.deleteScan(scan.id);
            deletedCount++;
          }
        }
        await _logger.log('SNMP_ORCHESTRATOR', 'Deleted $deletedCount SNMP AUTO scans');
        await _logger.flush();
      }

      final uniqueId = '${device.id}_${DateTime.now().millisecondsSinceEpoch}';
      await _logger.log(
        'SNMP_ORCHESTRATOR',
        'Device ${device.id} - Running SNMP scan with uniqueId: $uniqueId',
      );
      await _logger.flush();

      await _logger.log('SNMP_ORCHESTRATOR', 'Calling snmpService.runSnmpScan...');
      await _logger.flush();

      final scanResult = await snmpService.runSnmpScan(
        device.ipAddress,
        uniqueId,
      );

      await _logger.log('SNMP_ORCHESTRATOR', 'snmpService.runSnmpScan returned');
      await _logger.log('SNMP_ORCHESTRATOR', 'Result length: ${scanResult.length} characters');
      await _logger.flush();

      if (scanResult.trim().isEmpty) {
        await _logger.logError(
          'SNMP_ORCHESTRATOR',
          'Device ${device.id} - Empty scan result (after trim)',
        );
        await _logger.flush();
        await _logger.logScanComplete('SNMP', device.id, device.name, false);
        return false;
      }

      await _logger.log(
        'SNMP_ORCHESTRATOR',
        'Device ${device.id} - Scan completed, XML length: ${scanResult.length}',
      );
      await _logger.flush();

      await _logger.log('SNMP_ORCHESTRATOR', 'Inserting scan result into database...');
      await _logger.flush();

      await scanRepo.insertScan(device.id, 'SNMP AUTO', scanResult);

      await _logger.log(
        'SNMP_ORCHESTRATOR',
        'Device ${device.id} - Scan inserted to database successfully',
      );
      await _logger.flush();

      // Process results in background (non-blocking) only if not cancelled
      // This allows the scan pool to immediately start the next scan
      if (!_isCancelRequested('SNMP')) {
        await _logger.log('SNMP_ORCHESTRATOR', 'Processing results in background...');
        await _logger.flush();
        _processSnmpResultsInBackground(device.id, device.name, projectId, scanResult);
      } else {
        await _logger.log('SNMP_ORCHESTRATOR', 'Skipping background processing (cancel requested)');
        await _logger.flush();
      }

      await _logger.log('SNMP_ORCHESTRATOR', 'SNMP scan completed successfully for device ${device.id}');
      await _logger.log('SNMP_ORCHESTRATOR', '========================================');
      await _logger.flush();
      await _logger.logScanComplete('SNMP', device.id, device.name, true);
      return true;
    } catch (e, stackTrace) {
      await _logger.logError(
        'SNMP_ORCHESTRATOR',
        'Device ${device.id} (${device.name}) failed with error: $e',
        stackTrace,
      );
      await _logger.log('SNMP_ORCHESTRATOR', '========================================');
      await _logger.flush();
      await _logger.logScanComplete('SNMP', device.id, device.name, false);
      return false;
    }
  }

  // SNMP Scans for all devices
  Future<Map<String, dynamic>> runSnmpScans(
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  ) async {
    await _logger.log('SNMP_POOL_SCAN', '========== STARTING SNMP POOL SCAN ==========');
    await _logger.log('SNMP_POOL_SCAN', 'Project ID: $projectId');
    await _logger.log('SNMP_POOL_SCAN', 'Replace existing: $replaceExisting');
    await _logger.flush();

    if (kIsWeb) {
      await _logger.log('SNMP_POOL_SCAN', 'Running in web mode');
      await _logger.flush();
      try {
        final response = await http.post(
          Uri.parse('${ApiDatabaseHelper.baseUrl}/projects/$projectId/snmp-scans'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'replaceExisting': replaceExisting}),
        );
        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          final taskId = result['taskId'] as String;
          final total = result['total'] as int;
          return await _pollScanProgress(projectId, taskId, 'SNMP', total, onProgress);
        }
        return {'completed': 0, 'failed': 0, 'total': 0};
      } catch (e) {
        await _logger.logError('SNMP_POOL_SCAN', 'Web mode error: $e');
        await _logger.flush();
        return {'completed': 0, 'failed': 0, 'total': 0};
      }
    }

    await _logger.log('SNMP_POOL_SCAN', 'Running in desktop mode');
    await _logger.log('SNMP_POOL_SCAN', 'Loading devices...');
    await _logger.flush();

    final devices = await deviceRepo.getDevices(projectId);

    await _logger.log('SNMP_POOL_SCAN', 'Found ${devices.length} devices');
    if (devices.isEmpty) {
      await _logger.log('SNMP_POOL_SCAN', 'No devices to scan, returning');
      await _logger.flush();
      return {'completed': 0, 'failed': 0, 'total': 0};
    }
    await _logger.flush();

    // Load concurrency from settings
    final effectiveConcurrency = await _settingsRepo.getIntSetting('concurrent_scan_count', 3);

    await _logger.log('SNMP_POOL_SCAN', 'Starting pool scan - ${devices.length} devices, concurrency: $effectiveConcurrency');
    await _logger.flush();

    final statusId = ScanStatusService().startScan(scanType: 'SNMP', totalDevices: devices.length);
    int completed = 0; int failed = 0; int deviceIndex = 0;
    final activeScans = <int, Future<bool>>{}; final activeDevices = <int, Device>{};
    try {
      await _logger.log('SNMP_POOL_SCAN', 'Entering main scan loop...');
      await _logger.flush();

      while (deviceIndex < devices.length || activeScans.isNotEmpty) {
        if (_isCancelRequested('SNMP')) {
          await _logger.log('SNMP_POOL_SCAN', 'Cancel requested, breaking out of scan loop');
          await _logger.flush();
          break;
        }

        // Fill the pool with scans up to concurrency limit
        while (activeScans.length < effectiveConcurrency && deviceIndex < devices.length && !_isCancelRequested('SNMP')) {
          final device = devices[deviceIndex];
          await _logger.log('SNMP_POOL_SCAN', 'Starting scan for device ${deviceIndex + 1}/${devices.length}: ${device.name} (${device.ipAddress})');
          await _logger.flush();

          deviceIndex++;
          final scanFuture = runSnmpScan(device, projectId, replaceExisting: replaceExisting);
          activeScans[device.id] = scanFuture; activeDevices[device.id] = device;

          await _logger.log('SNMP_POOL_SCAN', 'Active scans: ${activeScans.length}, Completed: $completed, Failed: $failed');
          await _logger.flush();

          ScanStatusService().updateScanProgress(id: statusId, activeDevices: activeDevices.values.map((d) => d.ipAddress).toList(), completed: completed);
          onProgress?.call('SNMP: Scanning ${activeDevices.values.map((d) => d.ipAddress).join(', ')} ($completed/${devices.length} completed)');
        }

        if (activeScans.isNotEmpty) {
          await _logger.log('SNMP_POOL_SCAN', 'Waiting for any of ${activeScans.length} active scans to complete...');
          await _logger.flush();

          final completedEntry = await Future.any(activeScans.entries.map((entry) => entry.value.then((success) => MapEntry(entry.key, success))));
          final deviceId = completedEntry.key; final success = completedEntry.value;

          final completedDevice = activeDevices[deviceId];
          await _logger.log('SNMP_POOL_SCAN', 'Scan completed for device ${completedDevice?.name} (${completedDevice?.ipAddress}): ${success ? "SUCCESS" : "FAILED"}');
          await _logger.flush();

          if (success) { completed++; } else { failed++; }
          activeScans.remove(deviceId); activeDevices.remove(deviceId);

          await _logger.log('SNMP_POOL_SCAN', 'Updated counts - Completed: $completed, Failed: $failed, Active: ${activeScans.length}');
          await _logger.flush();

          ScanStatusService().updateScanProgress(id: statusId, activeDevices: activeDevices.values.map((d) => d.ipAddress).toList(), completed: completed);
          onProgress?.call(activeDevices.isNotEmpty ? 'SNMP: Scanning ${activeDevices.values.map((d) => d.ipAddress).join(', ')} ($completed/${devices.length} completed)' : 'SNMP: $completed/${devices.length} completed');
        }
      }

      if (_isCancelRequested('SNMP')) {
        await _logger.log('SNMP_POOL_SCAN', 'Scan was cancelled, killing all processes...');
        await _logger.flush();
        onProgress?.call('SNMP scan cancelled');
        await snmpService.killAllProcesses();
      }

      ScanStatusService().completeScan(statusId);
      await _logger.log('SNMP_POOL_SCAN', '========== SNMP POOL SCAN COMPLETED ==========');
      await _logger.log('SNMP_POOL_SCAN', 'Results - Completed: $completed, Failed: $failed, Total: ${devices.length}');
      await _logger.flush();

      return {'completed': completed, 'failed': failed, 'total': devices.length};
    } catch (e, stackTrace) {
      ScanStatusService().completeScan(statusId);
      await _logger.logError('SNMP_POOL_SCAN', '========== SNMP POOL SCAN ERROR ==========');
      await _logger.logError('SNMP_POOL_SCAN', 'Pool scan error: $e', stackTrace);
      await _logger.flush();
      return {'completed': completed, 'failed': failed, 'total': devices.length};
    } finally {
      await _logger.log('SNMP_POOL_SCAN', 'Resetting cancel flag');
      await _logger.flush();
      resetCancel('SNMP');
    }
  }
}
