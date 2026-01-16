import 'dart:io';
import 'package:sqflite_common/sqlite_api.dart';

class ExportImportErrorHandler {
  static String getUserFriendlyMessage(Exception e) {
    if (e.toString().contains('Incorrect password') || 
        e.toString().contains('decryption') ||
        e.toString().contains('Bad decrypt')) {
      return 'Incorrect password. Please try again.';
    }
    
    if (e.toString().contains('corrupted') || 
        e.toString().contains('Invalid archive') ||
        e.toString().contains('FormatException')) {
      return 'The archive file is corrupted or invalid.';
    }
    
    if (e.toString().contains('Unsupported version')) {
      return 'This archive was created with a newer version of PenPeeper.';
    }
    
    if (e is FileSystemException) {
      if (e.osError?.errorCode == 28) {
        return 'Insufficient disk space to complete the operation.';
      }
      if (e.osError?.errorCode == 13 || e.osError?.errorCode == 5) {
        return 'Permission denied. Please check file permissions.';
      }
      return 'File system error: ${e.message}';
    }
    
    if (e is DatabaseException) {
      if (e.toString().contains('UNIQUE constraint')) {
        return 'A project with this name already exists.';
      }
      if (e.toString().contains('database is locked')) {
        return 'Database is locked. Please try again.';
      }
      return 'Database error occurred. Please try again.';
    }
    
    if (e.toString().contains('SocketException') || 
        e.toString().contains('HttpException')) {
      return 'Network error. Please check your connection.';
    }
    
    return 'An unexpected error occurred: ${e.toString()}';
  }

  static void logError(String operation, Exception e, StackTrace stack) {
    // ignore: avoid_print
    print('[$operation] Error: $e');
    // ignore: avoid_print
    print('Stack trace: $stack');
  }

  static bool isRecoverable(Exception e) {
    if (e.toString().contains('Incorrect password')) return true;
    if (e.toString().contains('database is locked')) return true;
    if (e.toString().contains('SocketException')) return true;
    if (e is FileSystemException && e.osError?.errorCode == 28) return false;
    if (e.toString().contains('corrupted')) return false;
    if (e.toString().contains('Unsupported version')) return false;
    
    return true;
  }
}
