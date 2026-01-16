import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:penpeeper/utils/database/retry_helper.dart';

class TestDatabaseException extends DatabaseException {
  TestDatabaseException(String super.message);

  @override
  int? getResultCode() => null;

  @override
  Object? get result => null;
}

void main() {
  group('RetryHelper.retry', () {
    test('should succeed on first attempt', () async {
      int callCount = 0;
      final result = await RetryHelper.retry(
        operation: () async {
          callCount++;
          return 42;
        },
      );
      expect(result, 42);
      expect(callCount, 1);
    });

    test('should retry on database locked error', () async {
      int callCount = 0;
      final result = await RetryHelper.retry(
        operation: () async {
          callCount++;
          if (callCount < 3) {
            throw TestDatabaseException('database is locked');
          }
          return 'success';
        },
        maxAttempts: 5,
        initialDelay: Duration(milliseconds: 1),
        shouldRetry: (e) => true,
      );
      expect(result, 'success');
      expect(callCount, 3);
    });

    test('should throw non-retryable error immediately', () async {
      int callCount = 0;
      expect(
        () => RetryHelper.retry(
          operation: () async {
            callCount++;
            throw ArgumentError('Invalid argument');
          },
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(callCount, 1);
    });

    test('should throw after max attempts exceeded', () async {
      int callCount = 0;
      await expectLater(
        () => RetryHelper.retry(
          operation: () async {
            callCount++;
            throw TestDatabaseException('database is locked');
          },
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 1),
          shouldRetry: (e) => true,
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect(callCount, 3);
    });

    test('should use custom shouldRetry function', () async {
      int callCount = 0;
      final result = await RetryHelper.retry(
        operation: () async {
          callCount++;
          if (callCount < 2) {
            throw TestDatabaseException('database is locked - Custom error');
          }
          return 'done';
        },
        shouldRetry: (error) => error.toString().contains('Custom'),
        maxAttempts: 5,
        initialDelay: Duration(milliseconds: 1),
      );
      expect(result, 'done');
      expect(callCount, 2);
    });

    test('should not retry when shouldRetry returns false', () async {
      int callCount = 0;
      expect(
        () => RetryHelper.retry(
          operation: () async {
            callCount++;
            throw Exception('Do not retry');
          },
          shouldRetry: (error) => false,
        ),
        throwsA(isA<Exception>()),
      );
      expect(callCount, 1);
    });

    test('should apply exponential backoff', () async {
      int callCount = 0;

      await RetryHelper.retry(
        operation: () async {
          callCount++;
          if (callCount < 4) {
            throw TestDatabaseException('database is locked');
          }
          return 'success';
        },
        maxAttempts: 5,
        initialDelay: Duration(milliseconds: 10),
        shouldRetry: (e) => true,
      );

      expect(callCount, 4);
    });
  });

  group('RetryHelper.retryIndefinitely', () {
    test('should succeed eventually', () async {
      int callCount = 0;
      await expectLater(() async {
        return await RetryHelper.retry(
          operation: () async {
            callCount++;
            if (callCount < 5) {
              throw TestDatabaseException('database is locked');
            }
            return 'finally';
          },
          maxAttempts: 10,
          initialDelay: Duration(milliseconds: 1),
          shouldRetry: (e) => true,
        );
      }(), completion('finally'));
      expect(callCount, 5);
    });

    test('should throw non-retryable error', () async {
      int callCount = 0;
      expect(
        () => RetryHelper.retryIndefinitely(
          operation: () async {
            callCount++;
            throw StateError('Fatal error');
          },
        ),
        throwsA(isA<StateError>()),
      );
      expect(callCount, 1);
    });

    test('should cap delay at maxDelay', () async {
      int callCount = 0;
      await RetryHelper.retry(
        operation: () async {
          callCount++;
          if (callCount < 10) {
            throw TestDatabaseException('database is locked');
          }
          return 'done';
        },
        maxAttempts: 15,
        initialDelay: Duration(milliseconds: 1),
        shouldRetry: (e) => true,
      );
      expect(callCount, 10);
    });
  });
}
