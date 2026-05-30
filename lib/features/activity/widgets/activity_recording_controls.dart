import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_upload_state.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/services/activity_recording_service.dart';
import 'package:endurain/features/activity/widgets/activity_stats_display.dart';
import 'package:endurain/features/activity/widgets/activity_type_picker.dart';
import 'package:endurain/features/activity/widgets/activity_upload_status_panel.dart';
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
    this.uploadStatus = ActivityUploadStatus.idle,
    this.uploadError,
    this.onRetryUpload,
    this.onDiscard,
    this.onOpenLocationSettings,
  });

  final ActivityRecordingState state;
  final ActivityType selectedActivityType;
  final ValueChanged<ActivityType>? onActivityTypeChanged;
  final ValueChanged<ActivityType>? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;
  final ActivityUploadStatus uploadStatus;
  final Object? uploadError;
  final VoidCallback? onRetryUpload;
  final VoidCallback? onDiscard;
  final VoidCallback? onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controls = _buildControls(l10n);
    final errorMessage = _recordingErrorMessage(l10n);

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
                if (errorMessage != null) ...[
                  Text(
                    errorMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (state.lastErrorKey ==
                      ActivityRecordingErrorKeys
                          .locationPermissionDeniedForever) ...[
                    const SizedBox(height: 8),
                    AdaptiveButton(
                      label: l10n.activityOpenSettings,
                      onPressed: onOpenLocationSettings,
                      variant: AdaptiveButtonVariant.secondary,
                      icon: const AdaptiveIcon(
                        materialIcon: Icons.settings,
                        cupertinoIcon: CupertinoIcons.settings,
                        size: 20,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
                ActivityStatsDisplay(state: state),
                if (state.isActive ||
                    state.status == ActivityRecordingStatus.stopping ||
                    state.status == ActivityRecordingStatus.completed)
                  const SizedBox(height: 8),
                if (state.status == ActivityRecordingStatus.completed) ...[
                  ActivityUploadStatusPanel(
                    status: uploadStatus,
                    error: uploadError,
                    onRetry: onRetryUpload,
                    onDiscard: onDiscard,
                  ),
                  const SizedBox(height: 8),
                ],
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
      case ActivityRecordingStatus.completed:
        return [];
    }
  }

  String? _recordingErrorMessage(AppLocalizations l10n) {
    if (state.status != ActivityRecordingStatus.failed) {
      return null;
    }

    return switch (state.lastErrorKey) {
      ActivityRecordingErrorKeys.emptyRecording => l10n.activityRecordingEmpty,
      ActivityRecordingErrorKeys.locationPermissionDenied =>
        l10n.activityLocationPermissionDenied,
      ActivityRecordingErrorKeys.locationPermissionDeniedForever =>
        l10n.activityLocationPermissionDeniedForever,
      ActivityRecordingErrorKeys.locationServiceDisabled =>
        l10n.activityLocationServiceDisabled,
      ActivityRecordingErrorKeys.locationStreamFailed =>
        l10n.activityLocationStreamFailed,
      _ => l10n.activityRecordingFailed,
    };
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