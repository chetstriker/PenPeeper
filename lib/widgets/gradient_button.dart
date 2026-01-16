import 'package:flutter/material.dart';
import '../gradient_config.dart';

/// A button widget with gradient or solid color background support.
/// 
/// Supports loading states, icons, tooltips, and customizable styling.
/// Automatically switches between gradient and solid color based on backgroundConfig.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final dynamic backgroundConfig;
  final VoidCallback? onPressed;
  final Color textColor;
  final EdgeInsets padding;
  final double borderRadius;
  final String? tooltip;
  final bool isLoading;
  final double? iconSize;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    required this.backgroundConfig,
    this.onPressed,
    this.textColor = Colors.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.borderRadius = 8.0,
    this.tooltip,
    this.isLoading = false,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: padding,
        decoration: _buildDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              isLoading
                  ? SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    )
                  : Icon(icon, color: textColor, size: iconSize),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }
    return button;
  }

  BoxDecoration _buildDecoration() {
    final radius = BorderRadius.circular(borderRadius);
    if (backgroundConfig is GradientConfig && (backgroundConfig as GradientConfig).isEnabled) {
      final gradientConfig = backgroundConfig as GradientConfig;
      return BoxDecoration(
        gradient: gradientConfig.toLinearGradient(),
        borderRadius: radius,
      );
    } else {
      final color = backgroundConfig is Color ? backgroundConfig : Colors.blue;
      return BoxDecoration(
        color: color,
        borderRadius: radius,
      );
    }
  }
}
