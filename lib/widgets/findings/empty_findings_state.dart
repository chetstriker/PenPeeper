import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

class EmptyFindingsState extends StatelessWidget {
  final String completionFilter;
  final VoidCallback? onShowAll;

  const EmptyFindingsState({
    super.key,
    required this.completionFilter,
    this.onShowAll,
  });

  IconData _getIcon() {
    switch (completionFilter) {
      case 'complete': return AppTheme.completeStatusIcon;
      case 'incomplete': return AppTheme.incompleteStatusIcon;
      default: return Icons.search_off;
    }
  }

  String _getTitle() {
    switch (completionFilter) {
      case 'complete': return 'No Complete Findings';
      case 'incomplete': return 'No Incomplete Findings';
      default: return 'No Findings Found';
    }
  }

  String _getMessage() {
    switch (completionFilter) {
      case 'complete': 
        return 'All your findings are missing required information.\nClick "Edit" on incomplete findings to add Evidence, Recommendations, Severity, and Classifications.';
      case 'incomplete': 
        return 'Great! All your findings have complete information.\nThey are ready to be included in your penetration testing reports.';
      default: 
        return 'No flagged findings yet.\nGo to the main FINDINGS tab to flag devices and create findings for your report.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderPrimary.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIcon(),
                size: 64,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                _getTitle(),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: AppTheme.fontSizeTitle,
                  fontWeight: AppTheme.fontWeightSemiBold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _getMessage(),
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: AppTheme.fontSizeBodyLarge,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (completionFilter != 'all' && onShowAll != null) ...[ 
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onShowAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.textOnPrimary,
                  ),
                  child: const Text('Show All Findings'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SearchPrompt extends StatelessWidget {
  final bool hasDevices;
  
  const SearchPrompt({super.key, required this.hasDevices});

  @override
  Widget build(BuildContext context) {
    if (!hasDevices) {
      return Text(
        'You currently have no devices to search.\nPlease start by clicking "Add Device(s)" on the GATHER tab above.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 22,
          height: 1.3,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(500, 60),
          painter: UpwardArrowsPainter(),
        ),
        const SizedBox(height: 16),
        Text(
          'Use one of the filters above\nto search through your devices',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 22,
            height: 1.3,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class UpwardArrowsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.arrowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final arrowPositions = [
      size.width * 0.15,
      size.width * 0.5,
      size.width * 0.85,
    ];

    for (final x in arrowPositions) {
      final path = Path();
      path.moveTo(x, size.height);
      path.lineTo(x, 0);
      canvas.drawPath(path, paint);

      final arrowPath = Path();
      arrowPath.moveTo(x, 0);
      arrowPath.lineTo(x - 14, 20);
      arrowPath.moveTo(x, 0);
      arrowPath.lineTo(x + 14, 20);
      canvas.drawPath(arrowPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
