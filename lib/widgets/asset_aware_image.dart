import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AssetAwareImage extends StatelessWidget {
  final String assetPath;
  final String fallbackAssetPath;
  final BoxFit fit;

  const AssetAwareImage({
    super.key,
    required this.assetPath,
    required this.fallbackAssetPath,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    // Use Image.asset for PNG files on all platforms
    return Image.asset(
      assetPath,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Image error for $assetPath: $error, using fallback: $fallbackAssetPath');
        return Image.asset(
          fallbackAssetPath,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Fallback image error for $fallbackAssetPath: $error');
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}
