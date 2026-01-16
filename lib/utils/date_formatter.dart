/// Date and time formatting utilities
class DateFormatter {
  /// Format timestamp for display (e.g., "2024-01-15 14:30:45")
  /// 
  /// Example:
  /// ```dart
  /// final formatted = DateFormatter.formatTimestamp(DateTime.now());
  /// ```
  static String formatTimestamp(DateTime date) {
    return '${date.year}-${_pad(date.month)}-${_pad(date.day)} '
           '${_pad(date.hour)}:${_pad(date.minute)}:${_pad(date.second)}';
  }

  /// Format date for filename (e.g., "20240115_143045")
  /// 
  /// Example:
  /// ```dart
  /// final filename = 'report_${DateFormatter.formatForFilename(DateTime.now())}.rtf';
  /// ```
  static String formatForFilename(DateTime date) {
    return '${date.year}${_pad(date.month)}${_pad(date.day)}_'
           '${_pad(date.hour)}${_pad(date.minute)}${_pad(date.second)}';
  }

  /// Format relative time (e.g., "2 hours ago", "3 days ago")
  /// 
  /// Example:
  /// ```dart
  /// final relative = DateFormatter.formatRelative(scanDate);
  /// ```
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  /// Format date only (e.g., "2024-01-15")
  /// 
  /// Example:
  /// ```dart
  /// final dateOnly = DateFormatter.formatDateOnly(DateTime.now());
  /// ```
  static String formatDateOnly(DateTime date) {
    return '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
  }

  /// Format time only (e.g., "14:30:45")
  /// 
  /// Example:
  /// ```dart
  /// final timeOnly = DateFormatter.formatTimeOnly(DateTime.now());
  /// ```
  static String formatTimeOnly(DateTime date) {
    return '${_pad(date.hour)}:${_pad(date.minute)}:${_pad(date.second)}';
  }

  /// Pad number with leading zero if needed
  static String _pad(int number) {
    return number.toString().padLeft(2, '0');
  }
}
