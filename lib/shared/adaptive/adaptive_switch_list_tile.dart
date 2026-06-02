import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:endurain/core/utils/platform_utils.dart';

class AdaptiveSwitchListTile extends StatelessWidget {
  const AdaptiveSwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isApplePlatform) {
      return CupertinoListTile(
        leading: leading,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: CupertinoSwitch(value: value, onChanged: onChanged),
      );
    }

    if (leading != null) {
      return ListTile(
        leading: leading,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Switch(value: value, onChanged: onChanged),
        onTap: () => onChanged(!value),
      );
    }

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}
