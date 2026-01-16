import 'package:flutter/material.dart';
import 'package:penpeeper/models.dart';
import 'package:penpeeper/theme_config.dart';

class ScanListItem extends StatelessWidget {
  final Scan scan;
  final VoidCallback onTap;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onFlag;

  const ScanListItem({
    super.key,
    required this.scan,
    required this.onTap,
    required this.onExport,
    required this.onDelete,
    required this.onFlag,
  });

  @override
  Widget build(BuildContext context) {
    final sizeKB = (scan.result.length / 1024).toStringAsFixed(0);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(scan.scanType)),
            Text(
              '$sizeKB KB',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Created: ${scan.timestamp.toString().split('.')[0]}',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(AppTheme.flagIcon, color: Colors.red, size: 20),
              onPressed: onFlag,
              tooltip: 'Flag as finding',
            ),
            IconButton(
              icon: Icon(AppTheme.fileDownloadIcon, color: AppTheme.primaryColor, size: 20),
              onPressed: onExport,
              tooltip: 'Export to file',
            ),
            IconButton(
              icon: Icon(AppTheme.deleteIcon, color: AppTheme.iconSecondary),
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

