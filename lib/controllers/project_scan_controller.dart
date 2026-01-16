import 'package:penpeeper/services/scan_orchestrator.dart';
import 'package:penpeeper/services/scan_executor.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/repositories/scan_repository.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/models.dart';

/// Controller for project scan operations
/// Extracts scan logic from ProjectScreen
class ProjectScanController {
  final ScanOrchestrator _orchestrator;
  final ScanRepository _scanRepo;
  final DeviceRepository _deviceRepo;
  final ProjectDataCache _cache;
  late final ScanExecutor _executor;

  bool _cancelRequested = false;

  ProjectScanController(
    this._orchestrator,
    this._scanRepo,
    this._deviceRepo,
    this._cache,
  ) {
    _executor = ScanExecutor(_orchestrator, _scanRepo, _cache);
  }

  void requestCancel([String? scanType]) {
    _cancelRequested = true;
    if (scanType != null) {
      _orchestrator.requestCancel(scanType);
    } else {
      // Cancel all scan types
      _orchestrator.requestCancel('NMAP');
      _orchestrator.requestCancel('NIKTO');
      _orchestrator.requestCancel('SEARCHSPLOIT');
      _orchestrator.requestCancel('WHATWEB');
      _orchestrator.requestCancel('FFUF');
      _orchestrator.requestCancel('ENUM4LINUX');
      _orchestrator.requestCancel('SNMP');
    }
  }

  void resetCancel([String? scanType]) {
    _cancelRequested = false;
    if (scanType != null) {
      _orchestrator.resetCancel(scanType);
    } else {
      _orchestrator.resetAllCancels();
    }
  }

  Future<void> executeScan({
    required ScanStrategy strategy,
    required int projectId,
    required Function(bool isScanning, String status) onStatusChange,
    required Future<String?> Function(String scanType) getScanOption,
  }) async {
    await _executor.executeScan(
      strategy: strategy,
      projectId: projectId,
      onStatusChange: onStatusChange,
      getScanOption: getScanOption,
    );
  }

  Future<String?> getScanOption(String scanType, List<Device> devices) async {
    bool hasExistingScans = false;
    for (final device in devices) {
      final scans = await _scanRepo.getScans(device.id);
      if (scans.any((scan) => scan.scanType == scanType)) {
        hasExistingScans = true;
        break;
      }
    }

    if (!hasExistingScans) return 'replace';
    return null;
  }

  Future<List<Device>> filterDevicesByScanOption(
    List<Device> devices,
    String scanType,
    String scanOption,
  ) async {
    if (scanOption == 'replace') return devices;

    final scannedDeviceIds = <int>{};
    for (final device in devices) {
      final scans = await _scanRepo.getScans(device.id);
      if (scans.any((scan) => scan.scanType == scanType)) {
        scannedDeviceIds.add(device.id);
      }
    }
    return devices.where((device) => !scannedDeviceIds.contains(device.id)).toList();
  }

  void dispose() {
    _orchestrator.cleanup();
  }
}
