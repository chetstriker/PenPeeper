import 'package:flutter/material.dart';

/// Defines the direction of a gradient.
enum GradientDirection {
  /// Gradient flows from left to right (horizontal)
  leftToRight,
  /// Gradient flows from top to bottom (vertical)
  topToBottom,
  /// Gradient flows diagonally at 45 degrees (top-left to bottom-right)
  diagonal45,
}

/// Configuration for gradient rendering in borders and button backgrounds.
/// 
/// Supports three gradient directions and can be toggled on/off.
/// When disabled, falls back to solid color rendering.
class GradientConfig {
  final List<Color> colors;
  final GradientDirection direction;
  final bool isEnabled;

  GradientConfig({
    required this.colors,
    this.direction = GradientDirection.leftToRight,
    this.isEnabled = true,
  });

  /// Converts this configuration to a Flutter LinearGradient.
  /// 
  /// Returns a LinearGradient with the configured colors and direction.
  LinearGradient toLinearGradient() {
    AlignmentGeometry begin;
    AlignmentGeometry end;

    switch (direction) {
      case GradientDirection.leftToRight:
        begin = Alignment.centerLeft;
        end = Alignment.centerRight;
        break;
      case GradientDirection.topToBottom:
        begin = Alignment.topCenter;
        end = Alignment.bottomCenter;
        break;
      case GradientDirection.diagonal45:
        begin = Alignment.topLeft;
        end = Alignment.bottomRight;
        break;
    }

    return LinearGradient(
      colors: colors,
      begin: begin,
      end: end,
    );
  }

  /// Creates a GradientConfig from a JSON map (theme file format).
  /// 
  /// Expected format:
  /// ```json
  /// {
  ///   "colors": ["0xFFFF0000", "0xFF0000FF"],
  ///   "direction": "leftToRight",
  ///   "isEnabled": true
  /// }
  /// ```
  factory GradientConfig.fromJson(Map<String, dynamic> json) {
    final colorsList = (json['colors'] as List?)
        ?.map((c) => Color(int.parse(c.toString())))
        .toList() ?? [];

    final directionStr = json['direction'] as String? ?? 'leftToRight';
    GradientDirection direction;
    switch (directionStr) {
      case 'topToBottom':
        direction = GradientDirection.topToBottom;
        break;
      case 'diagonal45':
        direction = GradientDirection.diagonal45;
        break;
      default:
        direction = GradientDirection.leftToRight;
    }

    return GradientConfig(
      colors: colorsList,
      direction: direction,
      isEnabled: json['isEnabled'] as bool? ?? false,
    );
  }

  /// Converts this configuration to a JSON map for theme file serialization.
  Map<String, dynamic> toJson() {
    String directionStr;
    switch (direction) {
      case GradientDirection.topToBottom:
        directionStr = 'topToBottom';
        break;
      case GradientDirection.diagonal45:
        directionStr = 'diagonal45';
        break;
      default:
        directionStr = 'leftToRight';
    }

    return {
      'colors': colors.map((c) => '0x${c.value.toRadixString(16).padLeft(8, '0').toUpperCase()}').toList(),
      'direction': directionStr,
      'isEnabled': isEnabled,
    };
  }
}
