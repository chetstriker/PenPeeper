import 'package:flutter/material.dart';
import '../gradient_button.dart';

class ScanActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool isLoading;

  const ScanActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GradientButton(
      label: label,
      icon: icon,
      backgroundConfig: Colors.transparent,
      onPressed: onPressed,
      textColor: color,
      tooltip: tooltip,
      isLoading: isLoading,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      iconSize: 20,
    );
  }
}
