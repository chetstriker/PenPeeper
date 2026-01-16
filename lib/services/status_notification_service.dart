import 'package:flutter/material.dart';

class StatusNotification {
  final String id;
  final String message;
  final bool isLoading;

  StatusNotification({
    required this.id,
    required this.message,
    this.isLoading = true,
  });
}

class StatusNotificationService extends ChangeNotifier {
  static final StatusNotificationService _instance = StatusNotificationService._internal();
  factory StatusNotificationService() => _instance;
  StatusNotificationService._internal();

  final List<StatusNotification> _notifications = [];
  List<StatusNotification> get notifications => List.unmodifiable(_notifications);

  bool _isDisposed = false;

  /// Schedule notification asynchronously to avoid calling during build/setState
  void _scheduleNotify() {
    if (_isDisposed) return;

    // Use Future.microtask instead of SchedulerBinding.addPostFrameCallback
    // This works better in packaged macOS apps
    Future.microtask(() {
      if (!_isDisposed && hasListeners) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('StatusNotificationService: Error notifying listeners: $e');
        }
      }
    });
  }

  String addNotification(String message) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _notifications.add(StatusNotification(id: id, message: message));
    _scheduleNotify();
    return id;
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _scheduleNotify();
  }

  void updateNotification(String id, String message) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = StatusNotification(id: id, message: message);
      _scheduleNotify();
    }
  }

  void clear() {
    _notifications.clear();
    _scheduleNotify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
