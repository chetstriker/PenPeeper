import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

class EmptyDevicePrompt extends StatelessWidget {
  const EmptyDevicePrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppTheme.infoOutlineIcon, size: 64, color: AppTheme.primaryColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No Devices Added',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Add Device(s)" to scan for active hosts',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class SelectDevicePrompt extends StatelessWidget {
  const SelectDevicePrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppTheme.devicesIcon, size: 64, color: AppTheme.primaryColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Select a Device',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a device from the list to view details',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
