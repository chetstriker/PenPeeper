/// Base class for application-specific errors
abstract class AppError implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppError(this.message, {this.originalError, this.stackTrace});

  @override
  String toString() => message;
}

/// Database-related errors
class DatabaseError extends AppError {
  DatabaseError(super.message, {super.originalError, super.stackTrace});
}

/// Network-related errors
class NetworkError extends AppError {
  NetworkError(super.message, {super.originalError, super.stackTrace});
}

/// Validation errors
class ValidationError extends AppError {
  ValidationError(super.message, {super.originalError, super.stackTrace});
}

/// Export-related errors
class ExportError extends AppError {
  ExportError(super.message, {super.originalError, super.stackTrace});
}

/// Scan/process errors
class ScanError extends AppError {
  ScanError(super.message, {super.originalError, super.stackTrace});
}

/// File operation errors
class FileOperationError extends AppError {
  FileOperationError(super.message, {super.originalError, super.stackTrace});
}
