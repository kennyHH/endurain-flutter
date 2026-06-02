import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/widgets/activity_type_label.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const double _activityTypePickerHeight = 56;

class ActivityTypePicker extends StatelessWidget {
  const ActivityTypePicker({
    super.key,
    required this.selectedType,
    required this.onChanged,
    this.enabled = true,
  });

  final ActivityType selectedType;
  final ValueChanged<ActivityType>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (PlatformUtils.isApplePlatform) {
      return _CupertinoActivityTypePicker(
        selectedType: selectedType,
        onChanged: onChanged,
        enabled: enabled,
        l10n: l10n,
      );
    }

    return DropdownButtonFormField<ActivityType>(
      key: const ValueKey('activityTypePickerMaterialField'),
      initialValue: selectedType,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.activityTypeLabel,
        border: const OutlineInputBorder(),
        constraints: const BoxConstraints.tightFor(
          height: _activityTypePickerHeight,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: ActivityType.values
          .map((type) {
            return DropdownMenuItem<ActivityType>(
              value: type,
              child: Text(type.localizedLabel(l10n)),
            );
          })
          .toList(growable: false),
      onChanged: enabled && onChanged != null
          ? (value) {
              if (value != null) {
                onChanged!(value);
              }
            }
          : null,
    );
  }
}

class _CupertinoActivityTypePicker extends StatelessWidget {
  const _CupertinoActivityTypePicker({
    required this.selectedType,
    required this.onChanged,
    required this.enabled,
    required this.l10n,
  });

  final ActivityType selectedType;
  final ValueChanged<ActivityType>? onChanged;
  final bool enabled;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final borderColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemGrey3,
      context,
    );
    final textColor = CupertinoDynamicColor.resolve(
      enabled ? CupertinoColors.label : CupertinoColors.inactiveGray,
      context,
    );

    return Semantics(
      button: true,
      label: l10n.activityTypeLabel,
      value: selectedType.localizedLabel(l10n),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          onPressed: enabled && onChanged != null
              ? () => _showTypeActions(context)
              : null,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.activityTypeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedType.localizedLabel(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_down, color: textColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTypeActions(BuildContext context) async {
    final selected = await showCupertinoModalPopup<ActivityType>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(l10n.activityTypeLabel),
          actions: ActivityType.values
              .map((type) {
                return CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(context, type),
                  child: Text(type.localizedLabel(l10n)),
                );
              })
              .toList(growable: false),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        );
      },
    );

    if (selected != null) {
      onChanged!(selected);
    }
  }
}
