import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:endurain/core/constants/ui_constants.dart';
import 'package:endurain/core/utils/platform_utils.dart';

enum AdaptiveButtonVariant { primary, secondary }

class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AdaptiveButtonVariant.primary,
    this.expand = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final AdaptiveButtonVariant variant;
  final bool expand;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final child = _ButtonContent(label: label, icon: icon, expand: expand);

    if (PlatformUtils.isApplePlatform) {
      final button = variant == AdaptiveButtonVariant.primary
          ? CupertinoButton.filled(onPressed: onPressed, child: child)
          : CupertinoButton(onPressed: onPressed, child: child);

      return expand ? SizedBox(width: double.infinity, child: button) : button;
    }

    final button = variant == AdaptiveButtonVariant.primary
        ? FilledButton(
            onPressed: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(UIConstants.paddingMedium),
              child: child,
            ),
          )
        : TextButton(onPressed: onPressed, child: child);

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.expand,
  });

  final String label;
  final Widget? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return Text(label, textAlign: TextAlign.center);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        icon!,
        const SizedBox(width: UIConstants.paddingMedium),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
  }
}
