import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

class DeviceSearchPrompt extends StatelessWidget {
  final bool hasDevices;

  const DeviceSearchPrompt({super.key, required this.hasDevices});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.search,
          size: 64,
          color: AppTheme.textSecondary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        Text(
          hasDevices
              ? 'Use the filters or search above to find devices'
              : 'No devices found in this project',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: AppTheme.fontSizeBodyLarge,
            fontFamily: AppTheme.defaultFontFamily.isEmpty
                ? null
                : AppTheme.defaultFontFamily,
          ),
        ),
      ],
    );
  }
}
