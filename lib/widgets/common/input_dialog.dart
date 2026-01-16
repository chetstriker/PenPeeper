import 'package:flutter/material.dart';
import 'package:penpeeper/utils/validation/validation_result.dart';

/// Reusable input dialog with validation
class InputDialog {
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? initialValue,
    String? hint,
    ValidationResult Function(String)? validator,
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(text: initialValue);
    String? errorText;

    return await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              errorText: errorText,
              border: const OutlineInputBorder(),
            ),
            maxLines: maxLines,
            autofocus: true,
            onChanged: (value) {
              if (validator != null) {
                final result = validator(value);
                setState(() {
                  errorText = result.isValid ? null : result.errorMessage;
                });
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (validator != null) {
                  final result = validator(value);
                  if (!result.isValid) {
                    setState(() => errorText = result.errorMessage);
                    return;
                  }
                }
                Navigator.pop(context, value);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}
