import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/decorated_dialog_title.dart' as widgets;
import 'package:penpeeper/widgets/gradient_button.dart';

class NonDeviceTitleDialog extends StatefulWidget {
  const NonDeviceTitleDialog({super.key});

  @override
  State<NonDeviceTitleDialog> createState() => _NonDeviceTitleDialogState();
}

class _NonDeviceTitleDialogState extends State<NonDeviceTitleDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
      title: const widgets.DecoratedDialogTitle('Flag a Non-Device Finding'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a brief title for this finding:'),
            const SizedBox(height: 8),
            const Text(
              'Examples: Physical Security, Inventory Processes, Policy Issues',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context, value.trim());
                }
              },
              decoration: const InputDecoration(
                hintText: 'Physical Security',
                labelText: 'Title',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        GradientButton(
          label: 'CONTINUE',
          backgroundConfig: AppTheme.primaryButtonGradient ?? AppTheme.primaryColor,
          onPressed: _controller.text.trim().isNotEmpty
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          textColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ],
    );
  }
}
