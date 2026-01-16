import 'package:flutter_test/flutter_test.dart';
import 'package:penpeeper/utils/date_formatter.dart';

void main() {
  group('DateFormatter.formatTimestamp', () {
    test('should format date with correct pattern', () {
      final date = DateTime(2024, 1, 15, 14, 30, 45);
      expect(DateFormatter.formatTimestamp(date), '2024-01-15 14:30:45');
    });

    test('should pad single digit values', () {
      final date = DateTime(2024, 3, 5, 9, 8, 7);
      expect(DateFormatter.formatTimestamp(date), '2024-03-05 09:08:07');
    });
  });

  group('DateFormatter.formatForFilename', () {
    test('should format for filename without special chars', () {
      final date = DateTime(2024, 1, 15, 14, 30, 45);
      expect(DateFormatter.formatForFilename(date), '20240115_143045');
    });

    test('should pad single digit values', () {
      final date = DateTime(2024, 3, 5, 9, 8, 7);
      expect(DateFormatter.formatForFilename(date), '20240305_090807');
    });
  });

  group('DateFormatter.formatDateOnly', () {
    test('should format date only', () {
      final date = DateTime(2024, 1, 15, 14, 30, 45);
      expect(DateFormatter.formatDateOnly(date), '2024-01-15');
    });

    test('should ignore time component', () {
      final date = DateTime(2024, 12, 31, 23, 59, 59);
      expect(DateFormatter.formatDateOnly(date), '2024-12-31');
    });
  });

  group('DateFormatter.formatTimeOnly', () {
    test('should format time only', () {
      final date = DateTime(2024, 1, 15, 14, 30, 45);
      expect(DateFormatter.formatTimeOnly(date), '14:30:45');
    });

    test('should ignore date component', () {
      final date = DateTime(2024, 12, 31, 23, 59, 59);
      expect(DateFormatter.formatTimeOnly(date), '23:59:59');
    });
  });

  group('DateFormatter.formatRelative', () {
    test('should return "Just now" for recent times', () {
      final date = DateTime.now().subtract(Duration(seconds: 30));
      expect(DateFormatter.formatRelative(date), 'Just now');
    });

    test('should format minutes correctly', () {
      final date = DateTime.now().subtract(Duration(minutes: 5));
      expect(DateFormatter.formatRelative(date), '5 minutes ago');
    });

    test('should format single minute correctly', () {
      final date = DateTime.now().subtract(Duration(minutes: 1));
      expect(DateFormatter.formatRelative(date), '1 minute ago');
    });

    test('should format hours correctly', () {
      final date = DateTime.now().subtract(Duration(hours: 3));
      expect(DateFormatter.formatRelative(date), '3 hours ago');
    });

    test('should format single hour correctly', () {
      final date = DateTime.now().subtract(Duration(hours: 1));
      expect(DateFormatter.formatRelative(date), '1 hour ago');
    });

    test('should format days correctly', () {
      final date = DateTime.now().subtract(Duration(days: 4));
      expect(DateFormatter.formatRelative(date), '4 days ago');
    });

    test('should format single day correctly', () {
      final date = DateTime.now().subtract(Duration(days: 1));
      expect(DateFormatter.formatRelative(date), '1 day ago');
    });

    test('should format weeks correctly', () {
      final date = DateTime.now().subtract(Duration(days: 14));
      expect(DateFormatter.formatRelative(date), '2 weeks ago');
    });

    test('should format months correctly', () {
      final date = DateTime.now().subtract(Duration(days: 60));
      expect(DateFormatter.formatRelative(date), '2 months ago');
    });

    test('should format years correctly', () {
      final date = DateTime.now().subtract(Duration(days: 400));
      expect(DateFormatter.formatRelative(date), '1 year ago');
    });
  });
}
