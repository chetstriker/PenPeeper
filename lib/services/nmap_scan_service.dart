import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:penpeeper/services/config_service.dart';
import 'package:penpeeper/services/nmap_processor.dart';
import 'package:penpeeper/utils/debug_logger.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/platform/platform_executor.dart';
import 'package:penpeeper/utils/privileged_runner.dart';
import 'package:penpeeper/services/command_path_resolver.dart';
import 'package:http/http.dart' as http;

class NmapScanService {
  final _logger = DebugLogger();
  final VulnerabilityRepository _vulnRepo = VulnerabilityRepository();
  final Set<Process> _activeProcesses = {};
  final _pathResolver = CommandPathResolver();

  // Expose active processes for orchestrator tracking
  Set<Process> get activeProcesses => _activeProcesses;

  Future<String> runHostDiscoveryScan(String target) async {
    return await PlatformExecutor.execute(
      web: () async {
        final response = await http.post(
          Uri.parse('/api/nmap/host-discovery'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'target': target}),
        );
        if (response.statusCode != 200) {
          throw Exception('Host discovery scan failed: ${response.body}');
        }
        return response.body;
      },
      desktop: () async {
        String command;
        List<String> args;

        if (ConfigService.isLinux || ConfigService.isMacOS || ConfigService.isWindows) {
          // Find full path to nmap (native on all desktop platforms now)
          command = await _pathResolver.requireCommandPath('nmap');
          args = ['-sn', target];
        } else {
          // Fallback
          command = 'nmap';
          args = ['-sn', target];
        }

        debugPrint('Running: $command ${args.join(" ")}');
        ProcessResult result;
        if ((ConfigService.isMacOS || ConfigService.isLinux) && PrivilegedRunner.hasPassword) {
          result = await PrivilegedRunner.run(command, args);
        } else {
          result = await Process.run(command, args);
        }
        debugPrint('Exit code: ${result.exitCode}');
        debugPrint('Stdout: ${result.stdout}');
        debugPrint('Stderr: ${result.stderr}');

        if (result.exitCode != 0) {
          throw Exception('Host discovery scan failed: ${result.stderr}');
        }

        final output = result.stdout.toString();
        final hosts = <Map<String, String>>[];
        final lines = output.split('\n');

        String? currentIp;
        String? currentHostname;

        for (final line in lines) {
          if (line.contains('Nmap scan report for')) {
            final match = RegExp(r'Nmap scan report for (.+?)(?:\s+\(([0-9.]+)\))?\s*$').firstMatch(line);
            if (match != null) {
              if (match.group(2) != null) {
                currentHostname = match.group(1);
                currentIp = match.group(2);
              } else {
                currentIp = match.group(1);
                currentHostname = currentIp;
              }
            }
          } else if (line.contains('Host is up') && currentIp != null) {
            hosts.add({'ip': currentIp, 'hostname': currentHostname ?? currentIp});
            currentIp = null;
            currentHostname = null;
          }
        }

        debugPrint('Parsed hosts: ${json.encode({'hosts': hosts})}');
        return json.encode({'hosts': hosts});
      },
    );
  }

  Future<String> runDeviceScan(String target, [String? uniqueId]) async {
    await _logger.log('NMAP_SERVICE', 'runDeviceScan called for target: $target, uniqueId: $uniqueId');
    await _logger.flush();

    return await PlatformExecutor.execute(
      web: () async {
        final response = await http.post(
          Uri.parse('/api/nmap/device-scan'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'target': target, 'uniqueId': uniqueId}),
        );
        if (response.statusCode != 200) {
          throw Exception('Device scan failed: ${response.body}');
        }
        return response.body;
      },
      desktop: () async {
        await _logger.log('NMAP_SERVICE', 'Starting desktop execution for target: $target');
        await _logger.flush();

        final pathsService = AppPathsService();
        final tempFile = pathsService.getTempScanPath('temp_scan_${uniqueId ?? ""}', 'xml');

        await _logger.log('NMAP_PROCESS', 'Temp file path: $tempFile');
        await _logger.log('NMAP_PROCESS', 'Temp directory: ${pathsService.tempScanDir}');
        await _logger.flush();

        String command;
        List<String> args;

        // Use native nmap on all desktop platforms
        command = await _pathResolver.requireCommandPath('nmap');
        args = [
          '-sV', '-O',
          '--script', 'vulners,http-enum,http-devframework,http-title,http-server-header',
          '--host-timeout', '30m',
          '--max-retries', '2',
          '-T4',
          '-oX', tempFile,
          target
        ];

        await _logger.logProcessStart(command, args, uniqueId?.hashCode ?? 0);
        await _logger.log('NMAP_PROCESS', 'Full command: $command ${args.join(" ")}');
        await _logger.flush();

        Process? process;
        try {
          await _logger.log('NMAP_PROCESS', 'About to start process for target: $target');
          await _logger.flush();
          if ((ConfigService.isMacOS || ConfigService.isLinux) && PrivilegedRunner.hasPassword) {
            await _logger.log('NMAP_PROCESS', 'Using PrivilegedRunner.start with sudo');
            await _logger.flush();
            process = await PrivilegedRunner.start(command, args);
          } else {
            await _logger.log('NMAP_PROCESS', 'Using Process.start');
            await _logger.flush();
            process = await Process.start(command, args);
          }
          await _logger.log('NMAP_PROCESS', 'Process started successfully');
          await _logger.flush();
          _activeProcesses.add(process);

          await _logger.log('NMAP_PROCESS', 'Started process PID: ${process.pid} for target: $target');
          await _logger.flush();

          // Close stdin immediately
          await _logger.log('NMAP_PROCESS', 'Closing stdin...');
          await _logger.flush();
          await process.stdin.close();
          await _logger.log('NMAP_PROCESS', 'Stdin closed');
          await _logger.flush();

          // Capture stderr
          await _logger.log('NMAP_PROCESS', 'Setting up stdout/stderr stream transforms...');
          await _logger.flush();
          final stderrFuture = process.stderr.transform(utf8.decoder).join();
          final stdoutFuture = process.stdout.transform(utf8.decoder).join();
          await _logger.log('NMAP_PROCESS', 'Stream transforms created');
          await _logger.flush();

          // Wait for process to complete with timeout
          await _logger.log('NMAP_PROCESS', 'Waiting for process to complete...');
          await _logger.flush();
          final result = await process.exitCode.timeout(
            Duration(minutes: 30),
            onTimeout: () {
              _logger.logError('NMAP_PROCESS', 'Process timed out after 30 minutes for target: $target');
              process?.kill(ProcessSignal.sigkill);
              throw Exception('Nmap scan timed out after 30 minutes');
            },
          );
          await _logger.log('NMAP_PROCESS', 'Process completed with exit code: $result');
          await _logger.flush();
          _activeProcesses.remove(process);

          // Log stderr and stdout
          await _logger.log('NMAP_PROCESS', 'Reading stderr and stdout...');
          await _logger.flush();
          final stderr = await stderrFuture;
          final stdout = await stdoutFuture;

          if (stderr.isNotEmpty) {
            await _logger.log('NMAP_PROCESS', 'Process stderr: $stderr');
          }
          if (stdout.isNotEmpty && stdout.length < 500) {
            await _logger.log('NMAP_PROCESS', 'Process stdout (truncated): ${stdout.substring(0, stdout.length < 500 ? stdout.length : 500)}');
          }
          await _logger.flush();

          await _logger.logProcessComplete(command, uniqueId?.hashCode ?? 0, result);

          // Log exit code and check if file exists
          await _logger.log('NMAP_PROCESS', 'Process exit code: $result');
          await _logger.log('NMAP_PROCESS', 'Checking if file exists at: $tempFile');
          await _logger.flush();
          final fileExists = await File(tempFile).exists();
          await _logger.log('NMAP_PROCESS', 'File exists: $fileExists');
          await _logger.flush();

          if (!fileExists) {
            try {
              final dir = Directory(pathsService.tempScanDir);
              if (await dir.exists()) {
                final files = await dir.list().toList();
                await _logger.log('NMAP_PROCESS', 'Files in temp dir: ${files.map((f) => path.basename(f.path)).join(", ")}');
              } else {
                await _logger.log('NMAP_PROCESS', 'Temp directory does not exist!');
              }
            } catch (e) {
              await _logger.log('NMAP_PROCESS', 'Error listing temp directory: $e');
            }
          }

          // Read directly (works for Windows native, Linux, macOS)
          await _logger.log('NMAP_PROCESS', 'About to read file directly');
          await _logger.flush();
          final xmlFile = File(tempFile);
          if (await xmlFile.exists()) {
            await _logger.log('NMAP_PROCESS', 'XML file exists, proceeding with read');
            await _logger.flush();
            // If file was created by sudo, change ownership to current user (Linux/MacOS only)
            if ((ConfigService.isMacOS || ConfigService.isLinux) && PrivilegedRunner.hasPassword) {
              try {
                final username = Platform.environment['USER'] ?? '';
                if (username.isNotEmpty) {
                  await _logger.log('NMAP_PROCESS', 'Changing file ownership to: $username');
                  await _logger.flush();
                  await PrivilegedRunner.run('chown', [username, tempFile]);
                  await _logger.log('NMAP_PROCESS', 'File ownership changed successfully');
                  await _logger.flush();
                }
              } catch (e) {
                await _logger.logError('NMAP_PROCESS', 'Failed to change file ownership: $e');
                await _logger.flush();
              }
            }

            await _logger.log('NMAP_PROCESS', 'About to read XML file content...');
            await _logger.flush();
            final xmlContent = await xmlFile.readAsString();
            await _logger.log('NMAP_PROCESS', 'XML content read, length: ${xmlContent.length}');
            await _logger.flush();
            if (xmlContent.isNotEmpty && _isValidXml(xmlContent)) {
              await _logger.log('NMAP_PROCESS', 'Valid XML file size: ${xmlContent.length} bytes');
              await _logger.flush();
              try {
                await xmlFile.delete();
              } catch (e) {
                await _logger.logError('NMAP_PROCESS', 'Could not delete temp file: $e');
              }
              return xmlContent;
            } else {
              await _logger.logError('NMAP_PROCESS', 'Invalid or empty XML file, size: ${xmlContent.length} bytes');
              throw Exception('Invalid XML output from nmap scan');
            }
          }

          throw Exception('No XML file found after nmap scan');

        } catch (e, stackTrace) {
          if (process != null) {
            _activeProcesses.remove(process);
            try {
              process.kill(ProcessSignal.sigterm);
              await Future.delayed(Duration(milliseconds: 500));
              process.kill(ProcessSignal.sigkill);
            } catch (killError) {
              await _logger.logError('NMAP_PROCESS', 'Failed to kill process: $killError');
            }
          }
            await _logger.logError('NMAP_PROCESS', 'Device scan error: $e', stackTrace);
            rethrow;
        }
      },
    );
  }

  Future<void> _waitForFileCompletion(String wslFilePath) async {
    // Legacy method mostly for WSL, can be removed if strictly native
  }

  bool _isValidXml(String content) {
    return content.trim().isNotEmpty &&
        content.contains('<?xml') &&
        content.contains('<nmaprun') &&
        content.contains('</nmaprun>');
  }

  Future<void> killAllProcesses() async {
    await _logger.log('NMAP_SERVICE', 'Killing ${_activeProcesses.length} active processes');
    for (final process in _activeProcesses) {
      try {
        process.kill(ProcessSignal.sigterm);
        await Future.delayed(Duration(milliseconds: 500));
        process.kill(ProcessSignal.sigkill);
      } catch (e) {
        await _logger.logError('NMAP_SERVICE', 'Failed to kill process PID ${process.pid}: $e');
      }
    }
    _activeProcesses.clear();
  }

  Future<bool> processNmapResults(int deviceId, int projectId, String xmlContent) async {
    await _logger.log('NMAP_PROCESSING', 'Starting processing for device $deviceId, XML length: ${xmlContent.length}');

    try {
      // Skip processing if XML is empty or invalid
      if (xmlContent.trim().isEmpty || !_isValidXml(xmlContent)) {
        await _logger.logError('NMAP_PROCESSING', 'Skipping processing for device $deviceId - invalid or empty XML');
        return false;
      }

      return await PlatformExecutor.execute(
        web: () async {
          final response = await http.post(
            Uri.parse('/api/nmap/process-results'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'deviceId': deviceId,
              'projectId': projectId,
              'xmlContent': xmlContent,
            }),
          );
          return response.statusCode == 200;
        },
        desktop: () async {
      await _logger.log('NMAP_PROCESSING', 'Device ID: $deviceId, Project ID: $projectId');

      // Process directly with Dart using DatabaseIsolateManager
      await NmapProcessor.processXmlContent(deviceId, projectId, xmlContent);

      await _logger.log('NMAP_PROCESSING', 'XML processing completed for device $deviceId');

      // Update vulnerabilities cache
      await _vulnRepo.updateVulnersCacheForDevice(deviceId);

          await _logger.log('NMAP_PROCESSING', 'Vulnerabilities cache updated for device $deviceId');

          return true;
        },
      );
    } catch (e, stackTrace) {
      await _logger.logError('NMAP_PROCESSING', 'Error processing device $deviceId: $e', stackTrace);
      return false;
    }
  }
}
