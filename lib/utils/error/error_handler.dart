import 'package:flutter/foundation.dart';
import 'error_types.dart';

/// Centralized error handling utility
class ErrorHandler {
  /// Handle an error with optional user message and logging callbacks
  /// 
  /// Parameters:
  /// - [error]: The error to handle
  /// - [onUserMessage]: Callback to display user-friendly message
  /// - [onLog]: Callback for logging the error
  /// - [context]: Optional context string for debugging
  /// 
  /// Example:
  /// ```dart
  /// try {
  ///   await someOperation();
  /// } catch (e, stack) {
  ///   ErrorHandler.handle(
  ///     e,
  ///     stackTrace: stack,
  ///     onUserMessage: (msg) => showSnackBar(msg),
  ///     context: 'Loading devices',
  ///   );
  /// }
  /// ```
  static void handle(
    dynamic error, {
    StackTrace? stackTrace,
    void Function(String)? onUserMessage,
    void Function(dynamic, StackTrace?)? onLog,
    String? context,
  }) {
    final userMessage = _getUserMessage(error, context);
    final logMessage = _getLogMessage(error, stackTrace, context);

    // Call user message callback if provided
    if (onUserMessage != null) {
      onUserMessage(userMessage);
    }

    // Call log callback if provided, otherwise use debug print
    if (onLog != null) {
      onLog(error, stackTrace);
    } else {
      debugPrint(logMessage);
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Get user-friendly error message
  static String _getUserMessage(dynamic error, String? context) {
    final prefix = context != null ? '$context: ' : '';

    if (error is AppError) {
      return '$prefix${error.message}';
    }

    if (error is DatabaseError) {
      return '${prefix}Database operation failed. Please try again.';
    }

    if (error is NetworkError) {
      return '${prefix}Network error. Please check your connection.';
    }

    if (error is ValidationError) {
      return '$prefix${error.message}';
    }

    if (error is ExportError) {
      return '${prefix}Export failed. Please try again.';
    }

    if (error is ScanError) {
      return '${prefix}Scan operation failed. Please try again.';
    }

    if (error is FileOperationError) {
      return '${prefix}File operation failed. Please try again.';
    }

    // Generic error message
    return '${prefix}An error occurred. Please try again.';
  }

  /// Get detailed log message
  static String _getLogMessage(dynamic error, StackTrace? stackTrace, String? context) {
    final buffer = StringBuffer();
    
    if (context != null) {
      buffer.write('[$context] ');
    }

    if (error is AppError) {
      buffer.write('${error.runtimeType}: ${error.message}');
      if (error.originalError != null) {
        buffer.write(' (Original: ${error.originalError})');
      }
    } else {
      buffer.write('Error: $error');
    }

    return buffer.toString();
  }

  /// Wrap an operation with error handling
  /// 
  /// Example:
  /// ```dart
  /// await ErrorHandler.wrap(
  ///   operation: () => database.insert(...),
  ///   onError: (msg) => showSnackBar(msg),
  ///   context: 'Saving device',
  /// );
  /// ```
  static Future<T?> wrap<T>({
    required Future<T> Function() operation,
    void Function(String)? onError,
    String? context,
  }) async {
    try {
      return await operation();
    } catch (e, stack) {
      handle(
        e,
        stackTrace: stack,
        onUserMessage: onError,
        context: context,
      );
      return null;
    }
  }
}
