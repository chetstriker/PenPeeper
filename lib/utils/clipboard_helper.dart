import 'package:flutter/material.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Centralized clipboard operations utility
class ClipboardHelper {
  /// Copy text to clipboard with optional success message
  static Future<void> copy(
    String text, {
    String? successMessage,
    BuildContext? context,
  }) async {
    bool success = false;

    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final item = DataWriterItem();
        item.add(Formats.plainText(text));
        await clipboard.write([item]);
        success = true;
      }
    } catch (e) {
      debugPrint('Clipboard error: $e');
    }

    if (success && context != null && successMessage != null) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(successMessage),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (!success && context != null && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Failed to copy to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Copy text to clipboard without UI feedback
  static Future<void> copyQuiet(String text) async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final item = DataWriterItem();
        item.add(Formats.plainText(text));
        await clipboard.write([item]);
      }
    } catch (e) {
      // Silently fail
    }
  }
}
