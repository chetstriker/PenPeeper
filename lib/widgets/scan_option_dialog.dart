import 'package:flutter/material.dart';
import 'package:penpeeper/widgets/decorated_dialog_title.dart';

class ScanOptionDialog extends StatelessWidget {
  final String scanType;

  const ScanOptionDialog({super.key, required this.scanType});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
      title: DecoratedDialogTitle('$scanType Scans'),
      content: Text('Choose how to handle existing $scanType scans:', textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'replace'),
          child: Text('Replace existing $scanType Scans'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'skip'),
          child: const Text('Skip devices that have already been scanned'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  static Future<String?> show(BuildContext context, String scanType) {
    return showDialog<String?>(
      context: context,
      builder: (context) => ScanOptionDialog(scanType: scanType),
    );
  }
}
