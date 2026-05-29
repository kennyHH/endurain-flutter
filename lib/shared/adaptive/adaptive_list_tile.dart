import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:endurain/core/utils/platform_utils.dart';

class AdaptiveListTile extends StatelessWidget {
  const AdaptiveListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final titleStyle = destructive
        ? TextStyle(
            color: PlatformUtils.isApplePlatform
                ? CupertinoColors.systemRed
                : Colors.red,
          )
        : null;

    if (PlatformUtils.isApplePlatform) {
      return CupertinoListTile(
        leading: leading,
        title: Text(title, style: titleStyle),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing:
            trailing ??
            (onTap == null ? null : const CupertinoListTileChevron()),
        onTap: onTap,
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: leading,
      title: Text(title, style: titleStyle),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
