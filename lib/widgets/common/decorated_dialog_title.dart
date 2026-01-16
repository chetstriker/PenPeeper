import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

class DecoratedDialogTitle extends StatelessWidget {
  final String title;

  const DecoratedDialogTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FractionallySizedBox(
          widthFactor: 0.8,
          child: Container(
            height: 7,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.arrowColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        Text(title, textAlign: TextAlign.center),
      ],
    );
  }
}
