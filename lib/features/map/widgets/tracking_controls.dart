import 'package:endurain/core/constants/tracking_ui_tokens.dart';
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:endurain/core/utils/metric_formatter.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TrackingControls extends StatefulWidget {
  const TrackingControls({
    super.key,
    required this.snapshot,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    this.suggestedActivityType,
    this.hasGpsFix = false,
    this.isPreparingStart = false,
    this.startCountdownSeconds = 0,
  });

  final TrackingSessionSnapshot snapshot;
  final ValueChanged<ActivityType> onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final ActivityType? suggestedActivityType;
  final bool hasGpsFix;
  final bool isPreparingStart;
  final int startCountdownSeconds;

  @override
  State<TrackingControls> createState() => _TrackingControlsState();
}

class _TrackingControlsState extends State<TrackingControls> {
  ActivityType _selectedType = ActivityType.run;

  @override
  void initState() {
    super.initState();
    final suggested = widget.suggestedActivityType;
    if (suggested != null) {
      _selectedType = suggested;
    }
  }

  @override
  void didUpdateWidget(covariant TrackingControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    final suggested = widget.suggestedActivityType;
    final isEditingType =
        widget.snapshot.state == TrackingSessionState.idle ||
        widget.snapshot.state == TrackingSessionState.stopped;
    if (isEditingType &&
        suggested != null &&
        suggested != oldWidget.suggestedActivityType) {
      _selectedType = suggested;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isRecording = widget.snapshot.state == TrackingSessionState.recording;
    final isPaused = widget.snapshot.state == TrackingSessionState.paused;
    final canPauseOrResume = isRecording || isPaused;
    final status = _statusText(l10n, widget.snapshot.state);
    final effectiveType = widget.snapshot.activityType ?? _selectedType;
    final durationLabel = MetricFormatter.formatDurationClock(
      widget.snapshot.duration,
    );
    final distanceLabel = MetricFormatter.formatDistanceKm(
      widget.snapshot.distanceMeters,
      l10n.trackingDistanceUnitKm,
    );
    final movementValue = MetricFormatter.formatMovement(
      activityType: effectiveType,
      distanceMeters: widget.snapshot.distanceMeters,
      durationSeconds: widget.snapshot.duration.inSeconds,
      paceUnit: l10n.trackingPaceUnitMinKm,
      speedUnit: l10n.trackingSpeedUnitKmh,
    );
    final movementLabel = _movementLabel(effectiveType, l10n);
    final isLiveTracking = isRecording || isPaused;
    final elevationLabel =
        '${widget.snapshot.elevationGainMeters.toStringAsFixed(0)} ${l10n.trackingElevationUnitM}';
    final tone = _statusTone(widget.snapshot.state);
    final hasGpsFix = widget.hasGpsFix;
    final isPreparingStart = widget.isPreparingStart;
    final actionColor = (isRecording || isPaused)
        ? TrackingSemanticColors.error
        : TrackingSemanticColors.success;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final metricValueStyle =
            (PlatformUtils.isApplePlatform
                    ? TrackingTypography.title.copyWith(
                        color: CupertinoColors.label.resolveFrom(context),
                      )
                    : (theme.textTheme.headlineSmall ??
                          TrackingTypography.title))
                .copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: isLiveTracking
                      ? (isCompact ? 21 : 26)
                      : (isCompact ? 18 : 22),
                );
        final metricMetaStyle = PlatformUtils.isApplePlatform
            ? TrackingTypography.meta.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: isCompact ? 11 : 12,
              )
            : (theme.textTheme.labelSmall ?? TrackingTypography.meta).copyWith(
                fontSize: isCompact ? 11 : 12,
              );

        final actionButtons = _buildActionButtons(
          context: context,
          isCompact: isCompact,
          isRecording: isRecording,
          isPaused: isPaused,
          canPauseOrResume: canPauseOrResume,
          actionColor: actionColor,
          l10n: l10n,
        );

        if (PlatformUtils.isApplePlatform) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondarySystemBackground,
                context,
              ),
              borderRadius: BorderRadius.circular(TrackingRadius.lg),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(
                isCompact ? TrackingSpacing.md : TrackingSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusPillCupertino(
                    key: const Key('tracking-status-label'),
                    color: cupertinoStatusColor(tone),
                    label: status,
                  ),
                  const SizedBox(height: TrackingSpacing.sm),
                  _GpsFixIndicator(
                    hasGpsFix: hasGpsFix,
                    isPreparingStart: isPreparingStart,
                    countdownSeconds: widget.startCountdownSeconds,
                  ),
                  const SizedBox(height: TrackingSpacing.md),
                  _MetricRow(
                    leftLabel: l10n.trackingDuration,
                    leftValue: durationLabel,
                    rightLabel: l10n.trackingDistance,
                    rightValue: distanceLabel,
                    textStyle: metricValueStyle,
                    metaStyle: metricMetaStyle,
                  ),
                  const SizedBox(height: TrackingSpacing.md),
                  _MetricRow(
                    leftLabel: movementLabel,
                    leftValue: movementValue,
                    rightLabel: l10n.trackingElevationGain,
                    rightValue: elevationLabel,
                    textStyle: metricValueStyle,
                    metaStyle: metricMetaStyle,
                  ),
                  const SizedBox(height: TrackingSpacing.md),
                  Text(l10n.activityTypeLabel, style: metricMetaStyle),
                  const SizedBox(height: TrackingSpacing.sm),
                  CupertinoSlidingSegmentedControl<ActivityType>(
                    key: const Key('tracking-activity-type'),
                    groupValue: _selectedType,
                    children: {
                      ActivityType.run: _segmentLabelWithIcon(
                        l10n.activityTypeRun,
                        _activityIcon(ActivityType.run),
                      ),
                      ActivityType.ride: _segmentLabelWithIcon(
                        l10n.activityTypeRide,
                        _activityIcon(ActivityType.ride),
                      ),
                      ActivityType.walk: _segmentLabelWithIcon(
                        l10n.activityTypeWalk,
                        _activityIcon(ActivityType.walk),
                      ),
                    },
                    onValueChanged: (value) {
                      if (isRecording || value == null) return;
                      setState(() {
                        _selectedType = value;
                      });
                    },
                  ),
                  const SizedBox(height: TrackingSpacing.lg),
                  actionButtons,
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TrackingRadius.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.all(
              isCompact ? TrackingSpacing.md : TrackingSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusPillMaterial(
                  key: const Key('tracking-status-label'),
                  color: _statusColor(tone),
                  label: status,
                ),
                const SizedBox(height: TrackingSpacing.sm),
                _GpsFixIndicator(
                  hasGpsFix: hasGpsFix,
                  isPreparingStart: isPreparingStart,
                  countdownSeconds: widget.startCountdownSeconds,
                ),
                const SizedBox(height: TrackingSpacing.md),
                _MetricRow(
                  leftLabel: l10n.trackingDuration,
                  leftValue: durationLabel,
                  rightLabel: l10n.trackingDistance,
                  rightValue: distanceLabel,
                  textStyle: metricValueStyle,
                  metaStyle: metricMetaStyle,
                ),
                const SizedBox(height: TrackingSpacing.md),
                _MetricRow(
                  leftLabel: movementLabel,
                  leftValue: movementValue,
                  rightLabel: l10n.trackingElevationGain,
                  rightValue: elevationLabel,
                  textStyle: metricValueStyle,
                  metaStyle: metricMetaStyle,
                ),
                const SizedBox(height: TrackingSpacing.md),
                Text(l10n.activityTypeLabel, style: metricMetaStyle),
                const SizedBox(height: TrackingSpacing.sm),
                Wrap(
                  key: const Key('tracking-activity-type'),
                  spacing: TrackingSpacing.sm,
                  runSpacing: TrackingSpacing.sm,
                  children: [
                    _buildTypeChip(
                      label: l10n.activityTypeRun,
                      value: ActivityType.run,
                      isEnabled: !isRecording,
                    ),
                    _buildTypeChip(
                      label: l10n.activityTypeRide,
                      value: ActivityType.ride,
                      isEnabled: !isRecording,
                    ),
                    _buildTypeChip(
                      label: l10n.activityTypeWalk,
                      value: ActivityType.walk,
                      isEnabled: !isRecording,
                    ),
                  ],
                ),
                const SizedBox(height: TrackingSpacing.lg),
                actionButtons,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons({
    required BuildContext context,
    required bool isCompact,
    required bool isRecording,
    required bool isPaused,
    required bool canPauseOrResume,
    required Color actionColor,
    required AppLocalizations l10n,
  }) {
    final pauseLabel = isRecording
        ? l10n.trackingPaused
        : l10n.trackingRecording;
    final stopLabel = isRecording || isPaused
        ? l10n.trackingStop
        : l10n.trackingStart;
    final canQuickRepeat = widget.suggestedActivityType != null && !canPauseOrResume;
    final pausePressed = isRecording ? widget.onPause : widget.onResume;
    final stopPressed = () {
      if (widget.isPreparingStart) return;
      if (isRecording || isPaused) {
        widget.onStop();
      } else {
        widget.onStart(_selectedType);
      }
    };

    if (isCompact && canPauseOrResume) {
      if (PlatformUtils.isApplePlatform) {
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                key: const Key('tracking-pause-resume-button'),
                color: CupertinoColors.systemGrey,
                borderRadius: BorderRadius.circular(TrackingRadius.md),
                padding: const EdgeInsets.symmetric(
                  vertical: TrackingSpacing.md,
                ),
                onPressed: pausePressed,
                child: Text(
                  pauseLabel,
                  style: TrackingTypography.title.copyWith(
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: TrackingSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                key: const Key('tracking-start-stop-button'),
                color: actionColor,
                borderRadius: BorderRadius.circular(TrackingRadius.md),
                padding: const EdgeInsets.symmetric(
                  vertical: TrackingSpacing.md,
                ),
                onPressed: widget.isPreparingStart ? null : stopPressed,
                child: Text(
                  stopLabel,
                  style: TrackingTypography.title.copyWith(
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      }
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              key: const Key('tracking-pause-resume-button'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: TrackingTypography.title,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TrackingRadius.md),
                ),
              ),
              onPressed: pausePressed,
              child: Text(pauseLabel),
            ),
          ),
          const SizedBox(height: TrackingSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('tracking-start-stop-button'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
                textStyle: TrackingTypography.title,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TrackingRadius.md),
                ),
              ),
              onPressed: widget.isPreparingStart ? null : stopPressed,
              child: Text(stopLabel),
            ),
          ),
        ],
      );
    }

    if (PlatformUtils.isApplePlatform) {
      return Column(
        children: [
          if (canQuickRepeat) ...[
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                key: const Key('tracking-repeat-last-button'),
                color: CupertinoColors.systemGrey2,
                borderRadius: BorderRadius.circular(TrackingRadius.md),
                padding: const EdgeInsets.symmetric(vertical: TrackingSpacing.md),
                onPressed: () => widget.onStart(widget.suggestedActivityType!),
                child: Text(
                  l10n.trackingRepeatLast(
                    _activityLabel(l10n, widget.suggestedActivityType!),
                  ),
                  style: TrackingTypography.body.copyWith(
                    color: CupertinoColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: TrackingSpacing.sm),
          ],
          Row(
            children: [
              if (canPauseOrResume) ...[
                Expanded(
                  child: CupertinoButton(
                    key: const Key('tracking-pause-resume-button'),
                    color: CupertinoColors.systemGrey,
                    borderRadius: BorderRadius.circular(TrackingRadius.md),
                    padding: const EdgeInsets.symmetric(
                      vertical: TrackingSpacing.md,
                    ),
                    onPressed: pausePressed,
                    child: Text(
                      pauseLabel,
                      style: TrackingTypography.title.copyWith(
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: TrackingSpacing.md),
              ],
              Expanded(
                child: CupertinoButton(
                  key: const Key('tracking-start-stop-button'),
                  color: actionColor,
                  borderRadius: BorderRadius.circular(TrackingRadius.md),
                  padding: const EdgeInsets.symmetric(vertical: TrackingSpacing.md),
                  onPressed: widget.isPreparingStart ? null : stopPressed,
                  child: Text(
                    stopLabel,
                    style: TrackingTypography.title.copyWith(
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        if (canQuickRepeat) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('tracking-repeat-last-button'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              onPressed: () => widget.onStart(widget.suggestedActivityType!),
              icon: const Icon(Icons.history),
              label: Text(
                l10n.trackingRepeatLast(
                  _activityLabel(l10n, widget.suggestedActivityType!),
                ),
              ),
            ),
          ),
          const SizedBox(height: TrackingSpacing.sm),
        ],
        Row(
          children: [
            if (canPauseOrResume) ...[
              Expanded(
                child: FilledButton.tonal(
                  key: const Key('tracking-pause-resume-button'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    textStyle: TrackingTypography.title,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(TrackingRadius.md),
                    ),
                  ),
                  onPressed: pausePressed,
                  child: Text(pauseLabel),
                ),
              ),
              const SizedBox(width: TrackingSpacing.md),
            ],
            Expanded(
              child: FilledButton(
                key: const Key('tracking-start-stop-button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: actionColor,
                  foregroundColor: Colors.white,
                  textStyle: TrackingTypography.title,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(TrackingRadius.md),
                  ),
                ),
                onPressed: widget.isPreparingStart ? null : stopPressed,
                child: Text(stopLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _segmentLabel(String text) {
    return _segmentLabelWithIcon(text, null);
  }

  Widget _segmentLabelWithIcon(String text, IconData? icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TrackingSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 6)],
          Text(text),
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required ActivityType value,
    required bool isEnabled,
  }) {
    final selected = _selectedType == value;
    final chipForeground = selected
        ? Colors.black
        : Theme.of(context).colorScheme.onSurface;
    return ChoiceChip(
      key: Key('tracking-type-${value.name}'),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_activityIcon(value), size: 16, color: chipForeground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TrackingTypography.body.copyWith(
              color: chipForeground,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
      selected: selected,
      onSelected: isEnabled
          ? (_) {
              setState(() {
                _selectedType = value;
              });
            }
          : null,
      side: BorderSide(
        color: selected
            ? TrackingSemanticColors.info
            : Colors.grey.withValues(alpha: 0.4),
      ),
      selectedColor: TrackingSemanticColors.info.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TrackingRadius.pill),
      ),
    );
  }

  String _statusText(AppLocalizations l10n, TrackingSessionState state) {
    switch (state) {
      case TrackingSessionState.idle:
        return l10n.trackingIdle;
      case TrackingSessionState.recording:
        return l10n.trackingRecording;
      case TrackingSessionState.paused:
        return l10n.trackingPaused;
      case TrackingSessionState.stopped:
        return l10n.trackingStopped;
    }
  }

  TrackingStatusTone _statusTone(TrackingSessionState state) {
    switch (state) {
      case TrackingSessionState.idle:
        return TrackingStatusTone.idle;
      case TrackingSessionState.recording:
        return TrackingStatusTone.recording;
      case TrackingSessionState.paused:
        return TrackingStatusTone.idle;
      case TrackingSessionState.stopped:
        return TrackingStatusTone.stopped;
    }
  }

  Color _statusColor(TrackingStatusTone tone) {
    switch (tone) {
      case TrackingStatusTone.idle:
        return TrackingSemanticColors.info;
      case TrackingStatusTone.recording:
        return TrackingSemanticColors.error;
      case TrackingStatusTone.stopped:
        return TrackingSemanticColors.success;
    }
  }

  String _movementLabel(ActivityType type, AppLocalizations l10n) {
    if (type == ActivityType.ride) {
      return l10n.trackingAverageSpeed;
    }
    return l10n.trackingPace;
  }

  IconData _activityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.run:
        return Icons.directions_run;
      case ActivityType.ride:
        return Icons.directions_bike;
      case ActivityType.walk:
        return Icons.hiking;
    }
  }

  String _activityLabel(AppLocalizations l10n, ActivityType type) {
    switch (type) {
      case ActivityType.run:
        return l10n.activityTypeRun;
      case ActivityType.ride:
        return l10n.activityTypeRide;
      case ActivityType.walk:
        return l10n.activityTypeWalk;
    }
  }
}

class _StatusPillMaterial extends StatelessWidget {
  const _StatusPillMaterial({
    super.key,
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TrackingSpacing.md,
        vertical: TrackingSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(TrackingRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: TrackingSpacing.sm),
          Text(
            label,
            style: TrackingTypography.body.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPillCupertino extends StatelessWidget {
  const _StatusPillCupertino({
    super.key,
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(TrackingRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TrackingSpacing.md,
          vertical: TrackingSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.recordingtape, size: 14, color: color),
            const SizedBox(width: TrackingSpacing.sm),
            Text(
              label,
              style: TrackingTypography.body.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsFixIndicator extends StatelessWidget {
  const _GpsFixIndicator({
    required this.hasGpsFix,
    required this.isPreparingStart,
    required this.countdownSeconds,
  });

  final bool hasGpsFix;
  final bool isPreparingStart;
  final int countdownSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final icon = hasGpsFix ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded;
    final color = hasGpsFix
        ? TrackingSemanticColors.success
        : Theme.of(context).colorScheme.error;
    final base = hasGpsFix ? l10n.trackingGpsReady : l10n.trackingGpsSearching;
    final message = isPreparingStart
        ? l10n.trackingGpsPreparingCountdown(countdownSeconds, base)
        : base;

    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: TrackingSpacing.sm),
        Expanded(
          child: Text(
            message,
            key: const Key('tracking-gps-fix-label'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    required this.textStyle,
    required this.metaStyle,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  final TextStyle textStyle;
  final TextStyle metaStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCell(
            label: leftLabel,
            value: leftValue,
            textStyle: textStyle,
            metaStyle: metaStyle,
          ),
        ),
        const SizedBox(width: TrackingSpacing.md),
        Expanded(
          child: _MetricCell(
            label: rightLabel,
            value: rightValue,
            textStyle: textStyle,
            metaStyle: metaStyle,
          ),
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.textStyle,
    required this.metaStyle,
  });

  final String label;
  final String value;
  final TextStyle textStyle;
  final TextStyle metaStyle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(TrackingRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TrackingSpacing.md,
          vertical: TrackingSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: metaStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: TrackingSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: textStyle,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
