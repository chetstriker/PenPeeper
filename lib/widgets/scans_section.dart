import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:penpeeper/repositories/scan_repository.dart';
import 'package:penpeeper/models.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/decorated_dialog_title.dart';
import 'package:penpeeper/services/scan_orchestrator.dart';
import 'package:penpeeper/services/scan_status_service.dart';
import 'package:penpeeper/services/nmap_scan_service.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/quill_scan_dialog.dart';
import 'package:penpeeper/quill_flag_dialog.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/repositories/project_repository.dart';
import 'package:penpeeper/models/cvss/cvss_data.dart';

import 'package:penpeeper/screens/project_screen.dart';
import 'package:penpeeper/widgets/scan_components/index.dart';
import 'package:penpeeper/widgets/import_scan_modal.dart';
import 'package:penpeeper/widgets/macos_password_prompt.dart';
import 'package:penpeeper/services/config_service.dart';
import 'package:penpeeper/utils/privileged_runner.dart';
import 'package:penpeeper/utils/debug_logger.dart';

class ScansSection extends StatefulWidget {
  final Device device;
  final VoidCallback onDataChanged;
  final String projectName;

  const ScansSection({
    super.key,
    required this.device,
    required this.onDataChanged,
    required this.projectName,
  });

  @override
  State<ScansSection> createState() => _ScansSectionState();
}

class _ScansSectionState extends State<ScansSection> {
  List<Scan> scans = <Scan>[];
  final _scanRepo = ScanRepository();
  final _scanOrchestrator = ScanOrchestrator();
  final _nmapService = NmapScanService();
  final _findingsRepo = FindingsRepository();
  final _projectRepo = ProjectRepository();
  final Map<String, bool> _scanningStates = {};

  Future<Map<String, String>> _loadConfig() async {
    try {
      final configFile = File('config.json');
      if (await configFile.exists()) {
        final configContent = await configFile.readAsString();
        final config = json.decode(configContent);
        return Map<String, String>.from(config['tools']);
      }
    } catch (e) {
      debugPrint('Failed to load config: $e');
    }
    if (Platform.isLinux) {
      return {
        'perl': 'perl',
        'nikto': 'nikto',
        'nmap_scanner': 'nmap',

        'nmap_processor': './nmap_processor',
        'searchsploit_scanner': './searchsploit_scanner',
      };
    }
    return {
      'perl': r'C:\Strawberry\perl\bin\perl.exe',
      'nikto': r'C:\nikto\program\nikto.pl',
      'nmap_scanner': 'nmap_scanner.exe',

      'nmap_processor': 'nmap_processor.exe',
      'searchsploit_scanner': 'searchsploit_scanner.exe',
    };
  }

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  Future<void> _loadScans() async {
    final scanList = await _scanRepo.getScans(widget.device.id);
    if (mounted) {
      setState(() {
        scans = scanList;
      });
    }
  }

  String _formatErrorMessage(Object error, String scanType) {
    final errorStr = error.toString();

    // Handle common error patterns
    if (errorStr.contains('TimeoutException') || errorStr.contains('timed out')) {
      return '$scanType scan timed out';
    } else if (errorStr.contains('No targets found')) {
      return 'No targets found for $scanType scan';
    } else if (errorStr.contains('Device needs AUTO NMAP')) {
      return 'Device needs AUTO NMAP scan first';
    } else if (errorStr.contains('Connection refused') || errorStr.contains('Failed to connect')) {
      return '$scanType scan failed: Connection refused';
    } else if (errorStr.contains('Permission denied')) {
      return '$scanType scan failed: Permission denied';
    } else if (errorStr.contains('No such file or directory')) {
      return '$scanType scan failed: Tool not found';
    } else if (errorStr.contains('Exception:')) {
      // Extract just the exception message without the full stack
      final exceptionMatch = RegExp(r'Exception:\s*(.+?)(?:\n|$)').firstMatch(errorStr);
      if (exceptionMatch != null) {
        return '$scanType scan failed: ${exceptionMatch.group(1)}';
      }
    }

    // For other errors, provide a generic message but log the full error
    debugPrint('$scanType scan error: $error');
    return '$scanType scan failed';
  }

  Future<void> _startNewScan() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => QuillScanDialog(
        deviceName: widget.device.name,
        projectName: widget.projectName,
      ),
    );

    if (result != null) {
      await _scanRepo.insertScan(widget.device.id, result['name'], result['content']);
      _loadScans();
      widget.onDataChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan added successfully')),
        );
      }
    }
  }

  Future<void> _importScan() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ImportScanModal(
        projectName: widget.projectName,
      ),
    );

    if (result != null) {
      await _scanRepo.insertScan(widget.device.id, result['name'], result['content']);
      _loadScans();
      widget.onDataChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan imported successfully')),
        );
      }
    }
  }

  Future<void> _editScan(Scan scan) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => QuillScanDialog(
        deviceName: widget.device.name,
        initialContent: scan.result,
        initialName: scan.scanType,
        isEditing: true,
        projectName: widget.projectName,
      ),
    );

    if (result != null) {
      await _scanRepo.updateScan(scan.id, result['name'], result['content']);
      _loadScans();
      widget.onDataChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan updated successfully')),
        );
      }
    }
  }





  Future<void> _exportScanToFile(Scan scan) async {
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = '${widget.device.name}_${scan.scanType}_$timestamp.txt';
      
      if (kIsWeb) {
        final bytes = utf8.encode(scan.result);
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Export Scan',
          fileName: fileName,
          bytes: bytes,
        );
        if (result != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Scan exported successfully')),
          );
        }
      } else {
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Export Scan',
          fileName: fileName,
        );
        if (result != null) {
          final file = File(result);
          await file.writeAsString(scan.result);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scan exported to: $result')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteScan(Scan scan) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
        title: const DecoratedDialogTitle('Delete Scan'),
        content: Text('Are you sure you want to delete "${scan.scanType}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      if (kIsWeb) {
        try {
          final response = await http.delete(
            Uri.parse('/api/scans/${scan.id}'),
          );
          if (response.statusCode == 200) {
            _loadScans();
            widget.onDataChanged();
          } else {
            throw Exception('Failed to delete scan');
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      } else {
        await _scanRepo.deleteScan(scan.id);
        _loadScans();
        widget.onDataChanged();
      }
    }
  }

  Future<void> _runAutomateScan() async {
    // Check for existing scans and show confirmation dialog
    final scans = await _scanRepo.getScans(widget.device.id);
    final hasExistingScans = scans.any((scan) => scan.scanType == 'AUTO NMAP');
    String? scanOption = 'replace';
    
    if (hasExistingScans) {
      if (!mounted) return;
      scanOption = await showDialog<String?>(
        context: context,
        builder: (context) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
          title: const DecoratedDialogTitle('NMAP Scans'),
          content: const Text('Choose how to handle existing AUTO NMAP scans:', textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'replace'),
              child: const Text('Replace existing NMAP Scans'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'skip'),
              child: const Text('Skip if already scanned'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
    
    if (scanOption == null) return; // User cancelled
    
    if (scanOption == 'skip' && hasExistingScans) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device already has NMAP scans')),
        );
      }
      return;
    }

    // Prompt for password on macOS/Linux/Web if needed
    if ((ConfigService.isMacOS || ConfigService.isLinux || kIsWeb) && !PrivilegedRunner.hasPassword) {
      final hasPassword = await MacOSPasswordPrompt.promptIfNeeded(context);
      if (!hasPassword) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Administrator access required for scanning')),
          );
        }
        return;
      }
    }

    final statusId = ScanStatusService().startScan(scanType: 'NMAP', totalDevices: 1);
    ScanStatusService().updateScanProgress(id: statusId, activeDevices: [widget.device.ipAddress], completed: 0);
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('/api/devices/${widget.device.id}/scan'),
        );
        if (response.statusCode == 200) {
          _loadScans();
          widget.onDataChanged();
          ScanStatusService().completeScan(statusId);
        } else {
          throw Exception('Scan failed');
        }
      } catch (e) {
        ScanStatusService().completeScan(statusId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_formatErrorMessage(e, 'NMAP'))),
        );
      }
      return;
    }
    try {
      final scanResult = await _runDeviceScan(widget.device.ipAddress);
      await _scanRepo.insertScan(widget.device.id, 'AUTO NMAP', scanResult);
      
      final projectState = context.findAncestorStateOfType<ProjectScreenState>();
      final projectId = widget.device.projectId;
      
      final success = await _nmapService.processNmapResults(widget.device.id, projectId, scanResult);
      
      if (!success) {
        debugPrint('Failed to process nmap results');
      }
      
      _loadScans();
      widget.onDataChanged();
      ScanStatusService().completeScan(statusId);

      // Trigger device list refresh in parent
      if (!mounted) return;
      projectState?.loadDevices();
    } catch (e) {
      ScanStatusService().completeScan(statusId);
      debugPrint('Scan failed: $e');
    }
  }

  Future<String> _runDeviceScan(String target) async {
    return await _nmapService.runDeviceScan(target);
  }

  Future<void> _runSingleDeviceNiktoScan() async {
    await _runGenericScan(
      scanType: 'NIKTO AUTO',
      displayName: 'Nikto',
      apiEndpoint: '/api/devices/${widget.device.id}/nikto',
      desktopScan: () => _scanOrchestrator.runNiktoScanForDevice(widget.device.id, replaceExisting: true),
      requiresNmap: false,
      webExtraBody: {'ip': widget.device.ipAddress},
      requiresPrivileges: true,
    );
  }

  Future<void> _runGenericScan({
    required String scanType,
    required String displayName,
    required String apiEndpoint,
    required Future<bool> Function() desktopScan,
    bool requiresNmap = false,
    Map<String, Object>? webExtraBody,
    bool showLongRunningMessage = false,
    bool requiresPrivileges = false,
  }) async {
    debugPrint('!!! _runGenericScan ENTRY - scanType: $scanType, displayName: $displayName !!!');
    final logger = DebugLogger();
    await logger.log('GENERIC_SCAN', '========== _runGenericScan CALLED ==========');
    await logger.log('GENERIC_SCAN', 'Scan type: $scanType');
    await logger.log('GENERIC_SCAN', 'Display name: $displayName');
    await logger.log('GENERIC_SCAN', 'Requires privileges: $requiresPrivileges');
    await logger.flush();
    debugPrint('!!! _runGenericScan after initial logs !!!');

    // Prompt for password on macOS/Linux if scan requires privileges
    if (requiresPrivileges && (ConfigService.isMacOS || ConfigService.isLinux || kIsWeb) && !PrivilegedRunner.hasPassword) {
      await logger.log('GENERIC_SCAN', 'Checking for password...');
      await logger.flush();
      final hasPassword = await MacOSPasswordPrompt.promptIfNeeded(context);
      await logger.log('GENERIC_SCAN', 'Password prompt result: $hasPassword');
      await logger.flush();
      if (!hasPassword) {
        await logger.log('GENERIC_SCAN', 'No password provided, aborting scan');
        await logger.flush();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Administrator access required for scanning')),
          );
        }
        return;
      }
    } else {
      await logger.log('GENERIC_SCAN', 'Password check not required or already has password');
      await logger.flush();
    }

    await logger.log('GENERIC_SCAN', 'Starting scan status service...');
    await logger.flush();

    final statusId = ScanStatusService().startScan(
      scanType: displayName,
      totalDevices: 1,
    );
    ScanStatusService().updateScanProgress(
      id: statusId,
      activeDevices: [widget.device.ipAddress],
      completed: 0,
    );

    await logger.log('GENERIC_SCAN', 'Status service started, fetching existing scans...');
    await logger.flush();

    debugPrint('!!! About to fetch scans from database !!!');
    try {
      final scans = await _scanRepo.getScans(widget.device.id);
      debugPrint('!!! Database returned ${scans.length} scans !!!');
      await logger.log('GENERIC_SCAN', 'Found ${scans.length} existing scans');
      await logger.flush();
      
      if (requiresNmap && !scans.any((scan) => scan.scanType == 'AUTO NMAP')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device needs AUTO NMAP scan first')),
          );
        }
        return;
      }

      final hasExistingScans = scans.any((scan) => scan.scanType == scanType);
      await logger.log('GENERIC_SCAN', 'Has existing scans: $hasExistingScans');
      await logger.flush();

      String? scanOption = 'replace';

      if (hasExistingScans) {
        await logger.log('GENERIC_SCAN', 'Showing dialog for existing scans...');
        await logger.flush();
        if (!mounted) return;
        scanOption = await showDialog<String?>(
          context: context,
          builder: (context) => AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
            title: DecoratedDialogTitle('$displayName Scans'),
            content: Text('Choose how to handle existing $scanType scans:', textAlign: TextAlign.center),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'replace'),
                child: Text('Replace existing $displayName Scans'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'skip'),
                child: const Text('Skip if already scanned'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
        await logger.log('GENERIC_SCAN', 'Dialog closed, scanOption: $scanOption');
        await logger.flush();
      }

      if (scanOption == null) {
        await logger.log('GENERIC_SCAN', 'User cancelled, returning');
        await logger.flush();
        return; // User cancelled
      }

      if (scanOption == 'skip' && hasExistingScans) {
        await logger.log('GENERIC_SCAN', 'Skip option selected, returning');
        await logger.flush();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Device already has $displayName scans')),
          );
        }
        return;
      }

      if (showLongRunningMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Running $displayName scan...'), duration: const Duration(hours: 1)),
        );
      }

      await logger.log('GENERIC_SCAN', 'Checking if web mode...');
      await logger.flush();

      if (kIsWeb) {
        final body = <String, dynamic>{'replace': scanOption == 'replace'};
        if (webExtraBody != null) body.addAll(webExtraBody);
        
        final response = await http.post(
          Uri.parse(apiEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );
        
        if (showLongRunningMessage && mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
        
        if (response.statusCode == 200) {
          final cache = ProjectDataCache();
          await cache.reloadDevices(widget.device.projectId);
          _loadScans();
          widget.onDataChanged();
          ScanStatusService().completeScan(statusId);
        } else {
          throw Exception('Scan failed');
        }
      } else {
        debugPrint('!!! Desktop mode - about to call desktopScan() !!!');
        await logger.log('GENERIC_SCAN', 'Desktop mode - calling desktopScan()...');
        await logger.flush();
        debugPrint('!!! Calling desktopScan() NOW !!!');
        final success = await desktopScan();
        debugPrint('!!! desktopScan() RETURNED with success=$success !!!');
        await logger.log('GENERIC_SCAN', 'desktopScan() returned: $success');
        await logger.flush();
        if (showLongRunningMessage && mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
        if (!success) {
          await logger.log('GENERIC_SCAN', 'Scan failed - no targets found');
          await logger.flush();
          throw Exception('No targets found for $displayName scan');
        }
        await logger.log('GENERIC_SCAN', 'Loading scans...');
        await logger.flush();
        _loadScans();
        await logger.log('GENERIC_SCAN', 'Completing scan status...');
        await logger.flush();
        ScanStatusService().completeScan(statusId);
        await logger.log('GENERIC_SCAN', 'Scan completed successfully');
        await logger.flush();
      }
    } catch (e) {
      if (showLongRunningMessage && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      ScanStatusService().completeScan(statusId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_formatErrorMessage(e, displayName))),
        );
      }
    }
  }

  Future<void> _runSingleDeviceSearchsploitScan() async {
    final device = Device(
      id: widget.device.id,
      projectId: widget.device.projectId,
      name: widget.device.name,
      ipAddress: widget.device.ipAddress,
    );

    await _runGenericScan(
      scanType: 'AUTO SEARCHSPLOIT',
      displayName: 'SearchSploit',
      apiEndpoint: '/api/devices/${widget.device.id}/searchsploit',
      desktopScan: () => _scanOrchestrator.runSearchsploitScan(device, replaceExisting: true),
      requiresNmap: true,
      showLongRunningMessage: true,
      requiresPrivileges: true,
    );
  }

  Future<void> _runSingleDeviceWhatwebScan() async {
    final device = Device(
      id: widget.device.id,
      projectId: widget.device.projectId,
      name: widget.device.name,
      ipAddress: widget.device.ipAddress,
    );

    await _runGenericScan(
      scanType: 'AUTO WHATWEB',
      displayName: 'WhatWeb',
      apiEndpoint: '/api/devices/${widget.device.id}/whatweb',
      desktopScan: () => _scanOrchestrator.runWhatwebScan(device, replaceExisting: true),
      requiresNmap: true,
      showLongRunningMessage: true,
      requiresPrivileges: true,
    );
  }

  Future<void> _runSingleDeviceSambaLdapScan() async {
    await _runGenericScan(
      scanType: 'AUTO SAMBA/LDAP',
      displayName: 'SAMBA/LDAP',
      apiEndpoint: '/api/devices/${widget.device.id}/enum4linux',
      desktopScan: () => _scanOrchestrator.runEnum4linuxScanForDevice(widget.device.id, replaceExisting: true),
      requiresNmap: false,
      requiresPrivileges: true,
    );
  }

  Future<void> _runSingleDeviceFfufScan() async {
    await _runGenericScan(
      scanType: 'AUTO FUZZER',
      displayName: 'FFUF',
      apiEndpoint: '/api/devices/${widget.device.id}/ffuf',
      desktopScan: () => _scanOrchestrator.runFfufScanForDevice(widget.device.id, replaceExisting: true),
      requiresNmap: true,
      showLongRunningMessage: true,
      requiresPrivileges: true,
    );
  }

  Future<void> _runSingleDeviceSnmpScan() async {
    // CRITICAL: First line - print to console immediately
    debugPrint('!!! SCANS TAB SNMP BUTTON CLICKED - ENTRY POINT !!!');
    debugPrint('!!! Device: ${widget.device.name} (${widget.device.ipAddress}) !!!');

    final logger = DebugLogger();
    await logger.log('SCANS_TAB_SNMP', '========== SCANS TAB SNMP BUTTON CLICKED ==========');
    await logger.log('SCANS_TAB_SNMP', 'Device ID: ${widget.device.id}');
    await logger.log('SCANS_TAB_SNMP', 'Device name: ${widget.device.name}');
    await logger.log('SCANS_TAB_SNMP', 'Device IP: ${widget.device.ipAddress}');
    await logger.flush();

    debugPrint('!!! After initial logs, about to create Device object !!!');

    final device = Device(
      id: widget.device.id,
      projectId: widget.device.projectId,
      name: widget.device.name,
      ipAddress: widget.device.ipAddress,
    );

    debugPrint('!!! About to call _runGenericScan !!!');
    await logger.log('SCANS_TAB_SNMP', 'Calling _runGenericScan...');
    await logger.flush();

    debugPrint('!!! Calling _runGenericScan NOW !!!');
    await _runGenericScan(
      scanType: 'SNMP AUTO',
      displayName: 'SNMP',
      apiEndpoint: '/api/devices/${widget.device.id}/snmp',
      desktopScan: () async {
        debugPrint('!!! INSIDE desktopScan lambda - FIRST LINE !!!');
        await logger.log('SCANS_TAB_SNMP', 'Inside desktopScan lambda, about to call runSnmpScan...');
        await logger.flush();
        debugPrint('!!! About to call _scanOrchestrator.runSnmpScan !!!');
        final success = await _scanOrchestrator.runSnmpScan(device, widget.device.projectId, replaceExisting: true);
        debugPrint('!!! _scanOrchestrator.runSnmpScan COMPLETED with success=$success !!!');
        await logger.log('SCANS_TAB_SNMP', 'runSnmpScan returned: $success');
        await logger.flush();
        if (success) {
          await logger.log('SCANS_TAB_SNMP', 'Reloading devices cache...');
          await logger.flush();
          final cache = ProjectDataCache();
          await cache.reloadDevices(widget.device.projectId);
          await logger.log('SCANS_TAB_SNMP', 'Cache reloaded');
          await logger.flush();
        }
        return success;
      },
      requiresPrivileges: true,  // SNMP requires root on macOS
      requiresNmap: false,
    );

    await logger.log('SCANS_TAB_SNMP', '_runGenericScan returned');
    await logger.flush();
  }

  Future<void> _runSingleDeviceProcessNmap() async {
    final statusId = ScanStatusService().startScan(scanType: 'Process NMAP', totalDevices: 1);
    ScanStatusService().updateScanProgress(id: statusId, activeDevices: [widget.device.ipAddress], completed: 0);
    final projectState = context.findAncestorStateOfType<ProjectScreenState>();
    if (projectState == null) return;
    
    try {
      final scans = await _scanRepo.getScans(widget.device.id);
      final nmapScan = scans.where((scan) => scan.scanType == 'AUTO NMAP').toList();
      
      if (nmapScan.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device needs AUTO NMAP scan first')),
          );
        }
        return;
      }

      for (final scan in nmapScan) {
        final tempFile = File('temp_nmap_${widget.device.id}_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}.xml');
        await tempFile.writeAsString(scan.result);
        
        final config = await _loadConfig();
        final result = await Process.run(
          config['nmap_processor']!,
          ['penpeeper.db', widget.device.id.toString(), widget.device.projectId.toString(), tempFile.path],
          workingDirectory: Directory.current.path,
        );
        
        try {
          await tempFile.delete();
        } catch (e) {
          debugPrint('Warning: Could not delete temp file: $e');
        }
        
        if (result.exitCode != 0) {
          debugPrint('Failed to process nmap results: ${result.stderr}');
        }
      }
      
      if (context.mounted) {
        projectState.loadDevices();
      }
      ScanStatusService().completeScan(statusId);
    } catch (e) {
      ScanStatusService().completeScan(statusId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatErrorMessage(e, 'NMAP processing'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppTheme.surfaceColor,
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: _startNewScan,
                child: const Text('ADD NEW SCAN'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _importScan,
                child: const Text('Import Scan'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ScanToolbar(
                  isScanning: false,
                  onNmap: _runAutomateScan,
                  onNikto: _runSingleDeviceNiktoScan,
                  onSearchsploit: _runSingleDeviceSearchsploitScan,
                  onWhatweb: _runSingleDeviceWhatwebScan,
                  onEnum4linux: _runSingleDeviceSambaLdapScan,
                  onFfuf: _runSingleDeviceFfufScan,
                  onSnmp: _runSingleDeviceSnmpScan,
                  onProcessNmap: _runSingleDeviceProcessNmap,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: scans.isEmpty
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'No scan data has been added yet',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: scans.length,
                  itemBuilder: (context, index) {
                    final scan = scans[index];
                    return ScanListItem(
                      scan: scan,
                      onTap: () => _editScan(scan),
                      onExport: () => _exportScanToFile(scan),
                      onDelete: () => _deleteScan(scan),
                      onFlag: () => _flagScan(scan),
                    );
                  },
                ),
        ),
      ],
    );
  }



  Future<void> _flagScan(Scan scan) async {
    final flagResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => QuillFlagDialog(
        deviceName: widget.device.name,
        projectName: widget.projectName,
        onSubmit: (type, content) {},
        initialComment: jsonEncode([{"insert": "Read over scan results in the Evidence tab and replace this with an appropriate description of the finding.\n"}]),
        initialEvidence: scan.result,
      ),
    );

    if (flagResult != null) {
      final id = await _findingsRepo.insertFlaggedFinding(
        widget.device.id,
        widget.device.name,
        widget.device.ipAddress,
        flagResult['type'],
        flagResult['comment'],
        findingType: 'MANUAL',
        projectId: widget.device.projectId,
      );

      if (flagResult['evidence'] != null) {
        await _findingsRepo.updateFlaggedFindingEvidence(
          id,
          flagResult['evidence'],
        );
      }
      
      if (flagResult['recommendation'] != null) {
        await _findingsRepo.updateFlaggedFindingRecommendation(
          id,
          flagResult['recommendation'],
        );
      }

      if (flagResult['cvssData'] != null) {
        final cvss = flagResult['cvssData'] as CvssData;
        await _findingsRepo.updateFlaggedFindingCvss(
          id,
          attackVector: cvss.attackVector?.name,
          attackComplexity: cvss.attackComplexity?.name,
          privilegesRequired: cvss.privilegesRequired?.name,
          userInteraction: cvss.userInteraction?.name,
          scope: cvss.scope?.name,
          confidentialityImpact: cvss.confidentialityImpact?.name,
          integrityImpact: cvss.integrityImpact?.name,
          availabilityImpact: cvss.availabilityImpact?.name,
          cvssBaseScore: cvss.baseScore,
          cvssSeverity: cvss.severity?.name,
        );
      }
      
      if (flagResult['classification'] != null) {
        final classification = flagResult['classification'] as Map<String, dynamic>;
        final vulnRepo = VulnerabilityRepository();
        if (classification['category'] != null && classification['subcategory'] != null && classification['scope'] != null) {
          await vulnRepo.insertVulnerabilityClassification(
            projectId: widget.device.projectId,
            deviceId: widget.device.id,
            findingId: id,
            category: classification['category'],
            subcategory: classification['subcategory'],
            description: '',
            mappedOwasp: '',
            mappedCwe: '',
            severityGuideline: '',
            scope: classification['scope'],
          );
        }
      }

      widget.onDataChanged();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finding added successfully')),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}



