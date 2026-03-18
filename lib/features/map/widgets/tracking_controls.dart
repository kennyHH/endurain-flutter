import 'package:endurain/core/constants/activity_type_catalog.dart';
import 'package:endurain/core/constants/tracking_ui_tokens.dart';
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:endurain/core/theme/endurain_design_system.dart';
import 'package:endurain/core/utils/activity_type_localization.dart';
import 'package:endurain/core/utils/metric_formatter.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/features/map/widgets/activity_type_picker_sheet.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/models/metric_type.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/di/service_locator.dart';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final void Function(ActivityType activityType, int activityTypeId) onStart;
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
  ActivityTypeCatalogItem _selectedActivity = ActivityTypeCatalog.defaultItem;
  late final PageController _metricsPageController;
  int _metricsPage = 0;
  List<MetricType?> _page1Metrics = [
    MetricType.distance,
    MetricType.elevation,
    MetricType.speed,
    MetricType.pace,
  ];
  List<MetricType?> _page2Metrics = [
    MetricType.none,
    MetricType.none,
    MetricType.none,
    MetricType.none,
  ];
  final _storage = serviceLocator<SecureStorageService>();

  @override
  void initState() {
    super.initState();
    _selectedActivity = ActivityTypeCatalog.fromSuggestedMode(
      widget.suggestedActivityType,
    );
    _metricsPageController = PageController();
    _loadMetricConfig();
  }

  @override
  void dispose() {
    _metricsPageController.dispose();
    super.dispose();
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
      _selectedActivity = ActivityTypeCatalog.fromSuggestedMode(suggested);
    }
  }

  Future<void> _loadMetricConfig() async {
    final jsonString = await _storage.getMetricConfig();
    if (jsonString != null) {
      try {
        final data = json.decode(jsonString) as Map<String, dynamic>;
        setState(() {
          _page1Metrics = (data['page1'] as List<dynamic>)
              .map((e) => _parseMetricType(e as String?))
              .toList();
          _page2Metrics = (data['page2'] as List<dynamic>)
              .map((e) => _parseMetricType(e as String?))
              .toList();
        });
      } catch (_) {}
    }
  }

  Future<void> _saveMetricConfig() async {
    final data = {
      'page1': _page1Metrics.map((e) => e?.name ?? 'none').toList(),
      'page2': _page2Metrics.map((e) => e?.name ?? 'none').toList(),
    };
    await _storage.setMetricConfig(json.encode(data));
  }

  MetricType? _parseMetricType(String? name) {
    if (name == null || name == 'none') return MetricType.none;
    return MetricType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => MetricType.none,
    );
  }

  String _formatMetricValue(
    MetricType type,
    AppLocalizations l10n,
    TrackingSessionSnapshot snapshot,
    ActivityType effectiveType,
  ) {
    switch (type) {
      case MetricType.distance:
        return MetricFormatter.formatDistanceKm(
          snapshot.distanceMeters,
          l10n.trackingDistanceUnitKm,
        );
      case MetricType.duration:
        return MetricFormatter.formatDurationClock(snapshot.duration);
      case MetricType.speed:
        return MetricFormatter.formatSpeedKmh(
          _currentSpeedKmh(snapshot.trackPoints),
          l10n.trackingSpeedUnitKmh,
        );
      case MetricType.avgSpeed:
        final avgSpeed = snapshot.duration.inSeconds > 0
            ? (snapshot.distanceMeters / snapshot.duration.inSeconds) * 3.6
            : 0.0;
        return MetricFormatter.formatSpeedKmh(
          avgSpeed,
          l10n.trackingSpeedUnitKmh,
        );
      case MetricType.pace:
        final speedKmh = _currentSpeedKmh(snapshot.trackPoints);
        if (speedKmh == null || speedKmh <= 0.1) return '-:--';
        final paceMinKm = 60 / speedKmh;
        final min = paceMinKm.floor();
        final sec = ((paceMinKm - min) * 60).round();
        return '$min:${sec.toString().padLeft(2, '0')}';
      case MetricType.avgPace:
        final avgSpeed = snapshot.duration.inSeconds > 0
            ? (snapshot.distanceMeters / snapshot.duration.inSeconds) * 3.6
            : 0.0;
        if (avgSpeed <= 0.1) return '-:--';
        final paceMinKm = 60 / avgSpeed;
        final min = paceMinKm.floor();
        final sec = ((paceMinKm - min) * 60).round();
        return '$min:${sec.toString().padLeft(2, '0')}';
      case MetricType.elevation:
        return '${snapshot.elevationGainMeters.toStringAsFixed(0)} ${l10n.trackingElevationUnitM}';
      case MetricType.heartRate:
        final hr = snapshot.currentHeartRate;
        return hr != null ? '$hr' : '--';
      case MetricType.cadence:
        final cad = snapshot.currentCadence;
        return cad != null ? '$cad' : '--';
      case MetricType.none:
        return '';
    }
  }

  void _showMetricPicker(int pageIndex, int slotIndex) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Metric',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: MetricType.values
                      .map(
                        (type) => ListTile(
                          leading: type == MetricType.none
                              ? const Icon(Icons.close)
                              : null,
                          title: Text(
                            type == MetricType.none
                                ? 'Empty / Remove'
                                : type.label(AppLocalizations.of(context)!),
                          ),
                          onTap: () {
                            setState(() {
                              if (pageIndex == 0) {
                                _page1Metrics[slotIndex] = type;
                              } else {
                                _page2Metrics[slotIndex] = type;
                              }
                            });
                            _saveMetricConfig();
                            Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricSlot(
    int pageIndex,
    int slotIndex,
    AppLocalizations l10n,
    TrackingSessionSnapshot snapshot,
    ActivityType effectiveType,
    TextStyle valueStyle,
    TextStyle labelStyle,
  ) {
    final metrics = pageIndex == 0 ? _page1Metrics : _page2Metrics;
    if (metrics.length <= slotIndex) return const SizedBox();

    final type = metrics[slotIndex] ?? MetricType.none;

    if (type == MetricType.none) {
      return GestureDetector(
        onTap: () => _showMetricPicker(pageIndex, slotIndex),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.add,
              size: 24,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showMetricPicker(pageIndex, slotIndex);
      },
      child: _MetricCell(
        label: type.label(l10n),
        value: _formatMetricValue(type, l10n, snapshot, effectiveType),
        textStyle: valueStyle,
        metaStyle: labelStyle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isRecording = widget.snapshot.state == TrackingSessionState.recording;
    final isPaused = widget.snapshot.state == TrackingSessionState.paused;
    final canPauseOrResume = isRecording || isPaused;
    final status = _statusText(l10n, widget.snapshot.state);
    final effectiveType =
        widget.snapshot.activityType ?? _selectedActivity.trackingMode;
    final isLiveTracking = isRecording || isPaused;
    final tone = _statusTone(widget.snapshot.state);
    final actionColor = (isRecording || isPaused)
        ? TrackingSemanticColors.error
        : TrackingSemanticColors.success;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 390;
        final metricValueStyle =
            EndurainTypography.metricValue(theme.colorScheme).copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: isLiveTracking
                  ? (isCompact ? 44 : 56)
                  : (isCompact ? 40 : 48),
              fontWeight: FontWeight.w900,
              height: 1.0,
            );
        final metricMetaStyle =
            EndurainTypography.metricLabel(theme.colorScheme).copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: isCompact ? 12.0 : 13.5,
              fontWeight: FontWeight.w600,
            );

        final metricsPager = _MetricPager(
          pageController: _metricsPageController,
          page: _metricsPage,
          onPageChanged: (page) {
            if (_metricsPage == page) return;
            setState(() {
              _metricsPage = page;
            });
          },
          firstPageTop: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildMetricSlot(
                  0,
                  0,
                  l10n,
                  widget.snapshot,
                  effectiveType,
                  metricValueStyle,
                  metricMetaStyle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricSlot(
                  0,
                  1,
                  l10n,
                  widget.snapshot,
                  effectiveType,
                  metricValueStyle,
                  metricMetaStyle,
                ),
              ),
            ],
          ),
          firstPageBottom: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildMetricSlot(
                  0,
                  2,
                  l10n,
                  widget.snapshot,
                  effectiveType,
                  metricValueStyle,
                  metricMetaStyle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricSlot(
                  0,
                  3,
                  l10n,
                  widget.snapshot,
                  effectiveType,
                  metricValueStyle,
                  metricMetaStyle,
                ),
              ),
            ],
          ),
          secondPageTop: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildMetricSlot(
                  1,
                  0,
                  l10n,
                  widget.snapshot,
                  effectiveType,
                  metricValueStyle,
                  metricMetaStyle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricSlot(
                  1,
                  1,
                  l10n,
                  widget.snapshot,
                  effectiveType,
                  metricValueStyle,
                  metricMetaStyle,
                ),
              ),
            ],
          ),
          secondPageBottom: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildMetricSlot(
                  1,
                  2,
                  l10n,
                  widget.snapshot,
                  effectiveType,
                  metricValueStyle,
                  metricMetaStyle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricSlot(
                  1,
                  3,
                  l10n,
                  widget.snapshot,
                  effectiveType,
                  metricValueStyle,
                  metricMetaStyle,
                ),
              ),
            ],
          ),
        );

        final actionButtons = _buildActionButtons(
          context: context,
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
                isCompact ? TrackingSpacing.sm : TrackingSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusGpsLine(
                    key: const Key('tracking-status-label'),
                    status: status,
                    statusColor: cupertinoStatusColor(tone),
                    hasGpsFix: widget.hasGpsFix,
                    isPreparingStart: widget.isPreparingStart,
                    countdownSeconds: widget.startCountdownSeconds,
                  ),
                  const SizedBox(height: 2),
                  metricsPager,
                  const SizedBox(height: 4),
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
              isCompact ? TrackingSpacing.sm : TrackingSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusGpsLine(
                  key: const Key('tracking-status-label'),
                  status: status,
                  statusColor: _statusColor(tone),
                  hasGpsFix: widget.hasGpsFix,
                  isPreparingStart: widget.isPreparingStart,
                  countdownSeconds: widget.startCountdownSeconds,
                ),
                const SizedBox(height: 2),
                metricsPager,
                const SizedBox(height: 0),
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

    void pausePressed() {
      if (isRecording) {
        widget.onPause();
      } else {
        widget.onResume();
      }
    }

    void stopPressed() {
      if (widget.isPreparingStart) return;
      if (isRecording || isPaused) {
        widget.onStop();
      } else {
        widget.onStart(_selectedActivity.trackingMode, _selectedActivity.id);
      }
    }

    // NEW: If initializing, show "Starting in X..." button
    if (widget.isPreparingStart) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.tonal(
          onPressed: null,
          child: Text(
            l10n.trackingGpsPreparingCountdown(
              widget.startCountdownSeconds,
              widget.hasGpsFix
                  ? l10n.trackingGpsReady
                  : l10n.trackingGpsSearching,
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (canPauseOrResume) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.activityTypeLabel,
            style: EndurainTypography.helper(Theme.of(context).colorScheme),
          ),
          const SizedBox(height: 4),
          _buildActivityTypeSelector(l10n, isEnabled: false),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  key: const Key('tracking-pause-resume-button'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    textStyle: TrackingTypography.title,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(TrackingRadius.md),
                    ),
                  ),
                  onPressed: pausePressed,
                  child: Text(pauseLabel),
                ),
              ),
              const SizedBox(width: TrackingSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const Key('tracking-start-stop-button'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
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

    // IDLE State
    final canStartNow = widget.hasGpsFix;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.activityTypeLabel,
                    style: EndurainTypography.helper(
                      Theme.of(context).colorScheme,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildActivityTypeSelector(l10n, isEnabled: true),
                ],
              ),
            ),
            const SizedBox(width: TrackingSpacing.md),
            Expanded(
              flex: 6,
              child: FilledButton(
                key: const Key('tracking-start-stop-button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: TrackingSemanticColors.success,
                  disabledBackgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  textStyle: EndurainTypography.metricLabel(
                    Theme.of(context).colorScheme,
                  ).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(TrackingRadius.md),
                  ),
                ),
                onPressed:
                    widget.isPreparingStart || !canStartNow ? null : stopPressed,
                child: Text(stopLabel),
              ),
            ),
          ],
        ),
        if (!canStartNow) ...[
          const SizedBox(height: 6),
          Text(
            l10n.trackingGpsNeedStableFix,
            key: const Key('tracking-start-disabled-reason'),
            style: EndurainTypography.helper(
              Theme.of(context).colorScheme,
            ).copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActivityTypeSelector(
    AppLocalizations l10n, {
    required bool isEnabled,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = _catalogLabel(_selectedActivity, l10n);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('tracking-activity-type-selector'),
        borderRadius: BorderRadius.circular(TrackingRadius.md),
        onTap: isEnabled
            ? () async {
                final selectedId = await showActivityTypePickerSheet(
                  context: context,
                  selectedTypeId: _selectedActivity.id,
                  labelBuilder: (item) => _catalogLabel(item, l10n),
                );
                if (selectedId == null) return;
                setState(() {
                  _selectedActivity = ActivityTypeCatalog.byId(selectedId);
                });
              }
            : null,
        child: Ink(
          height: 56,
          key: const Key('tracking-activity-type'),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(TrackingRadius.md),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TrackingSpacing.sm,
              vertical: TrackingSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(_selectedActivity.icon, size: 18),
                const SizedBox(width: EndurainSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EndurainTypography.metricLabel(colorScheme).copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: EndurainSpacing.xs),
                Icon(
                  isEnabled ? Icons.expand_more_rounded : Icons.lock_outline,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _catalogLabel(ActivityTypeCatalogItem item, AppLocalizations l10n) {
    return localizeActivityTypeById(l10n, item.id);
  }

  double? _currentSpeedKmh(List<TrackPoint> points) {
    if (points.length < 2) return null;
    final last = points.last;
    final previous = points[points.length - 2];
    final dtSeconds =
        last.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
    if (dtSeconds <= 0) return null;
    final distanceMeters = _distanceMeters(
      previous.latitude,
      previous.longitude,
      last.latitude,
      last.longitude,
    );
    if (!distanceMeters.isFinite || distanceMeters <= 0) return null;
    return (distanceMeters / dtSeconds) * 3.6;
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (pi / 180.0);

  String _statusText(AppLocalizations l10n, TrackingSessionState state) {
    switch (state) {
      case TrackingSessionState.initializing:
        return 'Initializing...';
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
      case TrackingSessionState.initializing:
        return TrackingStatusTone.idle;
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

}

class _StatusGpsLine extends StatelessWidget {
  const _StatusGpsLine({
    super.key,
    required this.status,
    required this.statusColor,
    required this.hasGpsFix,
    required this.isPreparingStart,
    required this.countdownSeconds,
  });

  final String status;
  final Color statusColor;
  final bool hasGpsFix;
  final bool isPreparingStart;
  final int countdownSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final gpsColor = hasGpsFix
        ? TrackingSemanticColors.success
        : Theme.of(context).colorScheme.error;
    final base = hasGpsFix ? l10n.trackingGpsReady : l10n.trackingGpsSearching;
    final message = isPreparingStart
        ? l10n.trackingGpsPreparingCountdown(countdownSeconds, base)
        : base;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TrackingSpacing.sm,
            vertical: TrackingSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(TrackingRadius.pill),
          ),
          child: Text(
            status,
            style: TrackingTypography.body.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: TrackingSpacing.sm),
        Expanded(
          child: Text(
            message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: gpsColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricPager extends StatelessWidget {
  const _MetricPager({
    required this.pageController,
    required this.page,
    required this.onPageChanged,
    required this.firstPageTop,
    required this.firstPageBottom,
    required this.secondPageTop,
    required this.secondPageBottom,
  });

  final PageController pageController;
  final int page;
  final ValueChanged<int> onPageChanged;
  final Widget firstPageTop;
  final Widget firstPageBottom;
  final Widget secondPageTop;
  final Widget secondPageBottom;

  @override
  Widget build(BuildContext context) {
    final active = Theme.of(context).colorScheme.primary;
    final inactive = Theme.of(context).colorScheme.outlineVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 160,
          child: PageView(
            controller: pageController,
            onPageChanged: onPageChanged,
            children: [
              _MetricPageBody(top: firstPageTop, bottom: firstPageBottom),
              _MetricPageBody(top: secondPageTop, bottom: secondPageBottom),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PageDot(
              active: page == 0,
              activeColor: active,
              inactiveColor: inactive,
            ),
            const SizedBox(width: 6),
            _PageDot(
              active: page == 1,
              activeColor: active,
              inactiveColor: inactive,
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricPageBody extends StatelessWidget {
  const _MetricPageBody({required this.top, required this.bottom});

  final Widget top;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Expanded(child: top),
          const SizedBox(height: 4),
          Expanded(child: bottom),
        ],
      ),
    );
  }
}

class _PageDot extends StatelessWidget {
  const _PageDot({
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
  });

  final bool active;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 14 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(999),
      ),
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
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(TrackingRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: metaStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: textStyle,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
