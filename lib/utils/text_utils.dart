/// Text processing utilities
class TextUtils {
  /// Truncate text to maximum length with ellipsis
  /// 
  /// Example:
  /// ```dart
  /// final short = TextUtils.truncate('Long text here', 10);
  /// // Returns: "Long te..."
  /// ```
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Escape text for CSV format
  /// 
  /// Example:
  /// ```dart
  /// final escaped = TextUtils.escapeForCSV('Text with "quotes"');
  /// ```
  static String escapeForCSV(String text) {
    if (text.contains('"') || text.contains(',') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  /// Escape text for RTF format
  /// 
  /// Example:
  /// ```dart
  /// final escaped = TextUtils.escapeForRTF('Text with \\ backslash');
  /// ```
  static String escapeForRTF(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('{', '\\{')
        .replaceAll('}', '\\}')
        .replaceAll('\n', '\\line ');
  }

  /// Sanitize text by removing control characters
  /// 
  /// Example:
  /// ```dart
  /// final clean = TextUtils.sanitize(userInput);
  /// ```
  static String sanitize(String text) {
    return text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  /// Remove extra whitespace and trim
  /// 
  /// Example:
  /// ```dart
  /// final clean = TextUtils.normalizeWhitespace('  too   much   space  ');
  /// // Returns: "too much space"
  /// ```
  static String normalizeWhitespace(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Check if string is empty or only whitespace
  /// 
  /// Example:
  /// ```dart
  /// if (TextUtils.isBlank(input)) { ... }
  /// ```
  static bool isBlank(String? text) {
    return text == null || text.trim().isEmpty;
  }

  /// Check if string is not empty and not only whitespace
  /// 
  /// Example:
  /// ```dart
  /// if (TextUtils.isNotBlank(input)) { ... }
  /// ```
  static bool isNotBlank(String? text) {
    return !isBlank(text);
  }
}
