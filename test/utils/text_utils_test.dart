import 'package:flutter_test/flutter_test.dart';
import 'package:penpeeper/utils/text_utils.dart';

void main() {
  group('TextUtils.truncate', () {
    test('should not truncate short text', () {
      expect(TextUtils.truncate('short', 10), 'short');
    });

    test('should truncate long text with ellipsis', () {
      expect(TextUtils.truncate('This is a long text', 10), 'This is a ...');
    });

    test('should handle exact length', () {
      expect(TextUtils.truncate('exactly10!', 10), 'exactly10!');
    });

    test('should handle empty string', () {
      expect(TextUtils.truncate('', 5), '');
    });
  });

  group('TextUtils.escapeForCSV', () {
    test('should not escape simple text', () {
      expect(TextUtils.escapeForCSV('simple'), 'simple');
    });

    test('should escape text with quotes', () {
      expect(TextUtils.escapeForCSV('has "quotes"'), '"has ""quotes"""');
    });

    test('should escape text with commas', () {
      expect(TextUtils.escapeForCSV('has,comma'), '"has,comma"');
    });

    test('should escape text with newlines', () {
      expect(TextUtils.escapeForCSV('has\nnewline'), '"has\nnewline"');
    });

    test('should handle multiple special chars', () {
      expect(TextUtils.escapeForCSV('text,"with",\nall'), '"text,""with"",\nall"');
    });
  });

  group('TextUtils.escapeForRTF', () {
    test('should escape backslashes', () {
      expect(TextUtils.escapeForRTF('path\\to\\file'), 'path\\\\to\\\\file');
    });

    test('should escape curly braces', () {
      expect(TextUtils.escapeForRTF('text {with} braces'), 'text \\{with\\} braces');
    });

    test('should escape newlines', () {
      expect(TextUtils.escapeForRTF('line1\nline2'), 'line1\\line line2');
    });

    test('should handle multiple escapes', () {
      expect(TextUtils.escapeForRTF('\\{test}\n'), '\\\\\\{test\\}\\line ');
    });
  });

  group('TextUtils.sanitize', () {
    test('should remove control characters', () {
      expect(TextUtils.sanitize('text\x00with\x1Fcontrol'), 'textwithcontrol');
    });

    test('should keep normal text', () {
      expect(TextUtils.sanitize('normal text 123'), 'normal text 123');
    });

    test('should remove DEL character', () {
      expect(TextUtils.sanitize('text\x7Fhere'), 'texthere');
    });
  });

  group('TextUtils.normalizeWhitespace', () {
    test('should trim leading and trailing spaces', () {
      expect(TextUtils.normalizeWhitespace('  text  '), 'text');
    });

    test('should collapse multiple spaces', () {
      expect(TextUtils.normalizeWhitespace('too   much   space'), 'too much space');
    });

    test('should handle tabs and newlines', () {
      expect(TextUtils.normalizeWhitespace('text\t\twith\n\ntabs'), 'text with tabs');
    });

    test('should handle empty string', () {
      expect(TextUtils.normalizeWhitespace(''), '');
    });

    test('should handle whitespace only', () {
      expect(TextUtils.normalizeWhitespace('   \t\n  '), '');
    });
  });

  group('TextUtils.isBlank', () {
    test('should return true for null', () {
      expect(TextUtils.isBlank(null), true);
    });

    test('should return true for empty string', () {
      expect(TextUtils.isBlank(''), true);
    });

    test('should return true for whitespace only', () {
      expect(TextUtils.isBlank('   '), true);
      expect(TextUtils.isBlank('\t\n'), true);
    });

    test('should return false for text', () {
      expect(TextUtils.isBlank('text'), false);
      expect(TextUtils.isBlank('  text  '), false);
    });
  });

  group('TextUtils.isNotBlank', () {
    test('should return false for null', () {
      expect(TextUtils.isNotBlank(null), false);
    });

    test('should return false for empty string', () {
      expect(TextUtils.isNotBlank(''), false);
    });

    test('should return false for whitespace only', () {
      expect(TextUtils.isNotBlank('   '), false);
    });

    test('should return true for text', () {
      expect(TextUtils.isNotBlank('text'), true);
      expect(TextUtils.isNotBlank('  text  '), true);
    });
  });
}
