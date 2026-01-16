import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

class LargeTextViewer extends StatelessWidget {
  final String text;

  const LargeTextViewer({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    
    return SelectableRegion(
      focusNode: FocusNode(),
      selectionControls: materialTextSelectionControls,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        cacheExtent: 500,
        itemCount: lines.length,
        itemExtent: 17,
        itemBuilder: (context, index) {
          return Text(
            lines[index],
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
            ),
          );
        },
      ),
    );
  }
}
