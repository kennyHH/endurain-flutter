import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/widgets/activity_stats_display.dart';
import 'package:endurain/features/activity/widgets/activity_type_picker.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/shared/adaptive/adaptive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ActivityRecordingControls extends StatelessWidget {
  const ActivityRecordingControls({
    super.key,
    required this.state,
    required this.selectedActivityType,
    required this.onActivityTypeChanged,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final ActivityRecordingState state;
  final ActivityType selectedActivityType;
  final ValueChanged<ActivityType>? onActivityTypeChanged;
  final ValueChanged<ActivityType>? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controls = _buildControls(l10n);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                blurRadius: 12,
                color: Color(0x33000000),
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ActivityStatsDisplay(state: state),
                if (state.isActive ||
                    state.status == ActivityRecordingStatus.stopping ||
                    state.status == ActivityRecordingStatus.completed)
                  const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: controls,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildControls(AppLocalizations l10n) {
    switch (state.status) {
      case ActivityRecordingStatus.recording:
        return [
          _controlButton(
            label: l10n.activityPause,
            materialIcon: Icons.pause,
            cupertinoIcon: CupertinoIcons.pause_fill,
            onPressed: onPause,
            variant: AdaptiveButtonVariant.secondary,
          ),
          _controlButton(
            label: l10n.activityStop,
            materialIcon: Icons.stop,
            cupertinoIcon: CupertinoIcons.stop_fill,
            onPressed: onStop,
            destructive: true,
          ),
        ];
      case ActivityRecordingStatus.paused:
        return [
          _controlButton(
            label: l10n.activityResume,
            materialIcon: Icons.play_arrow,
            cupertinoIcon: CupertinoIcons.play_arrow,
            onPressed: onResume,
          ),
          _controlButton(
            label: l10n.activityStop,
            materialIcon: Icons.stop,
            cupertinoIcon: CupertinoIcons.stop_fill,
            onPressed: onStop,
            destructive: true,
          ),
        ];
      case ActivityRecordingStatus.stopping:
        return [
          _controlButton(
            label: l10n.activityStopping,
            materialIcon: Icons.stop,
            cupertinoIcon: CupertinoIcons.stop_fill,
            onPressed: null,
            destructive: true,
          ),
        ];
      case ActivityRecordingStatus.idle:
      case ActivityRecordingStatus.completed:
      case ActivityRecordingStatus.failed:
        return [
          SizedBox(
            width: 180,
            child: ActivityTypePicker(
              selectedType: selectedActivityType,
              onChanged: onActivityTypeChanged,
            ),
          ),
          _controlButton(
            label: l10n.activityStart,
            materialIcon: Icons.play_arrow,
            cupertinoIcon: CupertinoIcons.play_arrow,
            onPressed: onStart == null
                ? null
                : () => onStart!(selectedActivityType),
          ),
        ];
    }
  }

  Widget _controlButton({
    required String label,
    required IconData materialIcon,
    required IconData cupertinoIcon,
    required VoidCallback? onPressed,
    AdaptiveButtonVariant variant = AdaptiveButtonVariant.primary,
    bool destructive = false,
  }) {
    return Tooltip(
      message: label,
      child: AdaptiveButton(
        label: label,
        onPressed: onPressed,
        variant: variant,
        destructive: destructive,
        icon: AdaptiveIcon(
          materialIcon: materialIcon,
          cupertinoIcon: cupertinoIcon,
          size: 20,
        ),
      ),
    );
  }
}