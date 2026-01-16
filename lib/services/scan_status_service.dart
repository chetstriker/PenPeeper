import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ScanStatusInfo {
  final String id;
  final String scanType;
  final List<String> activeDevices;
  final int completed;
  final int total;

  ScanStatusInfo({
    required this.id,
    required this.scanType,
    required this.activeDevices,
    required this.completed,
    required this.total,
  });

  String get message {
    if (activeDevices.isEmpty) {
      return 'Scanning... ($completed/$total completed)';
    }

    if (activeDevices.length == 1) {
      return 'Scanning ${activeDevices.first} ($completed/$total completed)';
    }

    // Show up to 3 devices, then "and N more"
    final displayDevices = activeDevices.take(3).toList();
    final remaining = activeDevices.length - displayDevices.length;

    final devicesText = displayDevices.join(', ');
    if (remaining > 0) {
      return 'Scanning $devicesText and $remaining more ($completed/$total completed)';
    }

    return 'Scanning $devicesText ($completed/$total completed)';
  }
}

class ScanStatusInfoWithMessage extends ScanStatusInfo {
  final String customMessage;

  ScanStatusInfoWithMessage({
    required super.id,
    required super.scanType,
    required super.activeDevices,
    required super.completed,
    required super.total,
    required this.customMessage,
  });

  @override
  String get message => customMessage;
}

class ScanStatusService extends ChangeNotifier {
  static final ScanStatusService _instance = ScanStatusService._internal();
  factory ScanStatusService() => _instance;
  ScanStatusService._internal();

  final Map<String, ScanStatusInfo> _statuses = {};
  bool _isDisposed = false;

  List<ScanStatusInfo> get statuses => _statuses.values.toList();

  bool get hasActiveScans => _statuses.isNotEmpty;

  /// Schedule notification asynchronously
  /// Uses a simple Future to defer notification and avoid synchronous crashes
  void _scheduleNotify() {
    if (_isDisposed || !hasListeners) return;

    // Use Future.microtask to defer notification
    // This is simpler and more reliable across debug/release builds than SchedulerBinding
    Future.microtask(() {
      if (!_isDisposed && hasListeners) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('ScanStatusService: Error notifying listeners: $e');
        }
      }
    });
  }

  String startScan({
    required String scanType,
    required int totalDevices,
  }) {
    final id = '${scanType}_${DateTime.now().millisecondsSinceEpoch}';
    _statuses[id] = ScanStatusInfo(
      id: id,
      scanType: scanType,
      activeDevices: [],
      completed: 0,
      total: totalDevices,
    );
    _scheduleNotify();
    return id;
  }

  void updateScanProgress({
    required String id,
    required List<String> activeDevices,
    required int completed,
  }) {
    final status = _statuses[id];
    if (status != null) {
      _statuses[id] = ScanStatusInfo(
        id: id,
        scanType: status.scanType,
        activeDevices: activeDevices,
        completed: completed,
        total: status.total,
      );
      _scheduleNotify();
    }
  }

  void updateScanMessage(String scanType, String customMessage) {
    // Find the status entry for this scan type and update with custom message
    for (final entry in _statuses.entries) {
      if (entry.value.scanType.toUpperCase() == scanType.toUpperCase()) {
        _statuses[entry.key] = ScanStatusInfoWithMessage(
          id: entry.value.id,
          scanType: entry.value.scanType,
          activeDevices: entry.value.activeDevices,
          completed: entry.value.completed,
          total: entry.value.total,
          customMessage: customMessage,
        );
        _scheduleNotify();
        break;
      }
    }
  }

  void completeScan(String id) {
    _statuses.remove(id);
    _scheduleNotify();
  }

  void clearAll() {
    _statuses.clear();
    _scheduleNotify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
