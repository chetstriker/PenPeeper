import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/services/config_service.dart';
import 'package:penpeeper/services/command_path_resolver.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'package:penpeeper/utils/wsl_utils.dart';

class SearchsploitScanService {
  final _pathResolver = CommandPathResolver();
  final VulnerabilityRepository _vulnRepo = VulnerabilityRepository();

  Future<String> runSearchsploitScan(String nmapXml) async {
    String command;
    List<String> args;
    String tempFilePath;

    if (ConfigService.isLinux || ConfigService.isMacOS) {
      tempFilePath = AppPathsService().getTempScanPath('temp_searchsploit', 'xml');
      final tempFile = File(tempFilePath);
      await tempFile.writeAsString(nmapXml);
      
      command = await _pathResolver.requireCommandPath('searchsploit');
      args = ['--nmap', tempFilePath, '-j'];
    } else {
      // For Windows/WSL, use simple /tmp path
      tempFilePath = WSLUtils.getWSLTempPath('searchsploit', 'xml');
      
      // Write the file using WSL
      final process = await Process.start('wsl.exe', ['bash', '-c', 'cat > $tempFilePath']);
      process.stdin.add(utf8.encode(nmapXml));
      await process.stdin.close();
      final writeResult = await process.exitCode;
      if (writeResult != 0) {
        throw Exception('Failed to write temp file to WSL');
      }
      
      command = 'wsl.exe';
      args = ['searchsploit', '--nmap', tempFilePath, '-j'];
    }
    try {
      debugPrint('SearchSploit: Running command: $command ${args.join(" ")}');

      final result = await Process.run(
        command,
        args,
        workingDirectory: Directory.current.path,
      ).timeout(Duration(minutes: 2));

      debugPrint('SearchSploit: Exit code: ${result.exitCode}');
      debugPrint('SearchSploit: Stdout length: ${result.stdout.toString().length}');
      if (result.stderr.toString().isNotEmpty) {
        debugPrint('SearchSploit: Stderr: ${result.stderr}');
      }

      // Clean up temp file
      if (ConfigService.isLinux || ConfigService.isMacOS) {
        try {
          await File(tempFilePath).delete();
        } catch (e) {
          debugPrint('Warning: Could not delete temp file: $e');
        }
      } else {
        await WSLUtils.deleteWSLFile(tempFilePath);
      }

      if (result.stdout.toString().trim().isEmpty) {
        debugPrint('SearchSploit: No output, returning empty array');
        return '[]';
      }

      return result.stdout.toString();
    } catch (e) {
      // Clean up temp file on error
      if (ConfigService.isLinux || ConfigService.isMacOS) {
        try {
          await File(tempFilePath).delete();
        } catch (_) {}
      } else {
        await WSLUtils.deleteWSLFile(tempFilePath);
      }
      rethrow;
    }
  }

  Future<void> parseAndStoreResults(int deviceId, String jsonResult) async {
    try {
      final lines = jsonResult.split('\n');
      final jsonObjects = <String>[];
      String currentJson = '';
      int braceCount = 0;

      for (final line in lines) {
        if (line.trim().startsWith('{')) {
          if (braceCount == 0) {
            currentJson = line;
          } else {
            currentJson += '\n$line';
          }
          braceCount += line.split('{').length - 1;
          braceCount -= line.split('}').length - 1;
        } else if (braceCount > 0) {
          currentJson += '\n$line';
          braceCount += line.split('{').length - 1;
          braceCount -= line.split('}').length - 1;
        }

        if (braceCount == 0 && currentJson.isNotEmpty) {
          jsonObjects.add(currentJson);
          currentJson = '';
        }
      }

      // Collect all vulnerabilities first, then batch insert
      final vulnerabilities = <Map<String, dynamic>>[];

      for (final jsonStr in jsonObjects) {
        try {
          final data = json.decode(jsonStr) as Map<String, dynamic>;

          final exploits = data['RESULTS_EXPLOIT'] as List?;
          if (exploits != null && exploits.isNotEmpty) {
            for (final exploit in exploits) {
              if (exploit is Map<String, dynamic>) {
                final title = exploit['Title']?.toString() ?? 'Unknown Exploit';
                final edbId = exploit['EDB-ID']?.toString() ?? '';
                final url = edbId.isNotEmpty
                    ? 'https://www.exploit-db.com/exploits/$edbId'
                    : '';

                vulnerabilities.add({
                  'device_id': deviceId,
                  'type': 'SearchSploit',
                  'title': title,
                  'description': 'Exploit found in SearchSploit database (EDB-ID: $edbId)',
                  'severity': 'Low',
                  'url': url,
                });
              }
            }
          }

          final shellcodes = data['RESULTS_SHELLCODE'] as List?;
          if (shellcodes != null && shellcodes.isNotEmpty) {
            for (final shellcode in shellcodes) {
              if (shellcode is Map<String, dynamic>) {
                final title =
                    shellcode['Title']?.toString() ?? 'Unknown Shellcode';
                final edbId = shellcode['EDB-ID']?.toString() ?? '';
                final url = edbId.isNotEmpty
                    ? 'https://www.exploit-db.com/shellcodes/$edbId'
                    : '';

                vulnerabilities.add({
                  'device_id': deviceId,
                  'type': 'SearchSploit',
                  'title': title,
                  'description': 'Shellcode found in SearchSploit database (EDB-ID: $edbId)',
                  'severity': 'Low',
                  'url': url,
                });
              }
            }
          }
        } catch (e) {
          debugPrint('Failed to parse individual JSON object: $e');
        }
      }

      // Batch insert all vulnerabilities in a single transaction
      if (vulnerabilities.isNotEmpty) {
        await _vulnRepo.batchInsertVulnerabilities(vulnerabilities);
      }
    } catch (e) {
      debugPrint('Failed to parse SearchSploit results: $e');
    }
  }
}
