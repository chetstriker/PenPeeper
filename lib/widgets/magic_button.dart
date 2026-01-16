import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/asset_aware_image.dart';

class MagicButton extends StatefulWidget {
  final VoidCallback onPressed;

  const MagicButton({super.key, required this.onPressed});

  @override
  State<MagicButton> createState() => _MagicButtonState();
}

class _MagicButtonState extends State<MagicButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Magic Button (All Scans)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onPressed,
          child: SizedBox(
            width: 180,
            height: 110,
            child: Stack(
              children: [
                // Background Layer (Stationary)
                Positioned.fill(child: _buildThemeImage('Back', BoxFit.fill)),
                // Button Layer (Moves Up/Down)
                Positioned(
                  right: 40,
                  top: 10,
                  bottom: 10,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 100),
                    child: _isPressed
                        ? SizedBox(
                            key: const ValueKey('down'),
                            width: 85,
                            height: 85,
                            child: _buildThemeImage('Down', BoxFit.contain),
                          )
                        : SizedBox(
                            key: const ValueKey('up'),
                            width: 85,
                            height: 85,
                            child: _buildThemeImage('Up', BoxFit.contain),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeImage(String type, BoxFit fit) {
    final themeName = AppTheme.currentThemeName;
    final pngPath = 'Themes/btn$type$themeName.png';
    final fallbackPath = 'assets/images/magic_button/btn_${type.toLowerCase()}.png';

    return AssetAwareImage(
      assetPath: pngPath,
      fallbackAssetPath: fallbackPath,
      fit: fit,
    );
  }
}
