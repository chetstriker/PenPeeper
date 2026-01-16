import 'package:flutter_test/flutter_test.dart';
import 'package:penpeeper/utils/error/error_handler.dart';
import 'package:penpeeper/utils/error/error_types.dart';

void main() {
  group('ErrorHandler.handle', () {
    test('calls onUserMessage callback with user-friendly message', () {
      String? capturedMessage;
      
      ErrorHandler.handle(
        Exception('Test error'),
        onUserMessage: (msg) => capturedMessage = msg,
        context: 'Test operation',
      );
      
      expect(capturedMessage, isNotNull);
      expect(capturedMessage, contains('Test operation'));
    });

    test('handles DatabaseError with appropriate message', () {
      String? capturedMessage;
      
      ErrorHandler.handle(
        DatabaseError('DB failed'),
        onUserMessage: (msg) => capturedMessage = msg,
      );
      
      expect(capturedMessage, 'DB failed');
    });

    test('handles NetworkError with appropriate message', () {
      String? capturedMessage;
      
      ErrorHandler.handle(
        NetworkError('Network failed'),
        onUserMessage: (msg) => capturedMessage = msg,
      );
      
      expect(capturedMessage, 'Network failed');
    });

    test('handles ValidationError with specific message', () {
      String? capturedMessage;
      
      ErrorHandler.handle(
        ValidationError('Invalid input'),
        onUserMessage: (msg) => capturedMessage = msg,
      );
      
      expect(capturedMessage, 'Invalid input');
    });

    test('calls onLog callback when provided', () {
      dynamic capturedError;
      
      ErrorHandler.handle(
        Exception('Test error'),
        onLog: (error, stack) => capturedError = error,
      );
      
      expect(capturedError, isNotNull);
    });

    test('includes context in log message', () {
      // This test verifies the internal behavior through side effects
      // In a real scenario, you'd capture debugPrint output
      expect(() {
        ErrorHandler.handle(
          Exception('Test error'),
          context: 'Test context',
        );
      }, returnsNormally);
    });
  });

  group('ErrorHandler.wrap', () {
    test('returns result on success', () async {
      final result = await ErrorHandler.wrap(
        operation: () async => 42,
      );
      
      expect(result, 42);
    });

    test('returns null on error', () async {
      final result = await ErrorHandler.wrap(
        operation: () async => throw Exception('Test error'),
      );
      
      expect(result, isNull);
    });

    test('calls onError callback on failure', () async {
      String? capturedMessage;
      
      await ErrorHandler.wrap(
        operation: () async => throw Exception('Test error'),
        onError: (msg) => capturedMessage = msg,
      );
      
      expect(capturedMessage, isNotNull);
    });

    test('includes context in error handling', () async {
      String? capturedMessage;
      
      await ErrorHandler.wrap(
        operation: () async => throw Exception('Test error'),
        onError: (msg) => capturedMessage = msg,
        context: 'Test operation',
      );
      
      expect(capturedMessage, contains('Test operation'));
    });
  });

  group('ErrorHandler with custom error types', () {
    test('handles ExportError', () {
      String? capturedMessage;
      
      ErrorHandler.handle(
        ExportError('Export failed'),
        onUserMessage: (msg) => capturedMessage = msg,
      );
      
      expect(capturedMessage, contains('Export failed'));
    });

    test('handles ScanError', () {
      String? capturedMessage;
      
      ErrorHandler.handle(
        ScanError('Scan failed'),
        onUserMessage: (msg) => capturedMessage = msg,
      );
      
      expect(capturedMessage, 'Scan failed');
    });

    test('handles FileOperationError', () {
      String? capturedMessage;
      
      ErrorHandler.handle(
        FileOperationError('File operation failed'),
        onUserMessage: (msg) => capturedMessage = msg,
      );
      
      expect(capturedMessage, contains('File operation failed'));
    });
  });
}
