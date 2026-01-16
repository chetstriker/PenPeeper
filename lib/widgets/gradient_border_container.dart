import 'package:flutter/material.dart';
import '../gradient_config.dart';

/// A container widget that renders borders with gradient or solid color support.
/// 
/// Automatically switches between gradient and solid color rendering based on
/// the borderConfig type and GradientConfig.isEnabled flag.
/// 
/// Uses CustomPainter for efficient gradient border rendering with caching.
class GradientBorderContainer extends StatelessWidget {
  final Widget child;
  final dynamic borderConfig;
  final double borderRadius;
  final double borderWidth;
  final Color? backgroundColor;

  const GradientBorderContainer({
    super.key,
    required this.child,
    required this.borderConfig,
    this.borderRadius = 8.0,
    this.borderWidth = 1.0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (borderConfig is GradientConfig && (borderConfig as GradientConfig).isEnabled) {
      final gradientConfig = borderConfig as GradientConfig;
      return RepaintBoundary(
        child: CustomPaint(
          painter: _GradientBorderPainter(
            gradient: gradientConfig.toLinearGradient(),
            borderRadius: borderRadius,
            borderWidth: borderWidth,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: child,
          ),
        ),
      );
    } else {
      final color = borderConfig is Color ? borderConfig : Colors.grey;
      return Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: color, width: borderWidth),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      );
    }
  }
}

/// Custom painter for rendering gradient borders efficiently.
/// 
/// Caches Paint objects to avoid recreation on every frame.
class _GradientBorderPainter extends CustomPainter {
  final LinearGradient gradient;
  final double borderRadius;
  final double borderWidth;
  Paint? _cachedPaint;
  Rect? _cachedRect;

  _GradientBorderPainter({
    required this.gradient,
    required this.borderRadius,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    if (_cachedPaint == null || _cachedRect != rect) {
      _cachedRect = rect;
      _cachedPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
    }

    canvas.drawRRect(rrect, _cachedPaint!);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter oldDelegate) {
    return oldDelegate.gradient != gradient ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth;
  }
}
