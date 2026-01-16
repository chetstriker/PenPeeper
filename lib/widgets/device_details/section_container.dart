import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';

class SectionContainer extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color? headerColor;
  final Widget? trailing;

  const SectionContainer({
    super.key,
    required this.title,
    required this.children,
    this.headerColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GradientBorderContainer(
      borderConfig: AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
      borderRadius: 8,
      borderWidth: 1,
      backgroundColor: AppTheme.surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: headerColor ?? AppTheme.sectionHeaderColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: headerColor == null ? Colors.black : Colors.white,
                      fontWeight: AppTheme.fontWeightSemiBold,
                      fontSize: AppTheme.fontSizeBodyLarge,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
