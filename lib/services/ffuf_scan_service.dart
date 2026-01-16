import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/services/config_service.dart';
import 'package:penpeeper/services/command_path_resolver.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'package:penpeeper/repositories/findings_data_repository.dart';
import 'package:penpeeper/utils/privileged_runner.dart';
import 'package:penpeeper/utils/wsl_utils.dart';

class FfufScanService {
  final _pathResolver = CommandPathResolver();
  final FindingsDataRepository _findingsRepo = FindingsDataRepository();

  /// Find the SecLists wordlist file in common installation locations
  Future<String> _findWordlistPath() async {
    // On Windows, check for wordlist in WSL
    if (Platform.isWindows) {
      final wslPaths = [
        '/usr/share/seclists/Discovery/Web-Content/raft-large-files.txt',
        '/usr/share/wordlists/seclists/Discovery/Web-Content/raft-large-files.txt',
      ];

      for (final path in wslPaths) {
        try {
          final result = await Process.run(
            'wsl',
            ['test', '-f', path],
            runInShell: true,
          );
          if (result.exitCode == 0) {
            debugPrint('FFUF: Found wordlist in WSL at: $path');
            return path;
          }
        } catch (e) {
          debugPrint('FFUF: Error checking WSL path $path: $e');
        }
      }

      throw Exception('SecLists wordlist not found in WSL. Please install SecLists or check installation path.');
    }

    // For macOS and Linux, check local filesystem
    final possiblePaths = [
      // macOS Homebrew locations
      '/opt/homebrew/share/seclists/Discovery/Web-Content/raft-large-files.txt',
      '/usr/local/share/seclists/Discovery/Web-Content/raft-large-files.txt',
      // macOS user install
      '${Platform.environment['HOME']}/.local/share/seclists/Discovery/Web-Content/raft-large-files.txt',
      // Linux locations
      '/usr/share/seclists/Discovery/Web-Content/raft-large-files.txt',
      '/usr/share/wordlists/seclists/Discovery/Web-Content/raft-large-files.txt',
    ];

    for (final path in possiblePaths) {
      if (await File(path).exists()) {
        debugPrint('FFUF: Found wordlist at: $path');
        return path;
      }
    }

    throw Exception('SecLists wordlist not found. Please install SecLists or check installation path.');
  }

  Future<String> runFfufScan(String ip, String port) async {
    final protocol = (port == '443' || port == '8443') ? 'https' : 'http';
    final url = '$protocol://$ip:$port/FUZZ';
    
    String tempFile;
    String outputFile;
    
    if (ConfigService.isLinux || ConfigService.isMacOS) {
      tempFile = AppPathsService().getTempScanPath('temp_ffuf_${ip.replaceAll('.', '_')}_$port', 'json');
      outputFile = tempFile;
    } else {
      tempFile = WSLUtils.getWSLTempPath('ffuf_${ip.replaceAll('.', '_')}_$port', 'json');
      outputFile = tempFile;
    }
    
    try {
      final wordlistPath = await _findWordlistPath();
      
      String command;
      List<String> args;

      if (ConfigService.isLinux || ConfigService.isMacOS) {
        command = await _pathResolver.requireCommandPath('ffuf');
        args = [
          '-H', 'User-Agent: PENTEST',
          '-c',
          '-w', '$wordlistPath:FUZZ',
          '-ac',
          '-maxtime-job', '60',
          '-recursion',
          '-recursion-depth', '2',
          '-u', url,
          '-o', outputFile,
          '-of', 'json'
        ];
      } else {
        command = 'wsl.exe';
        args = [
          'ffuf',
          '-H', 'User-Agent: PENTEST',
          '-c',
          '-w', '$wordlistPath:FUZZ',
          '-ac',
          '-maxtime-job', '60',
          '-recursion',
          '-recursion-depth', '2',
          '-u', url,
          '-o', outputFile,
          '-of', 'json'
        ];
      }
      
      debugPrint('FFUF: Running command: $command ${args.join(" ")}');

      ProcessResult result;
      if ((ConfigService.isMacOS || ConfigService.isLinux) && PrivilegedRunner.hasPassword) {
        debugPrint('FFUF: Running with administrator privileges');
        result = await PrivilegedRunner.run(command, args);
      } else {
        result = await Process.run(
          command,
          args,
          workingDirectory: Directory.current.path,
        );
      }

      String jsonContent = '';
      if (ConfigService.isLinux || ConfigService.isMacOS) {
        final outputFileObj = File(outputFile);
        debugPrint('FFUF: Checking for output file at: $outputFile');
        if (await outputFileObj.exists()) {
          jsonContent = await outputFileObj.readAsString();
          debugPrint('FFUF: Output file size: ${jsonContent.length} bytes');
          try {
            await outputFileObj.delete();
          } catch (e) {
            debugPrint('Warning: Could not delete temp file: $e');
          }
        } else {
          debugPrint('FFUF: Output file not found');
        }
      } else {
        // For Windows/WSL, read the file from WSL
        try {
          if (await WSLUtils.wslFileExists(outputFile)) {
            jsonContent = await WSLUtils.readWSLFile(outputFile);
            debugPrint('FFUF: Read ${jsonContent.length} bytes from WSL file');
          }
          await WSLUtils.deleteWSLFile(outputFile);
        } catch (e) {
          debugPrint('FFUF: Could not read WSL temp file: $e');
        }
      }

      if (result.exitCode != 0 && jsonContent.isEmpty) {
        debugPrint('FFUF: Exit code: ${result.exitCode}, stderr: ${result.stderr}');
        throw Exception('FFUF scan failed: ${result.stderr}');
      }

      return jsonContent.isNotEmpty ? jsonContent : result.stdout;
    } catch (e) {
      // Clean up temp files on error
      if (ConfigService.isLinux || ConfigService.isMacOS) {
        try {
          final outputFileObj = File(outputFile);
          if (await outputFileObj.exists()) {
            await outputFileObj.delete();
          }
        } catch (_) {}
      } else {
        await WSLUtils.deleteWSLFile(outputFile);
      }
      rethrow;
    }
  }

  Future<void> parseAndStoreResults(int deviceId, String ffufData) async {
    try {
      await _findingsRepo.deleteFfufFindings(deviceId);

      // Collect all findings first, then batch insert
      final findings = <Map<String, dynamic>>[];

      final lines = ffufData.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          try {
            final data = json.decode(trimmed) as Map<String, dynamic>;
            final results = data['results'] as List?;

            if (results != null && results.isNotEmpty) {
              for (final result in results) {
                if (result is Map<String, dynamic>) {
                  final url = result['url']?.toString() ?? '';
                  final status = result['status'] as int? ?? 0;
                  final words = result['words'] as int? ?? 0;

                  if (url.isNotEmpty && status > 0) {
                    findings.add({
                      'url': url,
                      'status': status,
                      'words': words,
                    });
                  }
                }
              }
            }
          } catch (e) {
            // Skip invalid JSON lines
          }
        }
      }

      // Batch insert all findings in a single transaction
      if (findings.isNotEmpty) {
        await _findingsRepo.batchInsertFfufFindings(deviceId, findings);
      }
    } catch (e) {
      debugPrint('Failed to process FFUF results: $e');
    }
  }
}
