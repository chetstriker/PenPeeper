import 'package:flutter/material.dart';
import 'package:penpeeper/device_icon_helper.dart';
import 'package:penpeeper/icon_list.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';

class IconSelectorDialog extends StatelessWidget {
  final String currentIconType;

  const IconSelectorDialog({
    super.key,
    required this.currentIconType,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Select Device Icon',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: iconLabels.length,
                itemBuilder: (context, index) {
                  final entry = iconLabels.entries.elementAt(index);
                  final isSelected = entry.key == currentIconType;
                  
                  return Tooltip(
                    message: entry.value,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, entry.key),
                      child: GradientBorderContainer(
                        borderConfig: isSelected ? AppTheme.primaryColor : (AppTheme.borderSecondaryGradient ?? AppTheme.borderSecondary),
                        borderRadius: 8,
                        borderWidth: isSelected ? 2 : 1,
                        backgroundColor: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.2) : AppTheme.cardBackground,
                        child: Center(
                          child: DeviceIconHelper.getIconWidget(
                            entry.key,
                            size: 32,
                            color: isSelected ? AppTheme.primaryColor : AppTheme.iconSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
