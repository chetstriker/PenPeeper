import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

/// Consistent loading indicator widget
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: size / 8,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AppTheme.primaryColor,
            ),
          ),
        ),
        if (message != null) ...[
          SizedBox(height: size / 3),
          Text(
            message!,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: AppTheme.fontSizeBody,
            ),
          ),
        ],
      ],
    );
  }
}
