import 'package:flutter/material.dart';
import 'package:penpeeper/models.dart';
import 'package:penpeeper/theme_config.dart';

class MoveDeviceDialog extends StatefulWidget {
  final List<Project> projects;
  final int currentProjectId;

  const MoveDeviceDialog({
    super.key,
    required this.projects,
    required this.currentProjectId,
  });

  @override
  State<MoveDeviceDialog> createState() => _MoveDeviceDialogState();
}

class _MoveDeviceDialogState extends State<MoveDeviceDialog> {
  int? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    // Filter out current project and sort alphabetically
    final availableProjects = widget.projects
        .where((p) => p.id != widget.currentProjectId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Row(
              children: [
                Icon(Icons.drive_file_move, color: AppTheme.primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Which Project would you like to move this device to:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Project dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.inputBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedProjectId,
                  hint: Text(
                    'Select a project...',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  dropdownColor: AppTheme.surfaceColor,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                  icon: Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                  items: availableProjects.map((project) {
                    return DropdownMenuItem<int>(
                      value: project.id,
                      child: Text(project.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProjectId = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Cancel button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 12),

                // Move Device button
                ElevatedButton(
                  onPressed: _selectedProjectId == null
                      ? null
                      : () => Navigator.of(context).pop(_selectedProjectId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                  child: const Text('Move Device', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
