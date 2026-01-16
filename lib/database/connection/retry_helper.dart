import 'package:flutter/foundation.dart';

/// Helper class for retrying database operations with exponential backoff
class RetryHelper {
  /// Executes an operation with retry logic for database lock errors
  /// 
  /// [operation] - The database operation to execute
  /// [maxAttempts] - Maximum number of retry attempts (default: 10)
  /// [initialDelayMs] - Initial delay in milliseconds (default: 50)
  /// [maxDelayMs] - Maximum delay in milliseconds (default: 500)
  static Future<T> execute<T>({
    required Future<T> Function() operation,
    int maxAttempts = 10,
    int initialDelayMs = 50,
    int maxDelayMs = 500,
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (e.toString().contains('database is locked') && attempt < maxAttempts - 1) {
          final delayMs = (initialDelayMs * (attempt + 1)).clamp(initialDelayMs, maxDelayMs);
          if (attempt > 0 && attempt % 5 == 0) {
            debugPrint('RetryHelper: Retry attempt $attempt after database lock');
          }
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        rethrow;
      }
    }
    throw Exception('RetryHelper: Max attempts reached');
  }
}
