import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/services/config_service.dart';
import 'package:penpeeper/services/command_path_resolver.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'package:penpeeper/utils/debug_logger.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/utils/privileged_runner.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:penpeeper/database_helper.dart';

class SnmpScanService {
  final _pathResolver = CommandPathResolver();
  final _logger = DebugLogger();
  final Set<Process> _activeProcesses = {};

  Set<Process> get activeProcesses => _activeProcesses;

  Future<void> killAllProcesses() async {
    for (final process in _activeProcesses) {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (e) {
        await _logger.logError('SNMP_KILL', 'Failed to kill process: $e');
      }
    }
    _activeProcesses.clear();
  }

  Future<String> runSnmpScan(String target, [String? uniqueId]) async {
    await _logger.log('SNMP_SCAN', '========== STARTING SNMP SCAN ==========');
    await _logger.log('SNMP_SCAN', 'Target: $target');
    await _logger.log('SNMP_SCAN', 'UniqueId: ${uniqueId ?? "none"}');
    await _logger.flush();

    if (kIsWeb) {
      await _logger.log('SNMP_SCAN', 'Running in web mode');
      final response = await http.post(
        Uri.parse('/api/snmp/scan'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'target': target, 'uniqueId': uniqueId}),
      );
      if (response.statusCode != 200) {
        throw Exception('SNMP scan failed: ${response.body}');
      }
      return response.body;
    }

    await _logger.log('SNMP_SCAN', 'Running in desktop mode');
    await _logger.log('SNMP_SCAN', 'Platform: ${Platform.operatingSystem}');
    await _logger.flush();

    final pathsService = AppPathsService();
    final tempFile = pathsService.getTempScanPath('temp_snmp_${uniqueId ?? ""}', 'xml');

    await _logger.log('SNMP_SCAN', 'Temp file path: $tempFile');
    await _logger.flush();

    // Check if temp directory exists
    final tempDir = Directory(pathsService.tempScanDir);
    final tempDirExists = await tempDir.exists();
    await _logger.log('SNMP_SCAN', 'Temp directory exists: $tempDirExists');
    await _logger.log('SNMP_SCAN', 'Temp directory path: ${pathsService.tempScanDir}');
    if (!tempDirExists) {
      await _logger.log('SNMP_SCAN', 'WARNING: Temp directory does not exist! Creating it...');
      try {
        await tempDir.create(recursive: true);
        await _logger.log('SNMP_SCAN', 'Temp directory created successfully');
      } catch (e) {
        await _logger.logError('SNMP_SCAN', 'Failed to create temp directory: $e');
      }
    }
    await _logger.flush();

    String command;
    List<String> args;

    if (ConfigService.isLinux || ConfigService.isMacOS || ConfigService.isWindows) {
      await _logger.log('SNMP_SCAN', 'Resolving nmap command path...');
      await _logger.flush();
      try {
        command = await _pathResolver.requireCommandPath('nmap');
        await _logger.log('SNMP_SCAN', 'Nmap command resolved to: $command');
        await _logger.flush();
      } catch (e) {
        await _logger.logError('SNMP_SCAN', 'Failed to resolve nmap path: $e');
        await _logger.flush();
        rethrow;
      }

      args = [
        '-sU',
        '-p137,161',
        '--script',
        'snmp-*,snmp-win32-*,nbstat.nse',
        '--script-args',
        'snmpcommunity=public',
        '-T4',
        '--max-retries',
        '1',
        '--host-timeout',
        '3m',
        '-oX',
        tempFile,
        target
      ];
    } else {
      command = 'nmap';
      args = [
        '-sU',
        '-p137,161',
        '--script',
        'snmp-*,snmp-win32-*,nbstat.nse',
        '--script-args',
        'snmpcommunity=public',
        '-T4',
        '--max-retries',
        '1',
        '--host-timeout',
        '3m',
        '-oX',
        tempFile,
        target
      ];
    }

    await _logger.log('SNMP_SCAN', 'Full command: $command ${args.join(" ")}');
    await _logger.flush();

    await _logger.logProcessStart(command, args, uniqueId?.hashCode ?? 0);

    Process? process;
    try {
      await _logger.log('SNMP_SCAN', 'Starting nmap process...');
      await _logger.log('SNMP_SCAN', 'Using privileged runner: ${(ConfigService.isMacOS || ConfigService.isLinux) && PrivilegedRunner.hasPassword}');
      await _logger.flush();

      if ((ConfigService.isMacOS || ConfigService.isLinux) && PrivilegedRunner.hasPassword) {
        await _logger.log('SNMP_SCAN', 'Starting with PrivilegedRunner');
        await _logger.flush();
        process = await PrivilegedRunner.start(command, args);
      } else {
        await _logger.log('SNMP_SCAN', 'Starting with Process.start');
        await _logger.flush();
        process = await Process.start(command, args);
      }
      _activeProcesses.add(process);

      await _logger.log('SNMP_PROCESS', 'Process started successfully! PID: ${process.pid}');
      await _logger.log('SNMP_PROCESS', 'Target: $target');
      await _logger.flush();

      // Capture stdout and stderr
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      // Listen to stdout
      process.stdout.listen((data) {
        final output = String.fromCharCodes(data);
        stdoutBuffer.write(output);
        _logger.log('SNMP_STDOUT', 'PID ${process?.pid}: $output');
      }, onError: (error) {
        _logger.logError('SNMP_STDOUT', 'Error reading stdout: $error');
      }, onDone: () {
        _logger.log('SNMP_STDOUT', 'PID ${process?.pid}: stdout stream closed');
      });

      // Listen to stderr
      process.stderr.listen((data) {
        final output = String.fromCharCodes(data);
        stderrBuffer.write(output);
        _logger.logError('SNMP_STDERR', 'PID ${process?.pid}: $output');
      }, onError: (error) {
        _logger.logError('SNMP_STDERR', 'Error reading stderr: $error');
      }, onDone: () {
        _logger.log('SNMP_STDERR', 'PID ${process?.pid}: stderr stream closed');
      });

      // Close stdin immediately
      await _logger.log('SNMP_PROCESS', 'Closing stdin...');
      await _logger.flush();
      try {
        await process.stdin.close();
        await _logger.log('SNMP_PROCESS', 'Stdin closed successfully');
      } catch (e) {
        await _logger.logError('SNMP_PROCESS', 'Failed to close stdin: $e');
      }
      await _logger.flush();

      // Monitor file size periodically
      final fileMonitorTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
        try {
          final xmlFile = File(tempFile);
          if (await xmlFile.exists()) {
            final size = await xmlFile.length();
            await _logger.log('SNMP_FILE_MONITOR', 'PID ${process?.pid}: Temp file size: $size bytes');
            await _logger.flush();
          } else {
            await _logger.log('SNMP_FILE_MONITOR', 'PID ${process?.pid}: Temp file does not exist yet');
            await _logger.flush();
          }
        } catch (e) {
          await _logger.logError('SNMP_FILE_MONITOR', 'Error checking file size: $e');
        }
      });

      await _logger.log('SNMP_PROCESS', 'Waiting for process to complete (5 minute timeout)...');
      await _logger.flush();

      final result = await process.exitCode.timeout(
        Duration(minutes: 5),
        onTimeout: () async {
          await _logger.logError('SNMP_PROCESS', '!!! TIMEOUT !!! Process timed out after 5 minutes for target: $target');
          await _logger.log('SNMP_PROCESS', 'Stdout so far: ${stdoutBuffer.toString()}');
          await _logger.log('SNMP_PROCESS', 'Stderr so far: ${stderrBuffer.toString()}');
          await _logger.flush();
          fileMonitorTimer.cancel();
          process?.kill(ProcessSignal.sigkill);
          throw Exception('SNMP scan timed out after 5 minutes - target may not have SNMP enabled');
        },
      );

      fileMonitorTimer.cancel();
      _activeProcesses.remove(process);

      await _logger.log('SNMP_PROCESS', 'Process completed with exit code: $result');
      await _logger.log('SNMP_PROCESS', 'Full stdout: ${stdoutBuffer.toString()}');
      if (stderrBuffer.isNotEmpty) {
        await _logger.logError('SNMP_PROCESS', 'Full stderr: ${stderrBuffer.toString()}');
      }
      await _logger.flush();

      await _logger.logProcessComplete(command, uniqueId?.hashCode ?? 0, result);

      await _logger.log('SNMP_PROCESS', 'Checking for XML file at: $tempFile');
      await _logger.flush();

      final xmlFile = File(tempFile);
      final fileExists = await xmlFile.exists();
      await _logger.log('SNMP_PROCESS', 'XML file exists: $fileExists');
      await _logger.flush();

      if (fileExists) {
        final fileSize = await xmlFile.length();
        await _logger.log('SNMP_PROCESS', 'XML file size: $fileSize bytes');
        await _logger.flush();

        // If file was created by sudo, change ownership to current user
        if ((ConfigService.isMacOS || ConfigService.isLinux) && PrivilegedRunner.hasPassword) {
          try {
            final username = Platform.environment['USER'] ?? '';
            if (username.isNotEmpty) {
              await _logger.log('SNMP_PROCESS', 'Changing file ownership to: $username');
              await _logger.flush();
              await PrivilegedRunner.run('chown', [username, tempFile]);
              await _logger.log('SNMP_PROCESS', 'File ownership changed successfully');
              await _logger.flush();
            }
          } catch (e) {
            await _logger.logError('SNMP_PROCESS', 'Failed to change file ownership: $e');
            await _logger.flush();
          }
        }

        await _logger.log('SNMP_PROCESS', 'Reading XML file contents...');
        await _logger.flush();

        final xmlContent = await xmlFile.readAsString();
        await _logger.log('SNMP_PROCESS', 'XML content read, length: ${xmlContent.length} bytes');
        await _logger.flush();

        if (xmlContent.isNotEmpty) {
          await _logger.log('SNMP_PROCESS', 'Validating XML...');
          await _logger.flush();

          final isValid = _isValidXml(xmlContent);
          await _logger.log('SNMP_PROCESS', 'XML is valid: $isValid');
          await _logger.flush();

          if (isValid) {
            await _logger.log('SNMP_PROCESS', 'Valid XML file size: ${xmlContent.length} bytes');
            await _logger.flush();

            try {
              await xmlFile.delete();
              await _logger.log('SNMP_PROCESS', 'Temp file deleted successfully');
              await _logger.flush();
            } catch (e) {
              await _logger.logError('SNMP_PROCESS', 'Could not delete temp file: $e');
              await _logger.flush();
            }

            await _logger.log('SNMP_SCAN', '========== SNMP SCAN COMPLETED SUCCESSFULLY ==========');
            await _logger.flush();
            return xmlContent;
          } else {
            await _logger.logError('SNMP_PROCESS', 'Invalid XML file. First 500 chars: ${xmlContent.substring(0, xmlContent.length > 500 ? 500 : xmlContent.length)}');
            await _logger.flush();
            throw Exception('Invalid XML output from SNMP scan');
          }
        } else {
          await _logger.logError('SNMP_PROCESS', 'XML file is empty (0 bytes)');
          await _logger.flush();
          throw Exception('Empty XML output from SNMP scan');
        }
      } else {
        await _logger.logError('SNMP_PROCESS', 'No XML file found after SNMP scan at path: $tempFile');
        await _logger.log('SNMP_PROCESS', 'Listing temp directory contents:');
        try {
          final tempDirFiles = await tempDir.list().toList();
          for (final file in tempDirFiles) {
            await _logger.log('SNMP_PROCESS', '  - ${file.path}');
          }
        } catch (e) {
          await _logger.logError('SNMP_PROCESS', 'Could not list temp directory: $e');
        }
        await _logger.flush();
        throw Exception('No XML file found after SNMP scan');
      }

    } catch (e, stackTrace) {
      await _logger.logError('SNMP_SCAN', '========== SNMP SCAN FAILED ==========');
      await _logger.logError('SNMP_SCAN', 'Error: $e');
      await _logger.logError('SNMP_SCAN', 'Stack trace: $stackTrace');
      await _logger.flush();

      if (process != null) {
        _activeProcesses.remove(process);
        try {
          await _logger.log('SNMP_SCAN', 'Killing process PID: ${process.pid}');
          await _logger.flush();
          process.kill(ProcessSignal.sigterm);
          await Future.delayed(Duration(milliseconds: 500));
          process.kill(ProcessSignal.sigkill);
          await _logger.log('SNMP_SCAN', 'Process killed');
          await _logger.flush();
        } catch (killError) {
          await _logger.logError('SNMP_PROCESS', 'Failed to kill process: $killError');
          await _logger.flush();
        }
      }
      await _logger.logError('SNMP_PROCESS', 'SNMP scan error: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> _waitForFileCompletion(String wslFilePath) async {
    // Legacy method for WSL
  }

  bool _isValidXml(String content) {
    try {
      XmlDocument.parse(content);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> processSnmpResults(int deviceId, int projectId, String xmlContent, DatabaseHelper dbHelper) async {
    try {
      final document = XmlDocument.parse(xmlContent);

      await _initSchema(dbHelper);
      await _clearDeviceData(dbHelper, deviceId);

      final hosts = document.findAllElements('host');
      bool hasFindings = false;
      for (final host in hosts) {
        final foundFindings = await _processHost(dbHelper, host, deviceId, projectId);
        if (foundFindings) hasFindings = true;
      }

      // Update cache if findings were found
      if (hasFindings) {
        final cache = ProjectDataCache();
        cache.addDeviceToScanType('SNMP', deviceId);
      }

      return true;
    } catch (e, stackTrace) {
      await _logger.logError('SNMP_PROCESS', 'Failed to process SNMP results: $e', stackTrace);
      return false;
    }
  }

  Future<void> _initSchema(DatabaseHelper dbHelper) async {
    final db = await dbHelper.database;
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS snmp_findings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER,
        project_id INTEGER,
        finding_type TEXT,
        finding_value TEXT,
        FOREIGN KEY(device_id) REFERENCES devices(id),
        FOREIGN KEY(project_id) REFERENCES projects(id)
      )
    ''');
  }

  Future<void> _clearDeviceData(DatabaseHelper dbHelper, int deviceId) async {
    final db = await dbHelper.database;
    await db.execute('DELETE FROM snmp_findings WHERE device_id = ?', [deviceId]);
  }

  Future<bool> _processHost(DatabaseHelper dbHelper, XmlElement host, int deviceId, int projectId) async {
    final db = await dbHelper.database;

    // Collect all findings first
    final findings = <Map<String, dynamic>>[];
    final deviceUpdates = <String, dynamic>{};

    // Extract MAC address and vendor from address elements
    String? macAddress;
    String? vendor;

    for (final address in host.findElements('address')) {
      final addrType = address.getAttribute('addrtype') ?? '';
      if (addrType == 'mac') {
        macAddress = address.getAttribute('addr');
        vendor = address.getAttribute('vendor');
        break;
      }
    }

    // Collect MAC and vendor updates
    if (macAddress != null && macAddress.isNotEmpty) {
      deviceUpdates['mac_address'] = macAddress;
      deviceUpdates['vendor'] = vendor ?? '';
    }

    // Process host-level scripts (like nbstat)
    final hostScriptElement = host.findElements('hostscript').firstOrNull;
    if (hostScriptElement != null) {
      for (final script in hostScriptElement.findElements('script')) {
        await _collectScriptFindings(script, deviceId, projectId, findings, deviceUpdates);
      }
    }

    // Process scripts for SNMP findings
    final portsElement = host.findElements('ports').firstOrNull;
    if (portsElement != null) {
      for (final port in portsElement.findElements('port')) {
        for (final script in port.findElements('script')) {
          await _collectScriptFindings(script, deviceId, projectId, findings, deviceUpdates);
        }
      }
    }

    // Apply all device updates in one operation
    if (deviceUpdates.isNotEmpty) {
      final setClause = deviceUpdates.keys.map((key) {
        if (key == 'mac_address' || key == 'vendor') {
          return '$key = COALESCE(NULLIF($key, \'\'), ?)';
        } else {
          return '$key = ?';
        }
      }).join(', ');
      final values = [...deviceUpdates.values, deviceId];
      await db.execute('UPDATE devices SET $setClause WHERE id = ?', values);
    }

    // Batch insert all findings in one transaction
    if (findings.isNotEmpty) {
      final batch = db.batch();
      for (final finding in findings) {
        batch.insert('snmp_findings', finding);
      }
      await batch.commit(noResult: true);
      return true; // Return true if findings were inserted
    }

    return false; // No findings found
  }

  Future<void> _collectScriptFindings(
    XmlElement script,
    int deviceId,
    int projectId,
    List<Map<String, dynamic>> findings,
    Map<String, dynamic> deviceUpdates,
  ) async {
    final scriptId = script.getAttribute('id') ?? '';
    final output = script.getAttribute('output') ?? '';

    if (output.isEmpty) return;

    // Store different types of SNMP findings
    String findingType = scriptId;
    String findingValue = output;

    // Parse specific script outputs
    if (scriptId == 'snmp-info') {
      findingType = 'System Information';
    } else if (scriptId == 'snmp-interfaces') {
      findingType = 'Network Interfaces';
    } else if (scriptId == 'snmp-sysdescr') {
      findingType = 'System Description';
    } else if (scriptId == 'snmp-netstat') {
      findingType = 'Network Statistics';
    } else if (scriptId == 'snmp-processes') {
      findingType = 'Running Processes';
    } else if (scriptId.startsWith('snmp-win32-')) {
      findingType = 'Windows ${scriptId.substring(11)}';
    } else if (scriptId == 'nbstat') {
      findingType = 'NetBIOS Information';

      // Parse nbstat output for key information
      _collectNbstatUpdates(output, deviceUpdates);
    }

    findings.add({
      'device_id': deviceId,
      'project_id': projectId,
      'finding_type': findingType,
      'finding_value': findingValue,
    });
  }

  /// Parses nbstat output to extract NetBIOS name, user, and MAC address
  void _collectNbstatUpdates(String output, Map<String, dynamic> deviceUpdates) {
    try {
      // Decode HTML entities
      String decoded = output
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&amp;', '&')
          .replaceAll('&#xa;', '\n');

      // Extract NetBIOS name
      final netbiosNameMatch = RegExp(r'NetBIOS name:\s*([^,\n]+)').firstMatch(decoded);
      final netbiosName = netbiosNameMatch?.group(1)?.trim();

      // Extract NetBIOS user
      final netbiosUserMatch = RegExp(r'NetBIOS user:\s*([^,\n]+)').firstMatch(decoded);
      final netbiosUser = netbiosUserMatch?.group(1)?.trim();

      // Extract NetBIOS MAC
      final netbiosMacMatch = RegExp(r'NetBIOS MAC:\s*([0-9a-fA-F:]+)').firstMatch(decoded);
      final netbiosMac = netbiosMacMatch?.group(1)?.trim();

      // Extract vendor from MAC address line
      final vendorMatch = RegExp(r'NetBIOS MAC:.*?\(([^)]+)\)').firstMatch(decoded);
      final vendor = vendorMatch?.group(1)?.trim();

      // Collect device updates
      if (netbiosName != null && netbiosName.isNotEmpty && netbiosName != '<unknown>') {
        deviceUpdates['netbios_name'] = netbiosName;
      }

      if (netbiosUser != null && netbiosUser.isNotEmpty && netbiosUser != '<unknown>') {
        deviceUpdates['netbios_user'] = netbiosUser;
      }

      if (netbiosMac != null && netbiosMac.isNotEmpty) {
        deviceUpdates['mac_address'] = netbiosMac;
      }

      if (vendor != null && vendor.isNotEmpty) {
        deviceUpdates['vendor'] = vendor;
      }
    } catch (e) {
      // Silently ignore parse errors - will be logged at higher level if needed
    }
  }
}
