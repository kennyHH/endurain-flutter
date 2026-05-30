import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/widgets/activity_type_label.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

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

    return DropdownButtonFormField<ActivityType>(
      initialValue: selectedType,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.activityTypeLabel,
        border: const OutlineInputBorder(),
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
