import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

class StatusBar extends StatelessWidget {
  final String status;
  final bool isScanning;
  final VoidCallback? onCancel;

  const StatusBar({
    super.key,
    required this.status,
    required this.isScanning,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      color: AppTheme.surfaceColor,
      child: Row(
        children: [
          const SizedBox(width: 16),
          if (isScanning)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (isScanning && onCancel != null)
            Tooltip(
              message: 'Cancel scan',
              child: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                onPressed: onCancel,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
