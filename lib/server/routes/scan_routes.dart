import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shelf/shelf.dart' as shelf;
import 'package:penpeeper/database_helper.dart';
import 'package:penpeeper/repositories/project_repository.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/scan_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/repositories/settings_repository.dart';
import 'package:penpeeper/services/nmap_processor.dart';
import 'package:penpeeper/services/nikto_scan_service.dart';
import 'package:penpeeper/services/searchsploit_scan_service.dart';
import 'package:penpeeper/services/whatweb_scan_service.dart';
import 'package:penpeeper/services/ffuf_scan_service.dart';
import 'package:penpeeper/services/enum4linux_scan_service.dart';
import 'package:penpeeper/services/snmp_scan_service.dart';
import 'package:penpeeper/server/scan_progress_tracker.dart';

// Session password storage for web terminal mode
String? _sessionPassword;

class ScanRoutes {
  static Future<shelf.Response?> handle(
    shelf.Request request,
    List<String> parts,
    DatabaseHelper db,
  ) async {
    // POST /api/set-session-password
    if (parts.length == 1 &&
        parts[0] == 'set-session-password' &&
        request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      _sessionPassword = body['password'] as String?;
      return _jsonResponse({'success': true});
    }

    // POST /api/devices/:id/scan
    if (parts.length == 3 &&
        parts[0] == 'devices' &&
        parts[2] == 'scan' &&
        request.method == 'POST') {
      final deviceId = int.parse(parts[1]);
      return await _handleDeviceScan(db, deviceId);
    }

    // GET /api/projects/:id/scan-progress
    if (parts.length == 3 &&
        parts[0] == 'projects' &&
        parts[2] == 'scan-progress' &&
        request.method == 'GET') {
      final projectId = int.parse(parts[1]);
      return await _handleScanProgress(projectId);
    }

    // POST /api/nmap/device-scan
    if (parts.length == 2 &&
        parts[0] == 'nmap' &&
        parts[1] == 'device-scan' &&
        request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      return await _handleNmapDeviceScan(body['target'] as String);
    }

    // POST /api/nmap/process-results
    if (parts.length == 2 &&
        parts[0] == 'nmap' &&
        parts[1] == 'process-results' &&
        request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      return await _handleNmapProcessResults(body);
    }

    // GET /api/projects/:id/scan-tasks/:taskId - Get progress for a specific task
    if (parts.length == 4 &&
        parts[0] == 'projects' &&
        parts[2] == 'scan-tasks' &&
        request.method == 'GET') {
      final taskId = parts[3];
      return _handleGetTaskProgress(taskId);
    }

    // Batch scan routes
    if (parts.length == 3 && parts[0] == 'projects' && request.method == 'POST') {
      // Check if this is a scan-related endpoint before reading the body
      final validScanEndpoints = [
        'nmap-scans',
        'snmp-scans',
        'nikto-scans',
        'searchsploit-scans',
        'whatweb-scans',
        'ffuf-scans',
        'enum4linux-scans',
        'scan-hosts',
      ];

      if (!validScanEndpoints.contains(parts[2])) {
        return null; // Not a scan endpoint, let other handlers process it
      }

      final projectId = int.parse(parts[1]);
      final body = json.decode(await request.readAsString());
      final replaceExisting = body['replaceExisting'] as bool? ?? false;

      switch (parts[2]) {
        case 'nmap-scans':
          return await _handleNmapScans(db, projectId, replaceExisting);
        case 'snmp-scans':
          return await _handleSnmpScans(db, projectId, replaceExisting);
        case 'nikto-scans':
          return await _handleNiktoScans(db, projectId, replaceExisting);
        case 'searchsploit-scans':
          return await _handleSearchsploitScans(db, projectId, replaceExisting);
        case 'whatweb-scans':
          return await _handleWhatwebScans(db, projectId, replaceExisting);
        case 'ffuf-scans':
          return await _handleFfufScans(db, projectId, replaceExisting);
        case 'enum4linux-scans':
          return await _handleEnum4linuxScans(db, projectId, replaceExisting);
        case 'scan-hosts':
          final target = body['target'] as String;
          return await _scanHosts(projectId, target);
      }
    }

    // GET /api/projects/:id/has-nmap-results
    if (parts.length == 3 &&
        parts[0] == 'projects' &&
        parts[2] == 'has-nmap-results' &&
        request.method == 'GET') {
      final projectId = int.parse(parts[1]);
      return await _handleHasNmapResults(projectId);
    }

    // Individual device scan routes
    if (parts.length == 3 && parts[0] == 'devices' && request.method == 'POST') {
      final deviceId = int.parse(parts[1]);
      final body = json.decode(await request.readAsString());

      switch (parts[2]) {
        case 'nikto':
          return await _handleDeviceNiktoScan(db, deviceId, body);
        case 'searchsploit':
          return await _handleDeviceSearchsploitScan(db, deviceId, body);
        case 'whatweb':
          return await _handleDeviceWhatwebScan(db, deviceId, body);
        case 'enum4linux':
          return await _handleDeviceEnum4linuxScan(db, deviceId, body);
        case 'ffuf':
          return await _handleDeviceFfufScan(db, deviceId, body);
        case 'snmp':
          return await _handleDeviceSnmpScan(db, deviceId, body);
      }
    }

    return null;
  }

  static Future<shelf.Response> _handleDeviceScan(
    DatabaseHelper db,
    int deviceId,
  ) async {
    try {
      final projectRepository = ProjectRepository();
      final deviceRepository = DeviceRepository();
      final scanRepository = ScanRepository();
      final projects = await projectRepository.getProjectsRaw();
      String? ipAddress;
      int? projectId;

      for (final project in projects) {
        final devices = await deviceRepository.getDevicesRaw(project['id']);
        final device = devices.where((d) => d['id'] == deviceId).firstOrNull;
        if (device != null) {
          ipAddress = device['ip_address'];
          projectId = project['id'];
          break;
        }
      }

      if (ipAddress == null || projectId == null) {
        return shelf.Response.notFound(
          json.encode({'error': 'Device not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final xmlContent = await _runNmapScan(ipAddress, _sessionPassword);
      if (xmlContent == null) {
        return shelf.Response.internalServerError(
          body: json.encode({'error': 'Nmap scan failed'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await scanRepository.insertScan(deviceId, 'AUTO NMAP', xmlContent);

      await NmapProcessor.processXmlContent(
        deviceId,
        projectId,
        xmlContent,
      );

      final vulnRepo = VulnerabilityRepository();
      await vulnRepo.updateVulnersCacheForDevice(deviceId);

      return _jsonResponse({'success': true, 'message': 'Scan completed'});
    } catch (e) {
      return shelf.Response.internalServerError(
        body: json.encode({'error': 'Scan failed: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  static Future<String?> _runNmapScan(String target, [String? password]) async {
    try {
      print('[NMAP] Starting scan for target: $target');
      print('[NMAP] Password provided: ${password != null}');
      
      final tempFile = '/tmp/nmap_${DateTime.now().millisecondsSinceEpoch}.xml';
      final args = [
        '-sV',
        '-O',
        '--script',
        'vulners,http-enum,http-devframework,http-title,http-server-header',
        '--host-timeout',
        '10m',
        '--max-retries',
        '2',
        '-T4',
        '-oX',
        tempFile,
        target,
      ];
      
      ProcessResult result;
      if (password != null) {
        print('[NMAP] Running with sudo');
        print('[NMAP] Command: sudo -S nmap ${args.join(' ')}');
        final process = await Process.start('sudo', ['-S', 'nmap', ...args]);
        process.stdin.writeln(password);
        await process.stdin.flush();
        await process.stdin.close();
        final stdout = await process.stdout.transform(utf8.decoder).join();
        final stderr = await process.stderr.transform(utf8.decoder).join();
        final exitCode = await process.exitCode;
        result = ProcessResult(process.pid, exitCode, stdout, stderr);
        print('[NMAP] Exit code: $exitCode');
        if (stderr.isNotEmpty) print('[NMAP] STDERR: $stderr');
      } else {
        print('[NMAP] Running without sudo');
        print('[NMAP] Command: nmap ${args.join(' ')}');
        result = await Process.run('nmap', args.cast<String>());
        print('[NMAP] Exit code: ${result.exitCode}');
        if (result.stderr.toString().isNotEmpty) {
          print('[NMAP] STDERR: ${result.stderr}');
        }
      }

      if (result.exitCode == 0) {
        final xmlFile = File(tempFile);
        if (await xmlFile.exists()) {
          final xmlContent = await xmlFile.readAsString();
          print('[NMAP] Success: XML file size ${xmlContent.length} bytes');
          try {
            if (password != null) {
              // Delete with sudo since file was created by sudo
              final delProcess = await Process.start('sudo', ['-S', 'rm', tempFile]);
              delProcess.stdin.writeln(password);
              await delProcess.stdin.close();
              await delProcess.exitCode;
            } else {
              await xmlFile.delete();
            }
          } catch (e) {
            print('[NMAP] Warning: Could not delete temp file: $e');
          }
          return xmlContent;
        } else {
          print('[NMAP] Error: XML file not created at $tempFile');
        }
      } else {
        print('[NMAP] Error: Scan failed with exit code ${result.exitCode}');
      }
      return null;
    } catch (e, stack) {
      print('[NMAP] Exception: $e');
      print('[NMAP] Stack: $stack');
      return null;
    }
  }

  static Future<shelf.Response> _handleScanProgress(int projectId) async {
    final deviceRepository = DeviceRepository();
    final scanRepository = ScanRepository();
    final devices = await deviceRepository.getDevicesRaw(projectId);
    int completed = 0;

    for (final device in devices) {
      final scans = await scanRepository.getScansRaw(device['id']);
      if (scans.any((s) => s['name'] == 'AUTO NMAP')) {
        completed++;
      }
    }

    return _jsonResponse({'completed': completed, 'total': devices.length});
  }

  static Future<shelf.Response> _handleNmapDeviceScan(String target) async {
    try {
      final tempFile = '/tmp/nmap_${DateTime.now().millisecondsSinceEpoch}.xml';
      final args = [
        '-sV',
        '-O',
        '--script',
        'vulners,http-enum,http-devframework,http-title,http-server-header',
        '--host-timeout',
        '10m',
        '--max-retries',
        '2',
        '-T4',
        '-oX',
        tempFile,
        target,
      ];
      
      ProcessResult result;
      if (_sessionPassword != null) {
        final process = await Process.start('sudo', ['-S', 'nmap', ...args]);
        process.stdin.writeln(_sessionPassword);
        await process.stdin.flush();
        await process.stdin.close();
        final stdout = await process.stdout.transform(utf8.decoder).join();
        final stderr = await process.stderr.transform(utf8.decoder).join();
        final exitCode = await process.exitCode;
        result = ProcessResult(process.pid, exitCode, stdout, stderr);
      } else {
        result = await Process.run('nmap', args.cast<String>());
      }

      if (result.exitCode == 0) {
        final xmlFile = File(tempFile);
        if (await xmlFile.exists()) {
          final xmlContent = await xmlFile.readAsString();
          try {
            if (_sessionPassword != null) {
              final delProcess = await Process.start('sudo', ['-S', 'rm', tempFile]);
              delProcess.stdin.writeln(_sessionPassword);
              await delProcess.stdin.close();
              await delProcess.exitCode;
            } else {
              await xmlFile.delete();
            }
          } catch (e) {
            // Ignore delete errors
          }
          return shelf.Response.ok(xmlContent);
        }
      }
      return shelf.Response.internalServerError(
        body: 'Nmap scan failed: ${result.stderr}',
      );
    } catch (e) {
      return shelf.Response.internalServerError(body: 'Scan error: $e');
    }
  }

  static Future<shelf.Response> _handleNmapProcessResults(
    Map<String, dynamic> body,
  ) async {
    try {
      final deviceId = body['deviceId'] as int;
      final projectId = body['projectId'] as int;
      final xmlContent = body['xmlContent'] as String;

      await NmapProcessor.processXmlContent(
        deviceId,
        projectId,
        xmlContent,
      );

      final vulnRepo = VulnerabilityRepository();
      await vulnRepo.updateVulnersCacheForDevice(deviceId);

      return _jsonResponse({'success': true});
    } catch (e) {
      return shelf.Response.internalServerError(
        body: json.encode({'error': 'Processing error: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  static Future<shelf.Response> _handleNmapScans(
    DatabaseHelper db,
    int projectId,
    bool replaceExisting,
  ) async {
    try {
      final deviceRepository = DeviceRepository();
      final devices = await deviceRepository.getDevicesRaw(projectId);

      // Start tracking progress
      final tracker = ScanProgressTracker();
      final taskId = tracker.startTask(
        projectId: projectId,
        scanType: 'nmap',
        totalDevices: devices.length,
      );

      // Run scans in background
      unawaited(_runNmapScansInBackground(
        db,
        taskId,
        projectId,
        devices,
        replaceExisting,
      ));

      return _jsonResponse({
        'taskId': taskId,
        'total': devices.length,
        'message': 'Nmap scans started',
      });
    } catch (e) {
      return _jsonResponse({
        'error': e.toString(),
      });
    }
  }

  static Future<void> _runNmapScansInBackground(
    DatabaseHelper db,
    String taskId,
    int projectId,
    List<Map<String, dynamic>> devices,
    bool replaceExisting,
  ) async {
    final tracker = ScanProgressTracker();
    final settingsRepo = SettingsRepository();
    final concurrency = await settingsRepo.getIntSetting('concurrent_scan_count', 3);
    final vulnerabilityRepository = VulnerabilityRepository();

    int completed = 0, failed = 0;
    int deviceIndex = 0;
    final activeScans = <int, Future<bool>>{};
    final activeDevices = <int, Map<String, dynamic>>{};

    // Helper function to scan a single device
    Future<bool> scanDevice(Map<String, dynamic> device) async {
      final scanRepository = ScanRepository();
      final deviceId = device['id'] as int;
      final ipAddress = device['ip_address'] as String;

      try {
        // Delete existing AUTO NMAP scans if replacing
        if (replaceExisting) {
          final scans = await scanRepository.getScansRaw(deviceId);
          final existingScans = scans.where((s) => s['name'] == 'AUTO NMAP').toList();
          for (final scan in existingScans) {
            await scanRepository.deleteScan(scan['id']);
          }
        }

        // Run nmap scan
        final tempFile = '/tmp/nmap_${deviceId}_${DateTime.now().millisecondsSinceEpoch}.xml';
        final args = [
          '-sV',
          '-O',
          '--script',
          'vulners,http-enum,http-devframework,http-title,http-server-header',
          '--host-timeout',
          '10m',
          '--max-retries',
          '2',
          '-T4',
          '-oX',
          tempFile,
          ipAddress,
        ];
        
        ProcessResult result;
        if (_sessionPassword != null) {
          final process = await Process.start('sudo', ['-S', 'nmap', ...args]);
          process.stdin.writeln(_sessionPassword);
          await process.stdin.flush();
          await process.stdin.close();
          final stdout = await process.stdout.transform(utf8.decoder).join();
          final stderr = await process.stderr.transform(utf8.decoder).join();
          final exitCode = await process.exitCode;
          result = ProcessResult(process.pid, exitCode, stdout, stderr);
        } else {
          result = await Process.run('nmap', args.cast<String>());
        }

        if (result.exitCode == 0) {
          final xmlFile = File(tempFile);
          if (await xmlFile.exists()) {
            final xmlContent = await xmlFile.readAsString();

            if (xmlContent.trim().isNotEmpty) {
              // Save scan to database
              await scanRepository.insertScan(
                deviceId,
                'AUTO NMAP',
                xmlContent,
              );

              // Process XML to extract nmap data (ports, scripts, OS, etc.)
              try {
                await NmapProcessor.processXmlContent(
                  deviceId,
                  projectId,
                  xmlContent,
                );

                // Update Vulners cache for this device
                await vulnerabilityRepository.updateVulnersCacheForDevice(deviceId);
              } catch (e) {
                print('Failed to process nmap results for device $deviceId: $e');
              }

              // Clean up temp file
              try {
                if (_sessionPassword != null) {
                  final delProcess = await Process.start('sudo', ['-S', 'rm', tempFile]);
                  delProcess.stdin.writeln(_sessionPassword);
                  await delProcess.stdin.close();
                  await delProcess.exitCode;
                } else {
                  await xmlFile.delete();
                }
              } catch (e) {
                // Ignore cleanup errors
              }

              return true;
            }
          }
        }
        return false;
      } catch (e) {
        return false;
      }
    }

    // Pool pattern: maintain exactly 'concurrency' active scans
    while (deviceIndex < devices.length || activeScans.isNotEmpty) {
      // Fill the pool up to concurrency limit
      while (activeScans.length < concurrency && deviceIndex < devices.length) {
        final device = devices[deviceIndex++];
        final deviceId = device['id'] as int;

        activeScans[deviceId] = scanDevice(device);
        activeDevices[deviceId] = device;

        // Update progress with all active devices
        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
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

        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
        );
      }
    }

    tracker.completeTask(taskId);
  }

  static Future<shelf.Response> _handleSnmpScans(
    DatabaseHelper db,
    int projectId,
    bool replaceExisting,
  ) async {
    try {
      final deviceRepository = DeviceRepository();
      final scanRepository = ScanRepository();
      final devices = await deviceRepository.getDevicesRaw(projectId);

      // Count total devices with SNMP ports
      int total = 0;
      final devicesWithSnmp = <Map<String, dynamic>>[];
      for (final device in devices) {
        final scans = await scanRepository.getScansRaw(device['id']);
        final nmapScan = scans.where((s) => s['name'] == 'AUTO NMAP').firstOrNull;
        if (nmapScan != null) {
          final hasSnmp = nmapScan['content'].toString().contains('161') ||
              nmapScan['content'].toString().contains('snmp');
          if (hasSnmp) {
            total++;
            devicesWithSnmp.add(device);
          }
        }
      }

      // Start tracking progress
      final tracker = ScanProgressTracker();
      final taskId = tracker.startTask(
        projectId: projectId,
        scanType: 'snmp',
        totalDevices: total,
      );

      // Run scans in background
      unawaited(_runSnmpScansInBackground(
        db,
        taskId,
        devicesWithSnmp,
        replaceExisting,
      ));

      return _jsonResponse({
        'taskId': taskId,
        'total': total,
        'message': 'SNMP scans started',
      });
    } catch (e) {
      return _jsonResponse({
        'error': e.toString(),
      });
    }
  }

  static Future<void> _runSnmpScansInBackground(
    DatabaseHelper db,
    String taskId,
    List<Map<String, dynamic>> devices,
    bool replaceExisting,
  ) async {
    final tracker = ScanProgressTracker();
    final settingsRepo = SettingsRepository();
    final concurrency = await settingsRepo.getIntSetting('concurrent_scan_count', 3);

    int completed = 0, failed = 0;
    int deviceIndex = 0;
    final activeScans = <int, Future<bool>>{};
    final activeDevices = <int, Map<String, dynamic>>{};

    // Helper function to scan a single device
    Future<bool> scanDevice(Map<String, dynamic> device) async {
      final scanRepository = ScanRepository();
      final snmpService = SnmpScanService();

      try {
        // Use nmap with SNMP scripts (same as desktop version)
        final tempFile = '/tmp/snmp_${device['id']}_${DateTime.now().millisecondsSinceEpoch}.xml';
        final args = [
          '-sU',
          '-p137,161',
          '--script',
          'snmp-*,snmp-win32-*,nbstat.nse',
          '--script-args',
          'snmpcommunity=public',
          '-T4',
          '--max-retries',
          '2',
          '--host-timeout',
          '5m',
          '-oX',
          tempFile,
          device['ip_address'],
        ];
        
        ProcessResult result;
        if (_sessionPassword != null) {
          final process = await Process.start('sudo', ['-S', 'nmap', ...args]);
          process.stdin.writeln(_sessionPassword);
          await process.stdin.flush();
          await process.stdin.close();
          final stdout = await process.stdout.transform(utf8.decoder).join();
          final stderr = await process.stderr.transform(utf8.decoder).join();
          final exitCode = await process.exitCode;
          result = ProcessResult(process.pid, exitCode, stdout, stderr);
        } else {
          result = await Process.run('nmap', args.cast<String>());
        }

        if (result.exitCode == 0) {
          final xmlFile = File(tempFile);
          if (await xmlFile.exists()) {
            final xmlContent = await xmlFile.readAsString();

            if (xmlContent.trim().isNotEmpty) {
              if (replaceExisting) {
                final scans = await scanRepository.getScansRaw(device['id']);
                final existingScans = scans.where((s) => s['name'] == 'SNMP AUTO').toList();
                for (final scan in existingScans) {
                  await scanRepository.deleteScan(scan['id']);
                }
              }
              await scanRepository.insertScan(
                device['id'],
                'SNMP AUTO',
                xmlContent,
              );

              // Process SNMP results to extract findings
              try {
                final projectRepository = ProjectRepository();
                final projects = await projectRepository.getProjectsRaw();
                for (final project in projects) {
                  final deviceRepository = DeviceRepository();
                  final projectDevices = await deviceRepository.getDevicesRaw(project['id']);
                  if (projectDevices.any((d) => d['id'] == device['id'])) {
                    await snmpService.processSnmpResults(device['id'], project['id'], xmlContent, db);
                    break;
                  }
                }
              } catch (e) {
                print('Failed to process SNMP results for device ${device['id']}: $e');
              }

              // Clean up temp file
              try {
                if (_sessionPassword != null) {
                  final delProcess = await Process.start('sudo', ['-S', 'rm', tempFile]);
                  delProcess.stdin.writeln(_sessionPassword);
                  await delProcess.stdin.close();
                  await delProcess.exitCode;
                } else {
                  await xmlFile.delete();
                }
              } catch (e) {
                // Ignore cleanup errors
              }

              return true;
            }
          }
        }
        return false;
      } catch (e) {
        return false;
      }
    }

    // Pool pattern: maintain exactly 'concurrency' active scans
    while (deviceIndex < devices.length || activeScans.isNotEmpty) {
      // Fill the pool up to concurrency limit
      while (activeScans.length < concurrency && deviceIndex < devices.length) {
        final device = devices[deviceIndex++];
        final deviceId = device['id'] as int;

        activeScans[deviceId] = scanDevice(device);
        activeDevices[deviceId] = device;

        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
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

        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
        );
      }
    }

    tracker.completeTask(taskId);
  }

  static Future<shelf.Response> _handleHasNmapResults(int projectId) async {
    try {
      final deviceRepository = DeviceRepository();
      final scanRepository = ScanRepository();
      final devices = await deviceRepository.getDevicesRaw(projectId);

      for (final device in devices) {
        final scans = await scanRepository.getScansRaw(device['id']);
        if (scans.any((s) => s['name'] == 'AUTO NMAP')) {
          return _jsonResponse({'hasResults': true});
        }
      }
      return _jsonResponse({'hasResults': false});
    } catch (e) {
      return _jsonResponse({'hasResults': false});
    }
  }

  static Future<shelf.Response> _handleNiktoScans(
    DatabaseHelper db,
    int projectId,
    bool replaceExisting,
  ) async {
    try {
      final deviceRepository = DeviceRepository();
      final scanRepository = ScanRepository();
      final devices = await deviceRepository.getDevicesRaw(projectId);

      // Count total devices with HTTP ports
      int total = 0;
      final devicesWithHttpPorts = <Map<String, dynamic>>[];
      for (final device in devices) {
        final scans = await scanRepository.getScansRaw(device['id']);
        final nmapScan = scans.where((s) => s['name'] == 'AUTO NMAP').firstOrNull;
        if (nmapScan != null) {
          final ports = await _extractHttpPorts(nmapScan['content']);
          if (ports.isNotEmpty) {
            total++;
            devicesWithHttpPorts.add(device);
          }
        }
      }

      // Start tracking progress
      final tracker = ScanProgressTracker();
      final taskId = tracker.startTask(
        projectId: projectId,
        scanType: 'nikto',
        totalDevices: total,
      );

      // Run scans in background
      unawaited(_runNiktoScansInBackground(
        db,
        taskId,
        devicesWithHttpPorts,
        replaceExisting,
      ));

      // Return task ID immediately
      return _jsonResponse({
        'taskId': taskId,
        'total': total,
        'message': 'Nikto scans started',
      });
    } catch (e) {
      return _jsonResponse({
        'error': e.toString(),
      });
    }
  }

  static Future<void> _runNiktoScansInBackground(
    DatabaseHelper db,
    String taskId,
    List<Map<String, dynamic>> devices,
    bool replaceExisting,
  ) async {
    final tracker = ScanProgressTracker();
    final settingsRepo = SettingsRepository();
    final concurrency = await settingsRepo.getIntSetting('concurrent_scan_count', 3);

    int completed = 0, failed = 0;
    int deviceIndex = 0;
    final activeScans = <int, Future<shelf.Response>>{};
    final activeDevices = <int, Map<String, dynamic>>{};

    // Pool pattern: maintain exactly 'concurrency' active scans
    while (deviceIndex < devices.length || activeScans.isNotEmpty) {
      // Fill the pool up to concurrency limit
      while (activeScans.length < concurrency && deviceIndex < devices.length) {
        final device = devices[deviceIndex++];
        final deviceId = device['id'] as int;

        activeScans[deviceId] = _handleDeviceNiktoScan(db, deviceId, {
          'replace': replaceExisting,
        });
        activeDevices[deviceId] = device;

        // Update progress with all active devices
        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
        );
      }

      // If there are active scans, wait for any one to complete
      if (activeScans.isNotEmpty) {
        final completedEntry = await Future.any(
          activeScans.entries.map((entry) =>
            entry.value.then((response) => MapEntry(entry.key, response))
          ),
        );

        final deviceId = completedEntry.key;
        final response = completedEntry.value;

        if (response.statusCode == 200) {
          completed++;
        } else {
          failed++;
        }

        activeScans.remove(deviceId);
        activeDevices.remove(deviceId);

        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
        );
      }
    }

    tracker.completeTask(taskId);
  }

  static Future<shelf.Response> _handleSearchsploitScans(
    DatabaseHelper db,
    int projectId,
    bool replaceExisting,
  ) async {
    try {
      final deviceRepository = DeviceRepository();
      final devices = await deviceRepository.getDevicesRaw(projectId);

      // Start tracking progress
      final tracker = ScanProgressTracker();
      final taskId = tracker.startTask(
        projectId: projectId,
        scanType: 'searchsploit',
        totalDevices: devices.length,
      );

      // Run scans in background
      unawaited(_runSearchsploitScansInBackground(
        db,
        taskId,
        devices,
        replaceExisting,
      ));

      return _jsonResponse({
        'taskId': taskId,
        'total': devices.length,
        'message': 'SearchSploit scans started',
      });
    } catch (e) {
      return _jsonResponse({
        'error': e.toString(),
      });
    }
  }

  static Future<void> _runSearchsploitScansInBackground(
    DatabaseHelper db,
    String taskId,
    List<Map<String, dynamic>> devices,
    bool replaceExisting,
  ) async {
    final tracker = ScanProgressTracker();
    final settingsRepo = SettingsRepository();
    final concurrency = await settingsRepo.getIntSetting('concurrent_scan_count', 3);

    int completed = 0, failed = 0;
    int deviceIndex = 0;
    final activeScans = <int, Future<shelf.Response>>{};
    final activeDevices = <int, Map<String, dynamic>>{};

    while (deviceIndex < devices.length || activeScans.isNotEmpty) {
      while (activeScans.length < concurrency && deviceIndex < devices.length) {
        final device = devices[deviceIndex++];
        final deviceId = device['id'] as int;

        activeScans[deviceId] = _handleDeviceSearchsploitScan(db, deviceId, {
          'replace': replaceExisting,
        });
        activeDevices[deviceId] = device;

        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
        );
      }

      if (activeScans.isNotEmpty) {
        final completedEntry = await Future.any(
          activeScans.entries.map((entry) =>
            entry.value.then((response) => MapEntry(entry.key, response))
          ),
        );

        final deviceId = completedEntry.key;
        final response = completedEntry.value;

        if (response.statusCode == 200) {
          completed++;
        } else {
          failed++;
        }

        activeScans.remove(deviceId);
        activeDevices.remove(deviceId);

        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
        );
      }
    }

    tracker.completeTask(taskId);
  }

  static Future<shelf.Response> _handleWhatwebScans(
    DatabaseHelper db,
    int projectId,
    bool replaceExisting,
  ) async {
    try {
      final deviceRepository = DeviceRepository();
      final devices = await deviceRepository.getDevicesRaw(projectId);

      // Start tracking progress
      final tracker = ScanProgressTracker();
      final taskId = tracker.startTask(
        projectId: projectId,
        scanType: 'whatweb',
        totalDevices: devices.length,
      );

      // Run scans in background
      unawaited(_runWhatwebScansInBackground(
        db,
        taskId,
        devices,
        replaceExisting,
      ));

      return _jsonResponse({
        'taskId': taskId,
        'total': devices.length,
        'message': 'WhatWeb scans started',
      });
    } catch (e) {
      return _jsonResponse({
        'error': e.toString(),
      });
    }
  }

  static Future<void> _runWhatwebScansInBackground(
    DatabaseHelper db,
    String taskId,
    List<Map<String, dynamic>> devices,
    bool replaceExisting,
  ) async {
    final tracker = ScanProgressTracker();
    final settingsRepo = SettingsRepository();
    final concurrency = await settingsRepo.getIntSetting('concurrent_scan_count', 3);

    int completed = 0, failed = 0;
    int deviceIndex = 0;
    final activeScans = <int, Future<shelf.Response>>{};
    final activeDevices = <int, Map<String, dynamic>>{};

    while (deviceIndex < devices.length || activeScans.isNotEmpty) {
      while (activeScans.length < concurrency && deviceIndex < devices.length) {
        final device = devices[deviceIndex++];
        final deviceId = device['id'] as int;

        activeScans[deviceId] = _handleDeviceWhatwebScan(db, deviceId, {
          'replace': replaceExisting,
        });
        activeDevices[deviceId] = device;

        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
        );
      }

      if (activeScans.isNotEmpty) {
        final completedEntry = await Future.any(
          activeScans.entries.map((entry) =>
            entry.value.then((response) => MapEntry(entry.key, response))
          ),
        );

        final deviceId = completedEntry.key;
        final response = completedEntry.value;

        if (response.statusCode == 200) {
          completed++;
        } else {
          failed++;
        }

        activeScans.remove(deviceId);
        activeDevices.remove(deviceId);

        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
        );
      }
    }

    tracker.completeTask(taskId);
  }

  static Future<shelf.Response> _handleFfufScans(
    DatabaseHelper db,
    int projectId,
    bool replaceExisting,
  ) async {
    try {
      final deviceRepository = DeviceRepository();
      final scanRepository = ScanRepository();
      final devices = await deviceRepository.getDevicesRaw(projectId);

      // Count total devices with HTTP ports
      int total = 0;
      final devicesWithHttpPorts = <Map<String, dynamic>>[];
      for (final device in devices) {
        final scans = await scanRepository.getScansRaw(device['id']);
        final nmapScan = scans.where((s) => s['name'] == 'AUTO NMAP').firstOrNull;
        if (nmapScan != null) {
          final ports = await _extractHttpPorts(nmapScan['content']);
          if (ports.isNotEmpty) {
            total++;
            devicesWithHttpPorts.add(device);
          }
        }
      }

      // Start tracking progress
      final tracker = ScanProgressTracker();
      final taskId = tracker.startTask(
        projectId: projectId,
        scanType: 'ffuf',
        totalDevices: total,
      );

      // Run scans in background
      unawaited(_runFfufScansInBackground(
        db,
        taskId,
        devicesWithHttpPorts,
        replaceExisting,
      ));

      return _jsonResponse({
        'taskId': taskId,
        'total': total,
        'message': 'FFUF scans started',
      });
    } catch (e) {
      return _jsonResponse({
        'error': e.toString(),
      });
    }
  }

  static Future<void> _runFfufScansInBackground(
    DatabaseHelper db,
    String taskId,
    List<Map<String, dynamic>> devices,
    bool replaceExisting,
  ) async {
    final tracker = ScanProgressTracker();
    final settingsRepo = SettingsRepository();
    final concurrency = await settingsRepo.getIntSetting('concurrent_scan_count', 3);

    int completed = 0, failed = 0;
    int deviceIndex = 0;
    final activeScans = <int, Future<shelf.Response>>{};
    final activeDevices = <int, Map<String, dynamic>>{};

    while (deviceIndex < devices.length || activeScans.isNotEmpty) {
      while (activeScans.length < concurrency && deviceIndex < devices.length) {
        final device = devices[deviceIndex++];
        final deviceId = device['id'] as int;

        activeScans[deviceId] = _handleDeviceFfufScan(db, deviceId, {
          'replace': replaceExisting,
        });
        activeDevices[deviceId] = device;

        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
        );
      }

      if (activeScans.isNotEmpty) {
        final completedEntry = await Future.any(
          activeScans.entries.map((entry) =>
            entry.value.then((response) => MapEntry(entry.key, response))
          ),
        );

        final deviceId = completedEntry.key;
        final response = completedEntry.value;

        if (response.statusCode == 200) {
          completed++;
        } else {
          failed++;
        }

        activeScans.remove(deviceId);
        activeDevices.remove(deviceId);

        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
        );
      }
    }

    tracker.completeTask(taskId);
  }

  static Future<shelf.Response> _handleEnum4linuxScans(
    DatabaseHelper db,
    int projectId,
    bool replaceExisting,
  ) async {
    try {
      final deviceRepository = DeviceRepository();
      final scanRepository = ScanRepository();
      final devices = await deviceRepository.getDevicesRaw(projectId);

      // Count total devices with SMB/LDAP ports
      int total = 0;
      final devicesWithSmbLdap = <Map<String, dynamic>>[];
      for (final device in devices) {
        final scans = await scanRepository.getScansRaw(device['id']);
        final nmapScan = scans.where((s) => s['name'] == 'AUTO NMAP').firstOrNull;
        if (nmapScan != null) {
          final ports = await _extractSmbLdapPorts(nmapScan['content']);
          if (ports.isNotEmpty) {
            total++;
            devicesWithSmbLdap.add(device);
          }
        }
      }

      // Start tracking progress
      final tracker = ScanProgressTracker();
      final taskId = tracker.startTask(
        projectId: projectId,
        scanType: 'enum4linux',
        totalDevices: total,
      );

      // Run scans in background
      unawaited(_runEnum4linuxScansInBackground(
        db,
        taskId,
        devicesWithSmbLdap,
        replaceExisting,
      ));

      return _jsonResponse({
        'taskId': taskId,
        'total': total,
        'message': 'Enum4Linux scans started',
      });
    } catch (e) {
      return _jsonResponse({
        'error': e.toString(),
      });
    }
  }

  static Future<void> _runEnum4linuxScansInBackground(
    DatabaseHelper db,
    String taskId,
    List<Map<String, dynamic>> devices,
    bool replaceExisting,
  ) async {
    final tracker = ScanProgressTracker();
    final settingsRepo = SettingsRepository();
    final concurrency = await settingsRepo.getIntSetting('concurrent_scan_count', 3);

    int completed = 0, failed = 0;
    int deviceIndex = 0;
    final activeScans = <int, Future<shelf.Response>>{};
    final activeDevices = <int, Map<String, dynamic>>{};

    while (deviceIndex < devices.length || activeScans.isNotEmpty) {
      while (activeScans.length < concurrency && deviceIndex < devices.length) {
        final device = devices[deviceIndex++];
        final deviceId = device['id'] as int;

        activeScans[deviceId] = _handleDeviceEnum4linuxScan(db, deviceId, {
          'replace': replaceExisting,
        });
        activeDevices[deviceId] = device;

        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
        );
      }

      if (activeScans.isNotEmpty) {
        final completedEntry = await Future.any(
          activeScans.entries.map((entry) =>
            entry.value.then((response) => MapEntry(entry.key, response))
          ),
        );

        final deviceId = completedEntry.key;
        final response = completedEntry.value;

        if (response.statusCode == 200) {
          completed++;
        } else {
          failed++;
        }

        activeScans.remove(deviceId);
        activeDevices.remove(deviceId);

        tracker.updateProgress(
          taskId: taskId,
          currentDevice: activeDevices.values.map((d) => d['ip_address'] as String).join(', '),
          completed: completed,
          failed: failed,
        );
      }
    }

    tracker.completeTask(taskId);
  }

  static Future<shelf.Response> _handleDeviceNiktoScan(
    DatabaseHelper db,
    int deviceId,
    Map<String, dynamic> body,
  ) async {
    try {
      final replace = body['replace'] as bool? ?? true;
      final scanRepository = ScanRepository();

      if (replace) {
        await scanRepository.deleteNiktoAutoScans(deviceId);
      }

      final scans = await scanRepository.getScansRaw(deviceId);
      final nmapScan = scans.where((s) => s['name'] == 'AUTO NMAP').firstOrNull;
      if (nmapScan == null) {
        return _jsonResponse({
          'success': false,
          'error': 'No AUTO NMAP scan found',
        });
      }

      final device = await _getDeviceInfo(deviceId);
      if (device == null) {
        return _jsonResponse({'success': false, 'error': 'Device not found'});
      }

      final ports = await _extractHttpPorts(nmapScan['content']);
      if (ports.isEmpty) {
        return _jsonResponse({
          'success': false,
          'error': 'No HTTP ports found',
        });
      }

      final niktoService = NiktoScanService();
      final sslPorts = ports.where((p) => p == '443' || p == '8443').toList();
      final nonSslPorts = ports.where((p) => p != '443' && p != '8443').toList();

      String combinedResult = '';
      if (nonSslPorts.isNotEmpty) {
        final result = await niktoService.runNiktoScan(
          device['ip_address'],
          nonSslPorts.join(','),
          false,
        );
        combinedResult += result;
      }
      if (sslPorts.isNotEmpty) {
        final result = await niktoService.runNiktoScan(
          device['ip_address'],
          sslPorts.join(','),
          true,
        );
        if (combinedResult.isNotEmpty) {
          combinedResult += '\n\n<!-- SSL SCAN RESULTS -->\n\n';
        }
        combinedResult += result;
      }

      await scanRepository.insertScan(deviceId, 'NIKTO AUTO', combinedResult);

      // Parse and store Nikto findings
      if (combinedResult.isNotEmpty) {
        try {
          await niktoService.parseAndStoreResults(deviceId, combinedResult);
        } catch (e) {
          print('Failed to parse Nikto results: $e');
        }
      }

      return _jsonResponse({'success': true});
    } catch (e) {
      return _jsonResponse({'success': false, 'error': e.toString()});
    }
  }

  static Future<shelf.Response> _handleDeviceSearchsploitScan(
    DatabaseHelper db,
    int deviceId,
    Map<String, dynamic> body,
  ) async {
    try {
      final replace = body['replace'] as bool? ?? true;
      final scanRepository = ScanRepository();

      if (replace) {
        await scanRepository.deleteSearchsploitAutoScans(deviceId);
      }

      final scans = await scanRepository.getScansRaw(deviceId);
      final nmapScan = scans.where((s) => s['name'] == 'AUTO NMAP').firstOrNull;
      if (nmapScan == null) {
        return _jsonResponse({
          'success': false,
          'error': 'No AUTO NMAP scan found',
        });
      }

      final searchsploitService = SearchsploitScanService();
      final result = await searchsploitService.runSearchsploitScan(
        nmapScan['content'],
      );
      await scanRepository.insertScan(deviceId, 'AUTO SEARCHSPLOIT', result);
      await searchsploitService.parseAndStoreResults(deviceId, result);

      return _jsonResponse({'success': true});
    } catch (e) {
      return _jsonResponse({'success': false, 'error': e.toString()});
    }
  }

  static Future<shelf.Response> _handleDeviceWhatwebScan(
    DatabaseHelper db,
    int deviceId,
    Map<String, dynamic> body,
  ) async {
    try {
      final replace = body['replace'] as bool? ?? true;
      final scanRepository = ScanRepository();

      if (replace) {
        await scanRepository.deleteWhatwebAutoScans(deviceId);
      }

      final scans = await scanRepository.getScansRaw(deviceId);
      final nmapScan = scans.where((s) => s['name'] == 'AUTO NMAP').firstOrNull;
      if (nmapScan == null) {
        return _jsonResponse({
          'success': false,
          'error': 'No AUTO NMAP scan found',
        });
      }

      final device = await _getDeviceInfo(deviceId);
      if (device == null) {
        return _jsonResponse({'success': false, 'error': 'Device not found'});
      }

      final whatwebService = WhatwebScanService();
      final httpPorts = await whatwebService.parseNmapForHttpPorts(
        nmapScan['content'],
        device['ip_address'],
      );

      if (httpPorts.isEmpty) {
        return _jsonResponse({'success': true});
      }

      String combinedResult = '';
      for (final portInfo in httpPorts) {
        final result = await whatwebService.runWhatwebScan(portInfo);
        if (combinedResult.isNotEmpty) combinedResult += '\n\n';
        combinedResult += result;
      }

      if (combinedResult.isNotEmpty) {
        await scanRepository.insertScan(deviceId, 'AUTO WHATWEB', combinedResult);
        await whatwebService.parseAndStoreResults(deviceId, combinedResult);
      }

      return _jsonResponse({'success': true});
    } catch (e) {
      return _jsonResponse({'success': false, 'error': e.toString()});
    }
  }

  static Future<shelf.Response> _handleDeviceEnum4linuxScan(
    DatabaseHelper db,
    int deviceId,
    Map<String, dynamic> body,
  ) async {
    try {
      final replace = body['replace'] as bool? ?? true;
      final scanRepository = ScanRepository();

      if (replace) {
        await scanRepository.deleteSambaLdapAutoScans(deviceId);
      }

      final device = await _getDeviceInfo(deviceId);
      if (device == null) {
        return _jsonResponse({'success': false, 'error': 'Device not found'});
      }

      final enum4linuxService = Enum4linuxScanService();
      final result = await enum4linuxService.runEnum4linuxScan(
        device['ip_address'],
      );
      await scanRepository.insertScan(deviceId, 'AUTO SAMBA/LDAP', result);
      await enum4linuxService.parseAndStoreResults(deviceId, result);

      return _jsonResponse({'success': true});
    } catch (e) {
      return _jsonResponse({'success': false, 'error': e.toString()});
    }
  }

  static Future<shelf.Response> _handleDeviceFfufScan(
    DatabaseHelper db,
    int deviceId,
    Map<String, dynamic> body,
  ) async {
    try {
      final replace = body['replace'] as bool? ?? true;
      final scanRepository = ScanRepository();

      if (replace) {
        await scanRepository.deleteFfufAutoScans(deviceId);
      }

      final scans = await scanRepository.getScansRaw(deviceId);
      final nmapScan = scans.where((s) => s['name'] == 'AUTO NMAP').firstOrNull;
      if (nmapScan == null) {
        return _jsonResponse({
          'success': false,
          'error': 'No AUTO NMAP scan found',
        });
      }

      final device = await _getDeviceInfo(deviceId);
      if (device == null) {
        return _jsonResponse({'success': false, 'error': 'Device not found'});
      }

      final ports = await _extractHttpPorts(nmapScan['content']);
      if (ports.isEmpty) {
        return _jsonResponse({
          'success': false,
          'error': 'No HTTP ports found',
        });
      }

      final ffufService = FfufScanService();
      String combinedResult = '';

      for (final port in ports) {
        final result = await ffufService.runFfufScan(
          device['ip_address'],
          port,
        );
        if (combinedResult.isNotEmpty) {
          combinedResult += '\n\n<!-- PORT $port SCAN RESULTS -->\n\n';
        }
        combinedResult += result;
      }

      if (combinedResult.isNotEmpty) {
        await scanRepository.insertScan(deviceId, 'AUTO FUZZER', combinedResult);
        await ffufService.parseAndStoreResults(deviceId, combinedResult);
      }

      return _jsonResponse({'success': true});
    } catch (e) {
      return _jsonResponse({'success': false, 'error': e.toString()});
    }
  }

  static Future<shelf.Response> _handleDeviceSnmpScan(
    DatabaseHelper db,
    int deviceId,
    Map<String, dynamic> body,
  ) async {
    try {
      print('═══════════════════════════════════════════════════════');
      print('[SNMP DEBUG] Starting SNMP scan for device $deviceId');
      print('[SNMP DEBUG] Request body: $body');
      print('═══════════════════════════════════════════════════════');

      final replace = body['replace'] as bool? ?? true;
      final scanRepository = ScanRepository();

      final device = await _getDeviceInfo(deviceId);
      if (device == null) {
        print('[SNMP DEBUG] ❌ ERROR: Device not found: $deviceId');
        return _jsonResponse({'success': false, 'error': 'Device not found'});
      }
      print('[SNMP DEBUG] ✓ Device found: ${device['ip_address']}');
      print('[SNMP DEBUG] ✓ Device name: ${device['name']}');

      // Check if device has SNMP open (typically UDP 161/162)
      // We'll try the scan regardless as UDP port detection can be unreliable

      if (replace) {
        final scans = await scanRepository.getScansRaw(deviceId);
        final existingScans = scans.where((s) => s['name'] == 'SNMP AUTO').toList();
        print('[SNMP DEBUG] Found ${existingScans.length} existing SNMP scans to delete');
        for (final scan in existingScans) {
          await scanRepository.deleteScan(scan['id']);
        }
      }

      // Build the full command - Use nmap with SNMP scripts (same as desktop version)
      // Desktop version uses: nmap -sU -p137,161 --script snmp-*,snmp-win32-*,nbstat.nse
      final tempFile = '/tmp/snmp_${deviceId}_${DateTime.now().millisecondsSinceEpoch}.xml';
      final command = 'nmap';
      final args = <String>[
        '-sU',
        '-p137,161',
        '--script',
        'snmp-*,snmp-win32-*,nbstat.nse',
        '--script-args',
        'snmpcommunity=public',
        '-T4',
        '--max-retries',
        '2',
        '--host-timeout',
        '5m',
        '-oX',
        tempFile,
        device['ip_address'] as String,
      ];
      final fullCommand = '$command ${args.join(' ')}';

      print('');
      print('[SNMP DEBUG] ═══ EXECUTING COMMAND ═══');
      print('[SNMP DEBUG] Full command: $fullCommand');
      print('[SNMP DEBUG] Output file: $tempFile');
      print('[SNMP DEBUG] Working directory: ${Directory.current.path}');
      print('[SNMP DEBUG] Platform: ${Platform.operatingSystem}');
      print('[SNMP DEBUG] ═══════════════════════════');
      print('');

      // Run SNMP scan using nmap with SNMP scripts
      final stopwatch = Stopwatch()..start();
      ProcessResult result;
      if (_sessionPassword != null) {
        final process = await Process.start('sudo', ['-S', command, ...args]);
        process.stdin.writeln(_sessionPassword);
        await process.stdin.flush();
        await process.stdin.close();
        final stdout = await process.stdout.transform(utf8.decoder).join();
        final stderr = await process.stderr.transform(utf8.decoder).join();
        final exitCode = await process.exitCode;
        result = ProcessResult(process.pid, exitCode, stdout, stderr);
      } else {
        result = await Process.run(command, args);
      }
      stopwatch.stop();

      print('');
      print('[SNMP DEBUG] ═══ COMMAND COMPLETED ═══');
      print('[SNMP DEBUG] Execution time: ${stopwatch.elapsedMilliseconds}ms');
      print('[SNMP DEBUG] Exit code: ${result.exitCode}');
      print('[SNMP DEBUG] ═══════════════════════════');
      print('');

      final stdout = result.stdout.toString();
      final stderr = result.stderr.toString();

      print('[SNMP DEBUG] ═══ STDOUT (length: ${stdout.length} chars) ═══');
      if (stdout.isEmpty) {
        print('[SNMP DEBUG] ⚠️  STDOUT IS EMPTY');
      } else {
        // Print first 500 chars of stdout
        final previewLength = stdout.length > 500 ? 500 : stdout.length;
        print('[SNMP DEBUG] First $previewLength characters:');
        print(stdout.substring(0, previewLength));
        if (stdout.length > 500) {
          print('[SNMP DEBUG] ... (truncated, full length: ${stdout.length} chars)');
        }
      }
      print('');

      print('[SNMP DEBUG] ═══ STDERR (length: ${stderr.length} chars) ═══');
      if (stderr.isEmpty) {
        print('[SNMP DEBUG] ✓ No errors in stderr');
      } else {
        print('[SNMP DEBUG] ⚠️  STDERR CONTENT:');
        print(stderr);
      }
      print('');

      // Check if the XML file was created
      final xmlFile = File(tempFile);
      final fileExists = await xmlFile.exists();
      print('[SNMP DEBUG] XML file exists: $fileExists');

      if (fileExists) {
        final xmlContent = await xmlFile.readAsString();
        print('[SNMP DEBUG] XML file size: ${xmlContent.length} bytes');

        // Print first 500 chars of XML
        if (xmlContent.isNotEmpty) {
          final previewLength = xmlContent.length > 500 ? 500 : xmlContent.length;
          print('[SNMP DEBUG] First $previewLength bytes of XML:');
          print(xmlContent.substring(0, previewLength));
          if (xmlContent.length > 500) {
            print('[SNMP DEBUG] ... (truncated)');
          }
        }

        // Check if scan was successful
        if (result.exitCode == 0 && xmlContent.trim().isNotEmpty) {
          print('[SNMP DEBUG] ═══ SCAN SUCCESSFUL ═══');
          print('[SNMP DEBUG] Inserting ${xmlContent.length} chars into database');

          await scanRepository.insertScan(
            deviceId,
            'SNMP AUTO',
            xmlContent,
          );

          // Process SNMP results to extract findings
          try {
            final snmpService = SnmpScanService();
            // Get project ID for this device
            final deviceInfo = await _getDeviceInfo(deviceId);
            if (deviceInfo != null) {
              final projectRepository = ProjectRepository();
              final projects = await projectRepository.getProjectsRaw();
              for (final project in projects) {
                final deviceRepository = DeviceRepository();
                final devices = await deviceRepository.getDevicesRaw(project['id']);
                if (devices.any((d) => d['id'] == deviceId)) {
                  await snmpService.processSnmpResults(deviceId, project['id'], xmlContent, db);
                  print('[SNMP DEBUG] ✓ Successfully processed SNMP results');
                  break;
                }
              }
            }
          } catch (e) {
            print('[SNMP DEBUG] ⚠️  Failed to process SNMP results: $e');
          }

          // Clean up temp file
          try {
            if (_sessionPassword != null) {
              final delProcess = await Process.start('sudo', ['-S', 'rm', tempFile]);
              delProcess.stdin.writeln(_sessionPassword);
              await delProcess.stdin.close();
              await delProcess.exitCode;
            } else {
              await xmlFile.delete();
            }
            print('[SNMP DEBUG] ✓ Deleted temp file: $tempFile');
          } catch (e) {
            print('[SNMP DEBUG] ⚠️  Could not delete temp file: $e');
          }

          print('[SNMP DEBUG] ✓ Successfully stored scan results in database');
          print('[SNMP DEBUG] ═══════════════════════════════════════════════');
          return _jsonResponse({'success': true});
        } else {
          // Clean up temp file on failure
          try {
            if (_sessionPassword != null) {
              final delProcess = await Process.start('sudo', ['-S', 'rm', tempFile]);
              delProcess.stdin.writeln(_sessionPassword);
              await delProcess.stdin.close();
              await delProcess.exitCode;
            } else {
              await xmlFile.delete();
            }
          } catch (e) {
            // Ignore cleanup errors
          }

          print('[SNMP DEBUG] ═══ SCAN FAILED ═══');
          print('[SNMP DEBUG] Exit code: ${result.exitCode}');
          print('[SNMP DEBUG] XML content empty: ${xmlContent.trim().isEmpty}');
          print('[SNMP DEBUG] ═══════════════════════════════════════════════');

          return _jsonResponse({
            'success': false,
            'error': 'SNMP scan failed or no SNMP service available.\n'
                'Exit code: ${result.exitCode}\n'
                'Command: $fullCommand\n'
                'STDERR: ${stderr.isEmpty ? "(empty)" : stderr}\n'
                'XML file size: ${xmlContent.length}',
          });
        }
      } else {
        print('[SNMP DEBUG] ═══ SCAN FAILED ═══');
        print('[SNMP DEBUG] XML file was not created: $tempFile');
        print('[SNMP DEBUG] Exit code: ${result.exitCode}');
        print('[SNMP DEBUG] ═══════════════════════════════════════════════');

        return _jsonResponse({
          'success': false,
          'error': 'SNMP scan failed - XML file not created.\n'
              'Exit code: ${result.exitCode}\n'
              'Command: $fullCommand\n'
              'STDERR: ${stderr.isEmpty ? "(empty)" : stderr}',
        });
      }
    } catch (e, stackTrace) {
      print('[SNMP DEBUG] ═══ EXCEPTION OCCURRED ═══');
      print('[SNMP DEBUG] Exception: $e');
      print('[SNMP DEBUG] Stack trace:');
      print(stackTrace);
      print('[SNMP DEBUG] ═══════════════════════════════════════════════');
      return _jsonResponse({'success': false, 'error': e.toString()});
    }
  }

  static Future<shelf.Response> _scanHosts(int projectId, String target) async {
    try {
      ProcessResult result;
      if (_sessionPassword != null) {
        final process = await Process.start('sudo', ['-S', 'nmap', '-sn', target]);
        process.stdin.writeln(_sessionPassword);
        await process.stdin.flush();
        await process.stdin.close();
        final stdout = await process.stdout.transform(utf8.decoder).join();
        final stderr = await process.stderr.transform(utf8.decoder).join();
        final exitCode = await process.exitCode;
        result = ProcessResult(process.pid, exitCode, stdout, stderr);
      } else {
        result = await Process.run('nmap', ['-sn', target]);
      }

      if (result.exitCode != 0) {
        return _jsonResponse({
          'success': false,
          'error': 'Scan failed: ${result.stderr}',
        });
      }

      final output = result.stdout as String;
      final lines = output.split('\n');
      final devices = <Map<String, String>>[];

      for (final line in lines) {
        if (line.startsWith('Nmap scan report for ')) {
          final parts = line.substring('Nmap scan report for '.length).split(' ');
          String hostname = 'Unknown';
          String ip = '';

          if (parts.length > 1 &&
              parts[1].startsWith('(') &&
              parts[1].endsWith(')')) {
            hostname = parts[0];
            ip = parts[1].substring(1, parts[1].length - 1);
          } else {
            ip = parts[0];
            hostname = ip;
          }

          if (ip.isNotEmpty) {
            final deviceRepository = DeviceRepository();
            final deviceId = await deviceRepository.insertDevice(
              projectId,
              hostname,
              ip,
            );
            devices.add({
              'id': deviceId.toString(),
              'name': hostname,
              'ip': ip,
            });
          }
        }
      }

      return _jsonResponse({
        'success': true,
        'devices': devices,
        'count': devices.length,
      });
    } catch (e) {
      return _jsonResponse({'success': false, 'error': e.toString()});
    }
  }

  static Future<Map<String, dynamic>?> _getDeviceInfo(int deviceId) async {
    final projectRepository = ProjectRepository();
    final deviceRepository = DeviceRepository();
    final projects = await projectRepository.getProjectsRaw();
    for (final project in projects) {
      final devices = await deviceRepository.getDevicesRaw(project['id']);
      final device = devices.where((d) => d['id'] == deviceId).firstOrNull;
      if (device != null) return device;
    }
    return null;
  }

  static Future<List<String>> _extractHttpPorts(String nmapXml) async {
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

  static Future<List<String>> _extractSmbLdapPorts(String nmapXml) async {
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

  static shelf.Response _jsonResponse(dynamic data) {
    return shelf.Response.ok(
      json.encode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static shelf.Response _handleGetTaskProgress(String taskId) {
    final tracker = ScanProgressTracker();
    final progress = tracker.getProgress(taskId);

    if (progress == null) {
      return shelf.Response.notFound(
        json.encode({'error': 'Task not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return _jsonResponse(progress.toJson());
  }
}
