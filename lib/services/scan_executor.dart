import 'package:penpeeper/services/scan_orchestrator.dart';
import 'package:penpeeper/services/status_notification_service.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/repositories/scan_repository.dart';
import 'package:penpeeper/utils/debug_logger.dart';

/// Generic scan execution strategy
abstract class ScanStrategy {
  String get scanType;
  
  Future<Map<String, dynamic>> execute(
    ScanOrchestrator orchestrator,
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  );
}

class NmapScanStrategy extends ScanStrategy {
  @override
  String get scanType => 'AUTO NMAP';

  @override
  Future<Map<String, dynamic>> execute(
    ScanOrchestrator orchestrator,
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  ) async {
    final cache = ProjectDataCache();
    final devices = cache.devices;
    
    if (devices.isEmpty) {
      return {'completed': 0, 'failed': 0, 'total': 0};
    }

    orchestrator.resetCancel('NMAP');
    final result = await orchestrator.runAutomatedDeviceScans(
      projectId,
      devices,
      replaceExisting,
      onProgress,
    );

    return result;
  }
}

class NiktoScanStrategy extends ScanStrategy {
  @override
  String get scanType => 'NIKTO AUTO';

  @override
  Future<Map<String, dynamic>> execute(
    ScanOrchestrator orchestrator,
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  ) {
    orchestrator.resetCancel('NIKTO');
    return orchestrator.runNiktoScans(projectId, replaceExisting, onProgress);
  }
}

class SearchsploitScanStrategy extends ScanStrategy {
  @override
  String get scanType => 'AUTO SEARCHSPLOIT';

  @override
  Future<Map<String, dynamic>> execute(
    ScanOrchestrator orchestrator,
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  ) {
    orchestrator.resetCancel('SEARCHSPLOIT');
    return orchestrator.runSearchsploitScans(projectId, replaceExisting, onProgress);
  }
}

class WhatwebScanStrategy extends ScanStrategy {
  @override
  String get scanType => 'AUTO WHATWEB';

  @override
  Future<Map<String, dynamic>> execute(
    ScanOrchestrator orchestrator,
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  ) {
    orchestrator.resetCancel('WHATWEB');
    return orchestrator.runWhatwebScans(projectId, replaceExisting, onProgress);
  }
}

class FfufScanStrategy extends ScanStrategy {
  @override
  String get scanType => 'AUTO FUZZER';

  @override
  Future<Map<String, dynamic>> execute(
    ScanOrchestrator orchestrator,
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  ) {
    orchestrator.resetCancel('FFUF');
    return orchestrator.runFfufScans(projectId, replaceExisting, onProgress);
  }
}

class SambaLdapScanStrategy extends ScanStrategy {
  @override
  String get scanType => 'AUTO SAMBA/LDAP';

  @override
  Future<Map<String, dynamic>> execute(
    ScanOrchestrator orchestrator,
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  ) {
    orchestrator.resetCancel('ENUM4LINUX');
    return orchestrator.runSambaLdapScans(projectId, replaceExisting, onProgress);
  }
}

class SnmpScanStrategy extends ScanStrategy {
  @override
  String get scanType => 'SNMP AUTO';

  @override
  Future<Map<String, dynamic>> execute(
    ScanOrchestrator orchestrator,
    int projectId,
    bool replaceExisting,
    Function(String)? onProgress,
  ) async {
    final logger = DebugLogger();
    await logger.log('SNMP_STRATEGY', '========== PROJECT TOOLBAR SNMP BUTTON CLICKED ==========');
    await logger.log('SNMP_STRATEGY', 'Project ID: $projectId');
    await logger.log('SNMP_STRATEGY', 'Replace existing: $replaceExisting');
    await logger.flush();

    await logger.log('SNMP_STRATEGY', 'Resetting cancel flag...');
    await logger.flush();
    orchestrator.resetCancel('SNMP');

    await logger.log('SNMP_STRATEGY', 'Calling orchestrator.runSnmpScans...');
    await logger.flush();
    final result = await orchestrator.runSnmpScans(projectId, replaceExisting, onProgress);

    await logger.log('SNMP_STRATEGY', 'orchestrator.runSnmpScans returned');
    await logger.log('SNMP_STRATEGY', 'Result: completed=${result['completed']}, failed=${result['failed']}, total=${result['total']}');
    await logger.log('SNMP_STRATEGY', '========== SNMP STRATEGY COMPLETED ==========');
    await logger.flush();

    return result;
  }
}

/// Unified scan executor that eliminates duplication
class ScanExecutor {
  final ScanOrchestrator _orchestrator;
  final ScanRepository _scanRepo;
  final ProjectDataCache _cache;

  ScanExecutor(this._orchestrator, this._scanRepo, this._cache);

  Future<void> executeScan({
    required ScanStrategy strategy,
    required int projectId,
    required Function(bool isScanning, String status) onStatusChange,
    required Future<String?> Function(String scanType) getScanOption,
  }) async {
    final scanOption = await getScanOption(strategy.scanType);
    if (scanOption == null) return;

    final notificationId = StatusNotificationService().addNotification(
      'Starting ${strategy.scanType} scans...',
    );

    onStatusChange(true, 'Starting ${strategy.scanType} scans...');

    try {
      final result = await strategy.execute(
        _orchestrator,
        projectId,
        scanOption == 'replace',
        (status) {
          StatusNotificationService().updateNotification(notificationId, status);
          onStatusChange(true, status);
        },
      );

      await _cache.reloadDevices(projectId);

      StatusNotificationService().removeNotification(notificationId);

      final statusMessage = _buildStatusMessage(result, strategy.scanType);
      onStatusChange(false, statusMessage);
    } catch (e) {
      StatusNotificationService().removeNotification(notificationId);
      onStatusChange(false, 'Scan failed: $e');
    }
  }

  Future<String?> _getScanOption(String scanType) async {
    final cache = ProjectDataCache();
    final devices = cache.devices;
    
    bool hasExistingScans = false;
    for (final device in devices) {
      final scans = await _scanRepo.getScans(device.id);
      if (scans.any((scan) => scan.scanType == scanType)) {
        hasExistingScans = true;
        break;
      }
    }

    if (!hasExistingScans) return 'replace';

    // Return null to indicate user needs to be prompted
    // This will be handled by the UI layer
    return null;
  }

  String _buildStatusMessage(Map<String, dynamic> result, String scanType) {
    final completed = result['completed'] ?? 0;
    final failed = result['failed'] ?? 0;

    if (failed == 0) {
      return 'Completed $completed $scanType scans successfully';
    } else {
      return '$completed $scanType scans completed, $failed failed';
    }
  }
}
