import 'dart:async';

import 'package:endurain/core/utils/error_utils.dart';
import 'package:endurain/core/constants/activity_type_catalog.dart';
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/models/route_display_mode.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/services/activity_upload_service.dart';
import 'package:endurain/core/utils/metric_formatter.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/core/utils/activity_upload_feedback_mapper.dart';
import 'package:endurain/core/utils/history_route_thumbnail_key_builder.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:endurain/features/history/activity_detail_screen.dart';
import 'package:endurain/features/history/widgets/activity_route_map.dart';
import 'package:endurain/features/history/widgets/history_metric_widgets.dart';

enum _HistoryDateRange { all, last7Days, last30Days, last90Days, last365Days }

enum _HistorySortOrder { newest, oldest, longest, shortest }

enum _HistoryGroup { today, yesterday, thisWeek, older }

class _HistoryListEntry {
  const _HistoryListEntry.header(this.title) : activity = null, key = null;
  const _HistoryListEntry.item(this.activity, this.key) : title = null;

  final String? title;
  final Activity? activity;
  final String? key;

  bool get isHeader => title != null;
}

IconData _activityIconForType(ActivityType type) {
  switch (type) {
    case ActivityType.run:
      return Icons.directions_run;
    case ActivityType.ride:
      return Icons.directions_bike;
    case ActivityType.walk:
      return Icons.hiking;
  }
}

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({
    super.key,
    required this.repository,
    this.routeDisplayMode = RouteDisplayMode.auto,
    this.onRetryUpload,
    this.onStartFirstActivity,
    this.onDeleteActivity,
    this.onAuthRequired,
    this.isServerConnected = false,
  });

  final ActivityRepository repository;
  final RouteDisplayMode routeDisplayMode;

  final Future<ActivityUploadResult> Function(Activity activity)? onRetryUpload;
  final VoidCallback? onStartFirstActivity;
  final Future<String?> Function(Activity activity)? onDeleteActivity;
  final VoidCallback? onAuthRequired;
  final bool isServerConnected;

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  bool _isLoading = true;
  Object? _error;
  List<Activity> _activities = const <Activity>[];
  final Map<String, List<TrackPoint>> _routePreviewPointsByActivityId =
      <String, List<TrackPoint>>{};
  final Set<String> _routePreviewLoadingIds = <String>{};
  final Map<String, _HistoryMetricSnapshot> _metricSnapshotByActivityId =
      <String, _HistoryMetricSnapshot>{};
  final Set<String> _metricLoadingIds = <String>{};
  StreamSubscription<List<Activity>>? _activitySubscription;
  int? _filterCategoryId;
  _HistoryDateRange _filterDateRange = _HistoryDateRange.all;
  _HistorySortOrder _sortOrder = _HistorySortOrder.newest;
  bool _onlyUnuploaded = false;
  bool _syncHintDismissed = false;
  bool get _useMatchedTrack => widget.routeDisplayMode != RouteDisplayMode.raw;
  static const int _historyPreviewPointLimit = 400;
  static const int _historyPreviewFetchPageSize = 1000;

  @override
  void initState() {
    super.initState();
    _subscribeActivities();
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    super.dispose();
  }

  void _subscribeActivities() {
    _activitySubscription?.cancel();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _activitySubscription = widget.repository.watchAll().listen(
      (items) {
        if (!mounted) return;
        final hadPendingUploads = _activities.any(
          (activity) => !activity.uploaded,
        );
        final hasPendingUploads = items.any((activity) => !activity.uploaded);
        final itemIds = items.map((activity) => activity.id).toSet();
        _routePreviewPointsByActivityId.removeWhere(
          (id, _) => !itemIds.contains(id),
        );
        _routePreviewLoadingIds.removeWhere((id) => !itemIds.contains(id));
        _metricSnapshotByActivityId.removeWhere(
          (id, _) => !itemIds.contains(id),
        );
        _metricLoadingIds.removeWhere((id) => !itemIds.contains(id));
        setState(() {
          _activities = items.reversed.toList();
          if (hadPendingUploads != hasPendingUploads) {
            _syncHintDismissed = false;
          }
          _isLoading = false;
          _error = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = error;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _retryLoad() async {
    _subscribeActivities();
  }

  Future<void> _retryUpload(Activity activity) async {
    final callback = widget.onRetryUpload;
    if (callback == null) return;
    final fullActivity = await _resolveFullActivity(activity);
    final result = await callback(fullActivity);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final message = ActivityUploadFeedbackMapper.toDisplayMessage(result, l10n);

    if (!result.success) {
      if (result.failureType == ActivityUploadFailureType.authentication &&
          widget.onAuthRequired != null) {
        await ErrorUtils.showRetryDialog(
          context: context,
          title: l10n.error,
          message: message,
          onRetry: widget.onAuthRequired!,
          retryLabel: l10n.login,
          cancelLabel: l10n.cancel,
        );
        return;
      }
      await ErrorUtils.showRetryDialog(
        context: context,
        title: l10n.error,
        message: message,
        onRetry: () => _retryUpload(fullActivity),
        retryLabel: '${l10n.retry} Upload',
        cancelLabel: l10n.cancel,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openDetail(Activity activity) async {
    final fullActivity = await _resolveFullActivity(activity);
    if (!mounted) return;
    final detail = ActivityDetailScreen(
      activity: fullActivity,
      useMatchedTrack: _useMatchedTrack,
      onRetryUpload: widget.onRetryUpload == null
          ? null
          : () => _retryUpload(fullActivity),
      onRename: (name) async {
        final trimmed = name.trim();
        final base = await _resolveFullActivity(fullActivity);
        final updated = trimmed.isEmpty
            ? base.copyWith(clearName: true)
            : base.copyWith(name: trimmed);
        await widget.repository.update(updated);
      },
      onDelete: () async {
        final deleted = await _confirmAndDelete(fullActivity);
        if (!mounted || !deleted) return;
        await Navigator.of(context).maybePop();
      },
    );
    if (PlatformUtils.isApplePlatform) {
      await Navigator.of(
        context,
      ).push(CupertinoPageRoute<void>(builder: (context) => detail));
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => detail));
  }

  List<Activity> get _filteredActivities {
    final now = DateTime.now();
    final filtered = _activities.where((activity) {
      final selectedCategoryId = _filterCategoryId;
      final matchesType = switch (selectedCategoryId) {
        null => true,
        _ when activity.activityTypeId != null =>
          activity.activityTypeId == selectedCategoryId,
        _ =>
          activity.activityType ==
              _trackingModeForCategoryId(selectedCategoryId),
      };
      if (!matchesType) return false;
      if (_onlyUnuploaded && activity.uploaded) return false;
      return _matchesDateRange(activity.startedAt, now);
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOrder) {
        case _HistorySortOrder.newest:
          return b.startedAt.compareTo(a.startedAt);
        case _HistorySortOrder.oldest:
          return a.startedAt.compareTo(b.startedAt);
        case _HistorySortOrder.longest:
          return b.durationSeconds.compareTo(a.durationSeconds);
        case _HistorySortOrder.shortest:
          return a.durationSeconds.compareTo(b.durationSeconds);
      }
    });
    return filtered;
  }

  bool _matchesDateRange(DateTime startedAt, DateTime now) {
    switch (_filterDateRange) {
      case _HistoryDateRange.all:
        return true;
      case _HistoryDateRange.last7Days:
        return startedAt.isAfter(now.subtract(const Duration(days: 7)));
      case _HistoryDateRange.last30Days:
        return startedAt.isAfter(now.subtract(const Duration(days: 30)));
      case _HistoryDateRange.last90Days:
        return startedAt.isAfter(now.subtract(const Duration(days: 90)));
      case _HistoryDateRange.last365Days:
        return startedAt.isAfter(now.subtract(const Duration(days: 365)));
    }
  }

  Future<void> _openFilterSheet() async {
    final selected = await showModalBottomSheet<_HistoryFilterSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _HistoryFilterBottomSheet(
        selectedCategoryId: _filterCategoryId,
        selectedDateRange: _filterDateRange,
        selectedSortOrder: _sortOrder,
        onlyUnuploaded: _onlyUnuploaded,
      ),
    );
    if (selected == null) return;
    setState(() {
      _filterCategoryId = selected.categoryId;
      _filterDateRange = selected.dateRange;
      _sortOrder = selected.sortOrder;
      _onlyUnuploaded = selected.onlyUnuploaded;
    });
  }

  Future<void> _renameFromList(Activity activity) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: activity.name ?? '');
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.historyRenameTitle),
          content: TextField(
            controller: controller,
            maxLength: 60,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.historyRenameHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    if (nextName == null) return;
    final base = await _resolveSummaryActivity(activity);
    final updated = nextName.trim().isEmpty
        ? base.copyWith(clearName: true)
        : base.copyWith(name: nextName.trim());
    await widget.repository.update(updated);
  }

  Future<void> _showItemActions(Activity activity) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.historyRenameTitle),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.historyDeleteAction),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      await _renameFromList(activity);
      return;
    }
    await _confirmAndDelete(activity);
  }

  Future<bool> _confirmAndDelete(Activity activity) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.historyDeleteTitle),
        content: Text(l10n.historyDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.historyDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    final callback = widget.onDeleteActivity;
    final base = await _resolveSummaryActivity(activity);
    String? error;
    if (callback != null) {
      error = await callback(base);
    } else {
      await widget.repository.delete(base.id);
    }
    if (!mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    if (error == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.historyDeletedSuccess)),
      );
      return true;
    } else {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return false;
    }
  }

  Future<Activity> _resolveFullActivity(Activity activity) async {
    if (activity.trackPoints.isNotEmpty) return activity;
    final full = await widget.repository.getById(activity.id);
    return full ?? activity;
  }

  Future<Activity> _resolveSummaryActivity(Activity activity) async {
    if (activity.trackPoints.isEmpty) return activity;
    final summary = await widget.repository.getSummaryById(activity.id);
    return summary ?? activity.copyWith(trackPoints: const <TrackPoint>[]);
  }

  Future<void> _ensureRoutePreviewLoaded(Activity activity) async {
    if (activity.trackPoints.length >= 2) {
      _routePreviewPointsByActivityId[activity.id] = activity.trackPoints;
      return;
    }
    if (_routePreviewPointsByActivityId.containsKey(activity.id) ||
        _routePreviewLoadingIds.contains(activity.id)) {
      return;
    }
    _routePreviewLoadingIds.add(activity.id);
    try {
      final points = await _loadSampledPreviewPoints(activity.id);
      if (!mounted || points.isEmpty) return;
      setState(() {
        _routePreviewPointsByActivityId[activity.id] = List<TrackPoint>.from(
          points,
        );
      });
    } finally {
      _routePreviewLoadingIds.remove(activity.id);
    }
  }

  Future<List<TrackPoint>> _loadSampledPreviewPoints(String activityId) async {
    final total = await widget.repository.countTrackPoints(activityId);
    if (total <= 0) return const <TrackPoint>[];
    if (total <= _historyPreviewPointLimit) {
      final all = <TrackPoint>[];
      var offset = 0;
      while (offset < total) {
        final chunk = await widget.repository.getTrackPointsPage(
          activityId,
          limit: _historyPreviewFetchPageSize,
          offset: offset,
        );
        if (chunk.isEmpty) break;
        all.addAll(chunk);
        offset += chunk.length;
      }
      return all;
    }

    final targetOffsets = List<int>.generate(
      _historyPreviewPointLimit,
      (index) =>
          ((index * (total - 1)) / (_historyPreviewPointLimit - 1)).round(),
      growable: false,
    );
    final sampled = <TrackPoint>[];
    var targetIndex = 0;
    var baseOffset = 0;
    while (targetIndex < targetOffsets.length && baseOffset < total) {
      final chunk = await widget.repository.getTrackPointsPage(
        activityId,
        limit: _historyPreviewFetchPageSize,
        offset: baseOffset,
      );
      if (chunk.isEmpty) break;
      for (
        var localIndex = 0;
        localIndex < chunk.length && targetIndex < targetOffsets.length;
        localIndex++
      ) {
        final globalIndex = baseOffset + localIndex;
        while (targetIndex < targetOffsets.length &&
            targetOffsets[targetIndex] == globalIndex) {
          sampled.add(chunk[localIndex]);
          targetIndex++;
        }
      }
      baseOffset += chunk.length;
    }
    return sampled;
  }

  bool _needsSummaryMetricHydration(Activity activity) {
    if (activity.trackPoints.isNotEmpty) return false;
    final metrics = activity.qualityMetrics ?? const <String, dynamic>{};
    final hasElevation =
        metrics.containsKey('filtered_elevation_gain_meters') ||
        metrics.containsKey('raw_elevation_gain_meters');
    final hasAvgHeartRate = metrics.containsKey('avg_heart_rate_bpm');
    final hasAvgCadence = metrics.containsKey('avg_cadence_rpm');
    return !(hasElevation && hasAvgHeartRate && hasAvgCadence);
  }

  Future<void> _ensureSummaryMetricsLoaded(Activity activity) async {
    if (!_needsSummaryMetricHydration(activity)) return;
    if (_metricSnapshotByActivityId.containsKey(activity.id) ||
        _metricLoadingIds.contains(activity.id)) {
      return;
    }
    _metricLoadingIds.add(activity.id);
    try {
      final full = await widget.repository.getById(activity.id);
      if (!mounted || full == null) return;
      setState(() {
        _metricSnapshotByActivityId[activity.id] = _HistoryMetricSnapshot(
          elevationGainMeters: full.elevationGainMeters,
          avgHeartRateBpm: full.averageHeartRateBpm,
          avgCadenceRpm: full.averageCadenceRpm,
        );
      });
    } finally {
      _metricLoadingIds.remove(activity.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (PlatformUtils.isApplePlatform) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(l10n.historyTitle)),
        child: SafeArea(child: _buildBody(context)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('history-loading')),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.historyLoadError,
                key: const Key('history-error'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('history-retry-button'),
                onPressed: _retryLoad,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.route, size: 48),
              const SizedBox(height: 12),
              Text(
                l10n.historyEmptyTitle,
                key: const Key('history-empty-title'),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(l10n.historyEmptyBody, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('history-empty-start-cta'),
                onPressed: widget.onStartFirstActivity,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.historyEmptyCtaStart),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filteredActivities;
    final entries = _buildHistoryEntries(items, l10n);
    final showSyncHint =
        !_syncHintDismissed &&
        !widget.isServerConnected &&
        _activities.any((activity) => !activity.uploaded) &&
        widget.onAuthRequired != null;

    return ListView.separated(
      key: const Key('history-list'),
      itemCount: entries.length + 1,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HistoryFilterBar(
                selectedCategoryId: _filterCategoryId,
                selectedDateRange: _filterDateRange,
                selectedSortOrder: _sortOrder,
                onlyUnuploaded: _onlyUnuploaded,
                onOpenFilters: _openFilterSheet,
              ),
              if (showSyncHint) ...[
                const SizedBox(height: 10),
                _buildSyncHintCard(context, l10n),
              ],
            ],
          );
        }
        final entry = entries[index - 1];
        if (entry.isHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
            child: Text(
              entry.title!,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          );
        }
        final activity = entry.activity!;
        if (_needsSummaryMetricHydration(activity)) {
          unawaited(_ensureSummaryMetricsLoaded(activity));
        }
        final metricSnapshot = _metricSnapshotByActivityId[activity.id];
        final avgHeartRate =
            metricSnapshot?.avgHeartRateBpm ?? activity.averageHeartRateBpm;
        final avgCadence =
            metricSnapshot?.avgCadenceRpm ?? activity.averageCadenceRpm;
        final elevationGainMeters =
            metricSnapshot?.elevationGainMeters ?? activity.elevationGainMeters;
        final avgHeartRateText = avgHeartRate == null
            ? null
            : '${avgHeartRate.round()} bpm';
        final avgCadenceText = avgCadence == null
            ? null
            : '${avgCadence.round()} rpm';
        final routePreviewPoints =
            _routePreviewPointsByActivityId[activity.id] ??
            activity.trackPoints;
        if (routePreviewPoints.length < 2) {
          unawaited(_ensureRoutePreviewLoaded(activity));
        }
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openDetail(activity),
            onLongPress: () => _showItemActions(activity),
            child: IgnorePointer(
              child: Padding(
                key: Key(entry.key!),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _activityIconForType(activity.activityType),
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (activity.name == null ||
                                        activity.name!.isEmpty)
                                    ? _activityTypeLabel(
                                        l10n,
                                        activity.activityType,
                                      )
                                    : activity.name!,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_formatDate(activity.startedAt)} • ${_formatTime(activity.startedAt)}-${_formatTime(activity.endedAt ?? activity.startedAt)}',
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: activity.uploaded
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                activity.uploaded
                                    ? Icons.cloud_done_rounded
                                    : Icons.cloud_upload_rounded,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                activity.uploaded
                                    ? l10n.historyUploadDone
                                    : l10n.historyUploadPending,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 28,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ActivityRouteMap(
                      points: routePreviewPoints,
                      interactive: false,
                      height: 116,
                      useMatchedTrack: _useMatchedTrack,
                      activityType: activity.activityType,
                      thumbnailCacheKey: buildHistoryRouteThumbnailCacheKey(
                        activity,
                      ),
                      showRouteStatus: false,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: CompactMetric(
                            label: l10n.trackingDuration,
                            value: _formatDurationLabeled(
                              activity.durationSeconds,
                            ),
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: CompactMetric(
                            label: l10n.trackingDistance,
                            value: _formatDistance(activity.distanceMeters),
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: CompactMetric(
                            label: _formatMovementMetric(activity, l10n).label,
                            value: _formatMovementMetric(activity, l10n).value,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: CompactMetric(
                            label: l10n.trackingElevationGain,
                            value:
                                '${elevationGainMeters.toStringAsFixed(0)} ${l10n.trackingElevationUnitM}',
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                    if (avgHeartRateText != null || avgCadenceText != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (avgHeartRateText != null)
                            Expanded(
                              child: CompactMetric(
                                label: l10n.historyHeartRate,
                                value: avgHeartRateText,
                                compact: true,
                              ),
                            ),
                          if (avgHeartRateText != null &&
                              avgCadenceText != null)
                            const SizedBox(width: 4),
                          if (avgCadenceText != null)
                            Expanded(
                              child: CompactMetric(
                                label: 'Cadence',
                                value: avgCadenceText,
                                compact: true,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSyncHintCard(BuildContext context, AppLocalizations l10n) {
    return Container(
      key: const Key('history-sync-hint-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_upload_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.connectUploadTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: const Key('history-sync-hint-close'),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    _syncHintDismissed = true;
                  });
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.connectUploadMessage,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const Key('history-sync-hint-connect'),
            onPressed: widget.onAuthRequired,
            icon: const Icon(Icons.login_rounded, size: 18),
            label: Text(l10n.connectUploadAction),
          ),
        ],
      ),
    );
  }

  String _activityTypeLabel(AppLocalizations l10n, ActivityType type) {
    switch (type) {
      case ActivityType.run:
        return l10n.activityTypeRun;
      case ActivityType.ride:
        return l10n.activityTypeRide;
      case ActivityType.walk:
        return l10n.activityTypeWalk;
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDistance(double distanceMeters) {
    final l10n = AppLocalizations.of(context)!;
    return MetricFormatter.formatDistanceKm(
      distanceMeters,
      l10n.trackingDistanceUnitKm,
    );
  }

  List<_HistoryListEntry> _buildHistoryEntries(
    List<Activity> activities,
    AppLocalizations l10n,
  ) {
    final now = DateTime.now();
    final result = <_HistoryListEntry>[];
    _HistoryGroup? currentGroup;

    for (final activity in activities) {
      final group = _groupForDate(activity.startedAt, now);
      if (group != currentGroup) {
        currentGroup = group;
        result.add(_HistoryListEntry.header(_groupTitle(group, l10n)));
      }
      result.add(
        _HistoryListEntry.item(activity, 'history-item-${activity.id}'),
      );
    }
    return result;
  }

  _HistoryGroup _groupForDate(DateTime date, DateTime now) {
    final local = date.toLocal();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(
      Duration(days: todayStart.weekday - 1),
    );

    if (!local.isBefore(todayStart)) {
      return _HistoryGroup.today;
    }
    if (!local.isBefore(yesterdayStart)) {
      return _HistoryGroup.yesterday;
    }
    if (!local.isBefore(weekStart)) {
      return _HistoryGroup.thisWeek;
    }
    return _HistoryGroup.older;
  }

  String _groupTitle(_HistoryGroup group, AppLocalizations l10n) {
    switch (group) {
      case _HistoryGroup.today:
        return l10n.historyGroupToday;
      case _HistoryGroup.yesterday:
        return l10n.historyGroupYesterday;
      case _HistoryGroup.thisWeek:
        return l10n.historyGroupThisWeek;
      case _HistoryGroup.older:
        return l10n.historyGroupOlder;
    }
  }
}

class _MovementMetric {
  const _MovementMetric({required this.label, required this.value});

  final String label;
  final String value;
}

class _HistoryMetricSnapshot {
  const _HistoryMetricSnapshot({
    required this.elevationGainMeters,
    required this.avgHeartRateBpm,
    required this.avgCadenceRpm,
  });

  final double elevationGainMeters;
  final double? avgHeartRateBpm;
  final double? avgCadenceRpm;
}

_MovementMetric _formatMovementMetric(
  Activity activity,
  AppLocalizations l10n,
) {
  if (activity.activityType == ActivityType.ride) {
    final speed = activity.averageSpeedKmh;
    final value = MetricFormatter.formatSpeedKmh(
      speed,
      l10n.trackingSpeedUnitKmh,
    );
    return _MovementMetric(label: l10n.trackingAverageSpeed, value: value);
  }
  final pace = _formatPace(activity.averagePaceSecondsPerKm, l10n);
  return _MovementMetric(label: l10n.trackingPace, value: pace);
}

String _formatPace(double? paceSecondsPerKm, AppLocalizations l10n) {
  return MetricFormatter.formatPace(
    paceSecondsPerKm,
    l10n.trackingPaceUnitMinKm,
  );
}

String _formatDurationLabeled(int seconds) {
  return MetricFormatter.formatDurationLabeled(seconds);
}

ActivityType? _trackingModeForCategoryId(int? categoryId) {
  if (categoryId == null) return null;
  for (final item in ActivityTypeCatalog.items) {
    if (item.id == categoryId) return item.trackingMode;
  }
  return null;
}

String? _categoryLabelForId(int? categoryId) {
  if (categoryId == null) return null;
  for (final item in ActivityTypeCatalog.items) {
    if (item.id == categoryId) return item.fallbackLabel;
  }
  return null;
}

class _HistoryFilterBar extends StatelessWidget {
  const _HistoryFilterBar({
    required this.selectedCategoryId,
    required this.selectedDateRange,
    required this.selectedSortOrder,
    required this.onlyUnuploaded,
    required this.onOpenFilters,
  });

  final int? selectedCategoryId;
  final _HistoryDateRange selectedDateRange;
  final _HistorySortOrder selectedSortOrder;
  final bool onlyUnuploaded;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Text(
            _buildSummary(context, l10n),
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.tonalIcon(
          onPressed: onOpenFilters,
          icon: const Icon(Icons.tune_rounded),
          label: Text(l10n.historyFilterSort),
        ),
      ],
    );
  }

  String _buildSummary(BuildContext context, AppLocalizations l10n) {
    final typeLabel =
        _categoryLabelForId(selectedCategoryId) ?? l10n.historyFilterAll;
    final rangeLabel = switch (selectedDateRange) {
      _HistoryDateRange.all => l10n.historyRangeAllTime,
      _HistoryDateRange.last7Days => l10n.historyRange7d,
      _HistoryDateRange.last30Days => l10n.historyRange30d,
      _HistoryDateRange.last90Days => l10n.historyRange90d,
      _HistoryDateRange.last365Days => l10n.historyRange1y,
    };
    final sortLabel = switch (selectedSortOrder) {
      _HistorySortOrder.newest => l10n.historySortNewest,
      _HistorySortOrder.oldest => l10n.historySortOldest,
      _HistorySortOrder.longest => l10n.historySortLongest,
      _HistorySortOrder.shortest => l10n.historySortShortest,
    };
    final unuploaded = onlyUnuploaded ? ' • ${l10n.historyOnlyUnuploaded}' : '';
    return '$typeLabel • $rangeLabel • $sortLabel$unuploaded';
  }
}

class _HistoryFilterSelection {
  const _HistoryFilterSelection({
    required this.categoryId,
    required this.dateRange,
    required this.sortOrder,
    required this.onlyUnuploaded,
  });

  final int? categoryId;
  final _HistoryDateRange dateRange;
  final _HistorySortOrder sortOrder;
  final bool onlyUnuploaded;
}

class _HistoryFilterBottomSheet extends StatefulWidget {
  const _HistoryFilterBottomSheet({
    required this.selectedCategoryId,
    required this.selectedDateRange,
    required this.selectedSortOrder,
    required this.onlyUnuploaded,
  });

  final int? selectedCategoryId;
  final _HistoryDateRange selectedDateRange;
  final _HistorySortOrder selectedSortOrder;
  final bool onlyUnuploaded;

  @override
  State<_HistoryFilterBottomSheet> createState() =>
      _HistoryFilterBottomSheetState();
}

class _HistoryFilterBottomSheetState extends State<_HistoryFilterBottomSheet> {
  late int? _categoryId = widget.selectedCategoryId;
  late _HistoryDateRange _range = widget.selectedDateRange;
  late _HistorySortOrder _sortOrder = widget.selectedSortOrder;
  late bool _onlyUnuploaded = widget.onlyUnuploaded;
  String _categorySearch = '';

  List<ActivityTypeCatalogItem> _filteredCatalogItems(String query) {
    if (query.isEmpty) return ActivityTypeCatalog.items;
    final normalized = query.toLowerCase();
    return ActivityTypeCatalog.items
        .where((item) => item.fallbackLabel.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.86;
    return SizedBox(
      height: maxHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + mediaQuery.padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.historyFilterSort,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    Text(l10n.activityTypeLabel),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('history-filter-category-search'),
                      onChanged: (value) =>
                          setState(() => _categorySearch = value.trim()),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.historyFilterCategorySearchHint,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ChoiceChip(
                      label: Text(l10n.historyFilterAll),
                      selected: _categoryId == null,
                      onSelected: (_) => setState(() => _categoryId = null),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filteredCatalogItems(_categorySearch)
                          .map(
                            (item) => ChoiceChip(
                              avatar: Icon(item.icon, size: 16),
                              label: Text(item.fallbackLabel),
                              selected: _categoryId == item.id,
                              onSelected: (_) =>
                                  setState(() => _categoryId = item.id),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 14),
                    Text(l10n.historyDateRange),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.historyRange7d),
                          selected: _range == _HistoryDateRange.last7Days,
                          onSelected: (_) => setState(
                            () => _range = _HistoryDateRange.last7Days,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(l10n.historyRange30d),
                          selected: _range == _HistoryDateRange.last30Days,
                          onSelected: (_) => setState(
                            () => _range = _HistoryDateRange.last30Days,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(l10n.historyRange90d),
                          selected: _range == _HistoryDateRange.last90Days,
                          onSelected: (_) => setState(
                            () => _range = _HistoryDateRange.last90Days,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(l10n.historyRange1y),
                          selected: _range == _HistoryDateRange.last365Days,
                          onSelected: (_) => setState(
                            () => _range = _HistoryDateRange.last365Days,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(l10n.historyRangeAllTime),
                          selected: _range == _HistoryDateRange.all,
                          onSelected: (_) =>
                              setState(() => _range = _HistoryDateRange.all),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(l10n.historySortBy),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.historySortNewest),
                          selected: _sortOrder == _HistorySortOrder.newest,
                          onSelected: (_) => setState(
                            () => _sortOrder = _HistorySortOrder.newest,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(l10n.historySortOldest),
                          selected: _sortOrder == _HistorySortOrder.oldest,
                          onSelected: (_) => setState(
                            () => _sortOrder = _HistorySortOrder.oldest,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(l10n.historySortLongest),
                          selected: _sortOrder == _HistorySortOrder.longest,
                          onSelected: (_) => setState(
                            () => _sortOrder = _HistorySortOrder.longest,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(l10n.historySortShortest),
                          selected: _sortOrder == _HistorySortOrder.shortest,
                          onSelected: (_) => setState(
                            () => _sortOrder = _HistorySortOrder.shortest,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _onlyUnuploaded,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) =>
                          setState(() => _onlyUnuploaded = value),
                      title: Text(l10n.historyOnlyUnuploaded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('history-filter-reset'),
                    onPressed: () {
                      setState(() {
                        _categoryId = null;
                        _range = _HistoryDateRange.all;
                        _sortOrder = _HistorySortOrder.newest;
                        _onlyUnuploaded = false;
                        _categorySearch = '';
                      });
                    },
                    child: Text(l10n.historyFilterReset),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const Key('history-filter-apply'),
                    onPressed: () {
                      Navigator.of(context).pop(
                        _HistoryFilterSelection(
                          categoryId: _categoryId,
                          dateRange: _range,
                          sortOrder: _sortOrder,
                          onlyUnuploaded: _onlyUnuploaded,
                        ),
                      );
                    },
                    child: Text(l10n.apply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
