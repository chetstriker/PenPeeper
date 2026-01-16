import 'dart:async';

/// Tracks progress of long-running scan operations in Web mode
class ScanProgressTracker {
  static final ScanProgressTracker _instance = ScanProgressTracker._internal();
  factory ScanProgressTracker() => _instance;
  ScanProgressTracker._internal();

  final Map<String, ScanProgress> _tasks = {};

  /// Start tracking a new scan task
  String startTask({
    required int projectId,
    required String scanType,
    required int totalDevices,
  }) {
    final taskId = '${scanType}_${projectId}_${DateTime.now().millisecondsSinceEpoch}';
    _tasks[taskId] = ScanProgress(
      projectId: projectId,
      scanType: scanType,
      total: totalDevices,
      completed: 0,
      failed: 0,
      currentDevice: null,
      status: 'running',
      startTime: DateTime.now(),
    );
    return taskId;
  }

  /// Update progress for a scan task
  void updateProgress({
    required String taskId,
    int? completed,
    int? failed,
    String? currentDevice,
    String? status,
  }) {
    final task = _tasks[taskId];
    if (task != null) {
      _tasks[taskId] = ScanProgress(
        projectId: task.projectId,
        scanType: task.scanType,
        total: task.total,
        completed: completed ?? task.completed,
        failed: failed ?? task.failed,
        currentDevice: currentDevice ?? task.currentDevice,
        status: status ?? task.status,
        startTime: task.startTime,
      );
    }
  }

  /// Mark a task as complete
  void completeTask(String taskId) {
    final task = _tasks[taskId];
    if (task != null) {
      _tasks[taskId] = ScanProgress(
        projectId: task.projectId,
        scanType: task.scanType,
        total: task.total,
        completed: task.completed,
        failed: task.failed,
        currentDevice: null,
        status: 'completed',
        startTime: task.startTime,
      );

      // Clean up old tasks after 5 minutes
      Timer(const Duration(minutes: 5), () {
        _tasks.remove(taskId);
      });
    }
  }

  /// Get progress for a task
  ScanProgress? getProgress(String taskId) {
    return _tasks[taskId];
  }

  /// Get all active tasks for a project
  List<ScanProgress> getProjectTasks(int projectId) {
    return _tasks.values
        .where((task) => task.projectId == projectId && task.status == 'running')
        .toList();
  }

  /// Clear a task
  void clearTask(String taskId) {
    _tasks.remove(taskId);
  }
}

class ScanProgress {
  final int projectId;
  final String scanType;
  final int total;
  final int completed;
  final int failed;
  final String? currentDevice;
  final String status; // 'running', 'completed', 'failed'
  final DateTime startTime;

  ScanProgress({
    required this.projectId,
    required this.scanType,
    required this.total,
    required this.completed,
    required this.failed,
    required this.currentDevice,
    required this.status,
    required this.startTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'scanType': scanType,
      'total': total,
      'completed': completed,
      'failed': failed,
      'currentDevice': currentDevice,
      'status': status,
      'elapsedSeconds': DateTime.now().difference(startTime).inSeconds,
    };
  }
}
