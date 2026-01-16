import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

class WorkflowStatusDropdown extends StatelessWidget {
  final String completionFilter;
  final ValueChanged<String> onChanged;

  const WorkflowStatusDropdown({
    super.key,
    required this.completionFilter,
    required this.onChanged,
  });

  String _getTooltip() {
    switch (completionFilter) {
      case 'complete': return 'Showing findings with all required fields: Evidence, Recommendation, Severity, Category, Subcategory, and Scope';
      case 'incomplete': return 'Showing findings missing one or more required fields. Click Edit to complete them.';
      default: return 'Filter findings by completion status. Complete findings have all required information for reporting.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _getTooltip(),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.backgroundGradient,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderPrimary),
        ),
        child: DropdownButton<String>(
          value: completionFilter,
          underline: const SizedBox(),
          icon: Icon(Icons.keyboard_arrow_down, color: const Color(0xFF2196F3), size: 20),
          dropdownColor: AppTheme.statusDropdownBackground,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text('All Findings', style: TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'complete',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text('Complete', style: TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'incomplete',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text('Incomplete', style: TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ],
          selectedItemBuilder: (context) => [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text('All Findings', style: TextStyle(color: AppTheme.textPrimary)),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text('Complete', style: TextStyle(color: AppTheme.textPrimary)),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text('Incomplete', style: TextStyle(color: AppTheme.textPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
