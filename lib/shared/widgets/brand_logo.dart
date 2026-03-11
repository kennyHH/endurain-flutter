import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 120,
    this.lightAssetPath = 'assets/logo/logo.png',
    this.darkAssetPath,
    this.semanticLabel = 'Endurain logo',
  });

  final double size;
  final String lightAssetPath;
  final String? darkAssetPath;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final assetPath = brightness == Brightness.dark && darkAssetPath != null
        ? darkAssetPath!
        : lightAssetPath;

    return Semantics(
      label: semanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
