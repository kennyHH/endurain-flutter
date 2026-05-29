import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/core/utils/platform_utils.dart';

class AdaptiveFloatingActionButton extends StatelessWidget {
  const AdaptiveFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.materialIcon,
    required this.cupertinoIcon,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final IconData materialIcon;
  final IconData cupertinoIcon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isApplePlatform) {
      return CupertinoButton.filled(
        padding: const EdgeInsets.all(
          LocationMarkerConstants.buttonInnerPadding,
        ),
        onPressed: onPressed,
        child: Icon(cupertinoIcon, color: CupertinoColors.white),
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      child: Icon(materialIcon),
    );
  }
}
