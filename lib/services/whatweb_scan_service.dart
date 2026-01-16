import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/services/config_service.dart';
import 'package:penpeeper/services/command_path_resolver.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'package:penpeeper/repositories/findings_data_repository.dart';
import 'package:penpeeper/utils/privileged_runner.dart';
import 'package:penpeeper/utils/wsl_utils.dart';

class WhatwebScanService {
  final _pathResolver = CommandPathResolver();
  final FindingsDataRepository _findingsRepo = FindingsDataRepository();

  Future<String> runWhatwebScan(String target) async {
    String command;
    List<String> args;
    String outputPath;
    
    if (ConfigService.isLinux || ConfigService.isMacOS) {
      final tempPath = AppPathsService().getTempScanPath('temp_whatweb', 'json');
      outputPath = tempPath;
      command = await _pathResolver.requireCommandPath('whatweb');
      args = ['-v', '--log-json', outputPath, target];
    } else {
      outputPath = WSLUtils.getWSLTempPath('whatweb', 'json');
      command = 'wsl.exe';
      args = ['whatweb', '-v', '--log-json', outputPath, target];
    }
    try {
      ProcessResult result;
      if ((ConfigService.isMacOS || ConfigService.isLinux) && PrivilegedRunner.hasPassword) {
        debugPrint('WhatWeb: Running with administrator privileges: sudo -S $command ${args.join(" ")}');
        result = await PrivilegedRunner.run(command, args);
      } else {
        debugPrint('WhatWeb: Running command: $command ${args.join(" ")}');
        result = await Process.run(
          command,
          args,
          workingDirectory: Directory.current.path,
        );
      }

      debugPrint('WhatWeb: Exit code: ${result.exitCode}');
      debugPrint('WhatWeb: stdout: ${result.stdout}');
      debugPrint('WhatWeb: stderr: ${result.stderr}');

      String jsonContent = '';
      if (ConfigService.isLinux || ConfigService.isMacOS) {
        final tempFile = File(outputPath);
        debugPrint('WhatWeb: Checking for output file at: ${tempFile.path}');
        if (await tempFile.exists()) {
          jsonContent = await tempFile.readAsString();
          debugPrint('WhatWeb: Output file size: ${jsonContent.length} bytes');
        } else {
          debugPrint('WhatWeb: Output file not found');
        }
        try {
          await tempFile.delete();
        } catch (e) {
          debugPrint('Warning: Could not delete temp file: $e');
        }
      } else {
        // For Windows/WSL
        try {
          if (await WSLUtils.wslFileExists(outputPath)) {
            jsonContent = await WSLUtils.readWSLFile(outputPath);
            debugPrint('WhatWeb: Read ${jsonContent.length} bytes from WSL file');
          } else {
            debugPrint('WhatWeb: WSL output file not found');
          }
          await WSLUtils.deleteWSLFile(outputPath);
        } catch (e) {
          debugPrint('WhatWeb: Could not read WSL temp file: $e');
        }
      }

      if (result.exitCode != 0 && jsonContent.isEmpty) {
        final errorMsg = result.stderr.toString().trim().isNotEmpty
            ? result.stderr.toString()
            : result.stdout.toString().trim().isNotEmpty
                ? result.stdout.toString()
                : 'Unknown error (exit code ${result.exitCode})';
        debugPrint('WhatWeb: Scan failed - $errorMsg');
        throw Exception('WhatWeb scan failed: $errorMsg');
      }

      return jsonContent.isNotEmpty ? jsonContent : result.stdout;
    } catch (e) {
      // Clean up temp files on error
      if (ConfigService.isLinux || ConfigService.isMacOS) {
        try {
          await File(outputPath).delete();
        } catch (_) {}
      } else {
        await WSLUtils.deleteWSLFile(outputPath);
      }
      rethrow;
    }
  }

  Future<void> parseAndStoreResults(int deviceId, String whatwebData) async {
    try {
      await _findingsRepo.deleteWhatwebFindings(deviceId);

      // Collect all findings first, then batch insert
      final findings = <String>[];

      final lines = whatwebData.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty &&
            trimmed != '[' &&
            trimmed != ']' &&
            !trimmed.startsWith('{') &&
            !trimmed.startsWith('}') &&
            trimmed.length > 2) {

          String finding = trimmed;
          if (finding.contains('http')) {
            finding = finding.replaceAll(RegExp(r'\s+'), ' ');
            findings.add(finding);
          }
        }
      }

      try {
        final jsonLines = whatwebData.split('\n').where((line) => line.trim().startsWith('{')).toList();
        for (final jsonLine in jsonLines) {
          final data = json.decode(jsonLine) as Map<String, dynamic>;
          final target = data['target']?.toString() ?? '';
          final plugins = data['plugins'] as Map<String, dynamic>? ?? {};

          if (target.isNotEmpty && plugins.isNotEmpty) {
            final pluginFindings = <String>[];
            plugins.forEach((key, value) {
              if (value is Map && value.isNotEmpty) {
                pluginFindings.add('$key: ${value.toString()}');
              }
            });

            if (pluginFindings.isNotEmpty) {
              final finding = '$target - ${pluginFindings.join(', ')}';
              findings.add(finding);
            }
          }
        }
      } catch (e) {
        // JSON parsing failed, continue with text processing
      }

      // Batch insert all findings in a single transaction
      if (findings.isNotEmpty) {
        await _findingsRepo.batchInsertWhatwebFindings(deviceId, findings);
      }
    } catch (e) {
      debugPrint('Failed to process WhatWeb results: $e');
    }
  }

  Future<List<String>> parseNmapForHttpPorts(String nmapXml, String ipAddress) async {
    final httpPorts = <String>[];
    
    try {
      final portRegex = RegExp(r'<port protocol="tcp" portid="(\d+)">.*?<service name="([^"]*?)".*?</port>', dotAll: true);
      final matches = portRegex.allMatches(nmapXml);
      
      for (final match in matches) {
        final port = match.group(1)!;
        final service = match.group(2)?.toLowerCase() ?? '';
        
        if (port == '80' || port == '443' || 
            service.contains('http') || 
            service == 'ms-wbt-server') {
          final protocol = (port == '443' || service.contains('https')) ? 'https' : 'http';
          httpPorts.add('$protocol://$ipAddress:$port');
        }
      }
    } catch (e) {
      debugPrint('Failed to parse nmap XML for HTTP ports: $e');
    }
    
    return httpPorts;
  }
}
