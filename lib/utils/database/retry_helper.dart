import 'dart:async';
import 'package:sqflite/sqflite.dart';

/// Utility class for handling database operations with retry logic.
/// 
/// Provides configurable retry mechanisms with exponential backoff
/// to handle database lock conflicts and transient errors.
class RetryHelper {
  /// Executes a database operation with retry logic.
  /// 
  /// Parameters:
  /// - [operation]: The async function to execute
  /// - [maxAttempts]: Maximum number of retry attempts (default: 10)
  /// - [initialDelay]: Starting delay between retries (default: 50ms)
  /// - [shouldRetry]: Optional function to determine if error is retryable
  /// 
  /// Returns the result of the operation if successful.
  /// Throws the last error if all retry attempts fail.
  /// 
  /// Example:
  /// ```dart
  /// final result = await RetryHelper.retry(
  ///   operation: () => db.insert('table', data),
  ///   maxAttempts: 5,
  /// );
  /// ```
  static Future<T> retry<T>({
    required Future<T> Function() operation,
    int maxAttempts = 10,
    Duration initialDelay = const Duration(milliseconds: 50),
    bool Function(dynamic error)? shouldRetry,
  }) async {
    assert(maxAttempts > 0, 'maxAttempts must be greater than 0');
    
    int attempt = 0;
    Duration delay = initialDelay;
    dynamic lastError;

    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        lastError = e;
        attempt++;

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(e)) {
          rethrow;
        }

        // Check if this is a retryable database error
        if (!_isRetryableError(e)) {
          rethrow;
        }

        // If we've exhausted attempts, throw the error
        if (attempt >= maxAttempts) {
          rethrow;
        }

        // Wait before retrying with exponential backoff
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }

    // This should never be reached, but just in case
    throw lastError ?? Exception('Retry failed after $maxAttempts attempts');
  }

  /// Determines if an error is retryable.
  /// 
  /// Currently handles:
  /// - DatabaseException with 'database is locked' message
  /// - DatabaseException with SQLITE_BUSY error code
  static bool _isRetryableError(dynamic error) {
    if (error is DatabaseException) {
      final message = error.toString().toLowerCase();
      return message.contains('database is locked') ||
             message.contains('sqlite_busy') ||
             error.isNoSuchTableError() ||
             error.isDatabaseClosedError();
    }
    return false;
  }

  /// Executes a database operation with infinite retry logic.
  /// 
  /// WARNING: Use with caution! This will retry indefinitely.
  /// Only use for critical operations where failure is not an option.
  /// 
  /// Parameters:
  /// - [operation]: The async function to execute
  /// - [initialDelay]: Starting delay between retries (default: 50ms)
  /// - [maxDelay]: Maximum delay between retries (default: 5 seconds)
  /// 
  /// Example:
  /// ```dart
  /// await RetryHelper.retryIndefinitely(
  ///   operation: () => db.insert('critical_table', data),
  /// );
  /// ```
  static Future<T> retryIndefinitely<T>({
    required Future<T> Function() operation,
    Duration initialDelay = const Duration(milliseconds: 50),
    Duration maxDelay = const Duration(seconds: 5),
  }) async {
    Duration delay = initialDelay;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        if (!_isRetryableError(e)) {
          rethrow;
        }

        await Future.delayed(delay);
        
        // Exponential backoff with max cap
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(
            initialDelay.inMilliseconds,
            maxDelay.inMilliseconds,
          ),
        );
      }
    }
  }
}
