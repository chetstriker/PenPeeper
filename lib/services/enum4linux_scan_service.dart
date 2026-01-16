import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:penpeeper/services/config_service.dart';
import 'package:penpeeper/services/command_path_resolver.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'package:penpeeper/repositories/findings_data_repository.dart';
import 'package:penpeeper/utils/privileged_runner.dart';

class Enum4linuxScanService {
  final _pathResolver = CommandPathResolver();
  final FindingsDataRepository _findingsRepo = FindingsDataRepository();

  Future<String> runEnum4linuxScan(String ip) async {
    String? outputFile;
    try {
      String command;
      List<String> args;

      if (ConfigService.isLinux || ConfigService.isMacOS) {
        // enum4linux-ng adds .json extension automatically, so we need path without extension
        final tempPath = AppPathsService().getTempScanPath('temp_enum4linux_${ip.replaceAll('.', '_')}', 'json');
        final tempFile = tempPath.substring(0, tempPath.length - 5); // Remove .json extension
        
        command = await _pathResolver.requireCommandPath('enum4linux-ng');
        args = [ip, '-oJ', tempFile];
        outputFile = '$tempFile.json';
      } else {
        // For Windows/WSL, use a simple filename in /tmp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final tempFile = '/tmp/enum4linux_${ip.replaceAll('.', '_')}_$timestamp';
        
        command = 'wsl.exe';
        args = ['enum4linux-ng', ip, '-oJ', tempFile];
        outputFile = '$tempFile.json';
      }
      
      debugPrint('=== ENUM4LINUX COMMAND EXECUTION ===');
      debugPrint('Command: $command');
      debugPrint('Args: ${args.join(" ")}');
      debugPrint('Full command line: $command ${args.join(" ")}');
      debugPrint('Working directory: ${Directory.current.path}');
      debugPrint('Platform: ${Platform.operatingSystem}');
      debugPrint('Has privileged password: ${PrivilegedRunner.hasPassword}');
      debugPrint('Will use elevated privileges: ${(ConfigService.isMacOS || ConfigService.isLinux) && PrivilegedRunner.hasPassword}');

      ProcessResult result;
      if ((ConfigService.isMacOS || ConfigService.isLinux) && PrivilegedRunner.hasPassword) {
        debugPrint('>>> RUNNING WITH ELEVATED PRIVILEGES (using stored password) <<<');
        result = await PrivilegedRunner.run(command, args);
        debugPrint('Elevated command completed with exit code: ${result.exitCode}');
      } else {
        debugPrint('>>> RUNNING WITHOUT ELEVATED PRIVILEGES (normal user) <<<');

        // Use a safe working directory (same logic as PrivilegedRunner)
        // When launched from desktop shortcuts, CWD might be root or C:\
        final workingDir = (Directory.current.path == '/' || Directory.current.path == 'C:\\' || Directory.current.path == 'C:/')
            ? path.dirname(Platform.resolvedExecutable)
            : Directory.current.path;
        debugPrint('Working directory for command: $workingDir');
        debugPrint('Platform.resolvedExecutable: ${Platform.resolvedExecutable}');

        result = await Process.run(
          command,
          args,
          workingDirectory: workingDir,
        );
        debugPrint('Non-elevated command completed with exit code: ${result.exitCode}');
      }
      debugPrint('====================================');

      String jsonContent = '';
      if (ConfigService.isLinux || ConfigService.isMacOS) {
        final outputFileObj = File(outputFile);
        debugPrint('Enum4Linux: Checking for output file at: ${outputFileObj.path}');
        if (await outputFileObj.exists()) {
          jsonContent = await outputFileObj.readAsString();
          debugPrint('Enum4Linux: Output file size: ${jsonContent.length} bytes');
          try {
            await outputFileObj.delete();
          } catch (e) {
            debugPrint('Warning: Could not delete temp file: $e');
          }
        } else {
          debugPrint('Enum4Linux: Output file not found');
        }
      } else {
        // For Windows/WSL, read the file from WSL and then delete it
        try {
          final catResult = await Process.run('wsl.exe', ['cat', outputFile]);
          if (catResult.exitCode == 0) {
            jsonContent = catResult.stdout;
            debugPrint('Enum4Linux: Read ${jsonContent.length} bytes from WSL file');
          }
          // Clean up the WSL temp file
          await Process.run('wsl.exe', ['rm', '-f', outputFile]);
        } catch (e) {
          debugPrint('Enum4Linux: Could not read WSL temp file: $e');
        }
      }

      if (result.exitCode != 0 && jsonContent.isEmpty) {
        debugPrint('Enum4Linux: Exit code: ${result.exitCode}, stderr: ${result.stderr}');
        throw Exception('enum4linux-ng scan failed: ${result.stderr}');
      }

      return jsonContent.isNotEmpty ? jsonContent : result.stdout;
    } catch (e) {
      // Clean up temp files on error
      if (outputFile != null) {
        if (ConfigService.isLinux || ConfigService.isMacOS) {
          try {
            final outputFileObj = File(outputFile!);
            if (await outputFileObj.exists()) {
              await outputFileObj.delete();
            }
          } catch (_) {}
        } else {
          try {
            await Process.run('wsl.exe', ['rm', '-f', outputFile!]);
          } catch (_) {}
        }
      }
      rethrow;
    }
  }

  Future<void> parseAndStoreResults(int deviceId, String jsonData) async {
    try {
      await _findingsRepo.deleteSambaLdapFindings(deviceId);

      // Collect all findings first, then batch insert
      final findings = <Map<String, String>>[];

      final data = json.decode(jsonData) as Map<String, dynamic>;

      final smbDialects = data['smb_dialects'] as Map<String, dynamic>?;
      if (smbDialects != null) {
        final supportedDialects = smbDialects['Supported dialects'] as Map<String, dynamic>?;
        if (supportedDialects?['SMB 1.0'] == true) {
          findings.add({'type': 'SMB 1.0 Enabled', 'value': 'SMB 1.0 protocol is enabled (security risk)'});
        }
      }

      final sessions = data['sessions'] as Map<String, dynamic>?;
      if (sessions != null) {
        if (sessions['sessions_possible'] == true) {
          findings.add({'type': 'Sessions Possible', 'value': 'SMB sessions are possible'});
        }
        if (sessions['null'] == true) {
          findings.add({'type': 'Null Sessions', 'value': 'Null sessions are allowed (security risk)'});
        }
        if (sessions['password'] == false) {
          findings.add({'type': 'No Password Required', 'value': 'Password authentication not required'});
        }
      }

      final users = data['users'];
      if (users != null && users is Map && users.isNotEmpty) {
        findings.add({'type': 'Users Enumerated', 'value': '${users.length} users found'});
        for (final entry in users.entries) {
          final userInfo = entry.value as Map<String, dynamic>;
          final username = userInfo['username'] ?? 'Unknown';
          final description = userInfo['description'] ?? '';
          findings.add({'type': 'User', 'value': '$username${description.isNotEmpty ? " - $description" : ""}'});
        }
      }

      final groups = data['groups'];
      if (groups != null && groups is Map && groups.isNotEmpty) {
        findings.add({'type': 'Groups Enumerated', 'value': '${groups.length} groups found'});
        for (final entry in groups.entries) {
          final groupInfo = entry.value as Map<String, dynamic>;
          final groupname = groupInfo['groupname'] ?? 'Unknown';
          final type = groupInfo['type'] ?? '';
          findings.add({'type': 'Group', 'value': '$groupname${type.isNotEmpty ? " ($type)" : ""}'});
        }
      }

      final smbDomainInfo = data['smb_domain_info'] as Map<String, dynamic>?;
      if (smbDomainInfo != null) {
        final fqdn = smbDomainInfo['FQDN'];
        if (fqdn != null && fqdn.toString().isNotEmpty) {
          findings.add({'type': 'FQDN', 'value': fqdn.toString()});
        }
      }

      final osInfo = data['os_info'] as Map<String, dynamic>?;
      if (osInfo != null) {
        final os = osInfo['OS'];
        if (os != null && os.toString().isNotEmpty) {
          findings.add({'type': 'OS', 'value': os.toString()});
        }

        final osVersion = osInfo['OS version'];
        if (osVersion != null && osVersion.toString().isNotEmpty) {
          findings.add({'type': 'OS Version', 'value': osVersion.toString()});
        }

        final osRelease = osInfo['OS release'];
        if (osRelease != null && osRelease.toString().isNotEmpty) {
          findings.add({'type': 'OS Release', 'value': osRelease.toString()});
        }

        final osBuild = osInfo['OS build'];
        if (osBuild != null && osBuild.toString().isNotEmpty) {
          findings.add({'type': 'OS Build', 'value': osBuild.toString()});
        }

        final nativeOs = osInfo['Native OS'];
        if (nativeOs != null && nativeOs.toString().isNotEmpty) {
          findings.add({'type': 'Native OS', 'value': nativeOs.toString()});
        }

        final nativeLanManager = osInfo['Native LAN manager'];
        if (nativeLanManager != null && nativeLanManager.toString().isNotEmpty) {
          findings.add({'type': 'Native LAN Manager', 'value': nativeLanManager.toString()});
        }
      }

      // Batch insert all findings in a single transaction
      if (findings.isNotEmpty) {
        await _findingsRepo.batchInsertSambaLdapFindings(deviceId, findings);
      }

      final shares = data['shares'] as Map<String, dynamic>?;
      if (shares != null && shares.isNotEmpty) {
        final interestingShares = shares.keys.where((key) => key != 'IPC\$' && key != 'SYSVOL').toList();
        if (interestingShares.isNotEmpty) {
          await _findingsRepo.insertSambaLdapFinding(deviceId, 'Shares Found', 'Accessible shares: ${interestingShares.join(', ')}');
        }
      }
    } catch (e) {
      debugPrint('Failed to process SAMBA/LDAP results: $e');
    }
  }
}
