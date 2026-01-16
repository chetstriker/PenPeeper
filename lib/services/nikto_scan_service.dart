import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/services/config_service.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'package:penpeeper/services/command_path_resolver.dart';
import 'package:penpeeper/repositories/findings_data_repository.dart';
import 'package:penpeeper/utils/privileged_runner.dart';
import 'package:penpeeper/utils/wsl_utils.dart';
import 'package:xml/xml.dart';

class NiktoScanService {
  final FindingsDataRepository _findingsRepo = FindingsDataRepository();
  final _pathResolver = CommandPathResolver();

  Future<String> runNiktoScan(String ip, String ports, bool useSSL) async {
    String command;
    List<String> args;
    String outputPath;

    if (ConfigService.isLinux || ConfigService.isMacOS) {
      final tempPath = AppPathsService().getTempScanPath('temp_nikto_${ip.replaceAll('.', '_')}', 'xml');
      outputPath = tempPath;
      command = await _pathResolver.requireCommandPath('nikto');
      args = [
        '-h', ip,
        '-p', ports,
        '-Tuning', '123456789abc',
        '-nointeractive',
        '-maxtime', '900',
        '--no404',
        '-nolookup',
        '-Format', 'xml',
        '-output', outputPath
      ];
    } else {
      outputPath = WSLUtils.getWSLTempPath('nikto_${ip.replaceAll('.', '_')}', 'xml');
      command = 'wsl.exe';
      args = [
        'nikto',
        '-h', ip,
        '-p', ports,
        '-Tuning', '123456789abc',
        '-nointeractive',
        '-maxtime', '900',
        '--no404',
        '-nolookup',
        '-Format', 'xml',
        '-output', outputPath
      ];
    }
    
    if (useSSL) {
      args.add('-ssl');
    }

    debugPrint('Running: $command ${args.join(" ")}');

    try {
      ProcessResult result;
      if ((ConfigService.isMacOS || ConfigService.isLinux) && PrivilegedRunner.hasPassword) {
        debugPrint('Nikto: Running with administrator privileges');
        result = await PrivilegedRunner.run(command, args);
      } else {
        final process = await Process.start(command, args, workingDirectory: Directory.current.path);
        final stdout = await process.stdout.transform(const Utf8Decoder(allowMalformed: true)).join();
        final stderr = await process.stderr.transform(const Utf8Decoder(allowMalformed: true)).join();
        final exitCode = await process.exitCode;
        result = ProcessResult(process.pid, exitCode, stdout, stderr);
      }
      
      debugPrint('Exit code: ${result.exitCode}');
      debugPrint('Stdout length: ${result.stdout.toString().length}');
      debugPrint('Stderr: ${result.stderr}');
      
      if (result.exitCode != 0 && !(ConfigService.isLinux || ConfigService.isMacOS ? await File(outputPath).exists() : await WSLUtils.wslFileExists(outputPath))) {
        throw Exception('Nikto scan failed: ${result.stderr}');
      }
      
      String xmlContent = '';
      if (ConfigService.isLinux || ConfigService.isMacOS) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          debugPrint('Nikto output file exists at: ${outputFile.path}');
          xmlContent = await _waitForFileCompletion(outputFile);
          debugPrint('Nikto output file size: ${xmlContent.length} bytes');
          try {
            await outputFile.delete();
          } catch (e) {
            debugPrint('Warning: Could not delete temp file: $e');
          }
        } else if (result.stdout.isNotEmpty) {
          debugPrint('Nikto output file not found, using stdout (${result.stdout.length} bytes)');
          xmlContent = result.stdout;
        } else {
          debugPrint('Warning: No Nikto output file or stdout, using empty template');
          xmlContent = '<?xml version="1.0"?><niktoscan><scandetails targetip="$ip" targethostname="$ip" targetport="$ports" targetbanner="" starttime="" sitename="" hoststatus="" errors="" checks=""></scandetails></niktoscan>';
        }
      } else {
        // For Windows/WSL
        try {
          if (await WSLUtils.wslFileExists(outputPath)) {
            xmlContent = await WSLUtils.readWSLFile(outputPath);
            debugPrint('Nikto: Read ${xmlContent.length} bytes from WSL file');
          } else if (result.stdout.isNotEmpty) {
            debugPrint('Nikto WSL output file not found, using stdout (${result.stdout.length} bytes)');
            xmlContent = result.stdout;
          } else {
            debugPrint('Warning: No Nikto WSL output file or stdout, using empty template');
            xmlContent = '<?xml version="1.0"?><niktoscan><scandetails targetip="$ip" targethostname="$ip" targetport="$ports" targetbanner="" starttime="" sitename="" hoststatus="" errors="" checks=""></scandetails></niktoscan>';
          }
          await WSLUtils.deleteWSLFile(outputPath);
        } catch (e) {
          debugPrint('Nikto: Could not read WSL temp file: $e');
          if (result.stdout.isNotEmpty) {
            xmlContent = result.stdout;
          } else {
            xmlContent = '<?xml version="1.0"?><niktoscan><scandetails targetip="$ip" targethostname="$ip" targetport="$ports" targetbanner="" starttime="" sitename="" hoststatus="" errors="" checks=""></scandetails></niktoscan>';
          }
        }
      }

      return xmlContent;
    } catch (e) {
      debugPrint('Process.run failed: $e');
      throw Exception('Nikto execution failed: $e');
    }
  }

  Future<String> _waitForFileCompletion(File file) async {
    int lastSize = 0;
    int stableCount = 0;
    const maxWait = 30;
    
    for (int i = 0; i < maxWait; i++) {
      if (!await file.exists()) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }
      
      final currentSize = await file.length();
      if (currentSize == lastSize) {
        stableCount++;
        if (stableCount >= 3) break;
      } else {
        stableCount = 0;
        lastSize = currentSize;
      }
      
      await Future.delayed(const Duration(seconds: 1));
    }
    
    try {
      return await file.readAsString();
    } catch (e) {
      debugPrint('Failed to read file as UTF-8, trying Latin-1: $e');
      return await file.readAsString(encoding: latin1);
    }
  }

  Future<void> parseAndStoreResults(int deviceId, String xmlData) async {
    try {
      await _findingsRepo.deleteNiktoFindings(deviceId);

      // Sanitize XML: Remove all <?xml ... ?> declarations and <!DOCTYPE ...>
      String sanitizedXml = xmlData
          .replaceAll(RegExp(r'<\?xml.*?\?>'), '')
          .replaceAll(RegExp(r'<!DOCTYPE.*?>', caseSensitive: false), '');
      
      // Wrap in a single root element to handle multiple scan results concatenated
      sanitizedXml = '<root>$sanitizedXml</root>';

      // Collect all findings first, then batch insert
      final findings = <Map<String, String>>[];

      final document = XmlDocument.parse(sanitizedXml);

      // Find all scandetails elements
      for (final scanDetails in document.findAllElements('scandetails')) {
        // Find all item elements within scandetails
        for (final item in scanDetails.findElements('item')) {
          final itemId = _extractCData(item.getAttribute('id') ?? '');
          final description = _extractCData(item.findElements('description').firstOrNull?.innerText ?? '');
          final uri = _extractCData(item.findElements('uri').firstOrNull?.innerText ?? '');
          final namelink = _extractCData(item.findElements('namelink').firstOrNull?.innerText ?? '');
          final iplink = _extractCData(item.findElements('iplink').firstOrNull?.innerText ?? '');

          // Get references - may have multiple
          final referencesList = <String>[];
          for (final ref in item.findElements('references')) {
            final refUrl = _extractCData(ref.findElements('url').firstOrNull?.innerText ?? '');
            if (refUrl.isNotEmpty) {
              referencesList.add(refUrl);
            }
          }
          final references = referencesList.join(', ');

          // Only add if description is not empty
          if (description.isNotEmpty) {
            findings.add({
              'item_id': itemId,
              'description': description,
              'uri': uri,
              'namelink': namelink,
              'iplink': iplink,
              'references': references,
            });
          }
        }
      }

      // Batch insert all findings in a single transaction
      if (findings.isNotEmpty) {
        await _findingsRepo.batchInsertNiktoFindings(deviceId, findings);
      }
    } catch (e) {
      debugPrint('Failed to process Nikto results: $e');
    }
  }

  /// Extracts text from CDATA blocks and returns empty string for empty CDATA
  String _extractCData(String text) {
    if (text.isEmpty) return '';

    // Remove CDATA markers if present
    String cleaned = text.trim();
    if (cleaned.startsWith('<![CDATA[') && cleaned.endsWith(']]>')) {
      cleaned = cleaned.substring(9, cleaned.length - 3);
    }

    return cleaned.trim();
  }
}
