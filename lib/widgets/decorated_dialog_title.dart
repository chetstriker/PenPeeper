import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

class DecoratedDialogTitle extends StatelessWidget {
  final String title;

  const DecoratedDialogTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppTheme.primaryGradient,
            ),
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: AppTheme.fontSizeLargeTitle,
            fontWeight: AppTheme.fontWeightSemiBold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
