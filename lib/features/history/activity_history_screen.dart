import 'dart:async';

import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/models/route_display_mode.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/services/activity_upload_service.dart';
import 'package:endurain/core/services/map_matching_preview_service.dart';
import 'package:endurain/core/utils/metric_formatter.dart';
import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/core/utils/activity_upload_feedback_mapper.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

enum _HistoryDateRange { all, last7Days, last30Days, last90Days, last365Days }

enum _HistorySortOrder { newest, oldest, longest, shortest }

enum _HistoryGroup { today, yesterday, thisWeek, older }

class _HistoryListEntry {
  const _HistoryListEntry.header(this.title)
    : activity = null,
      key = null;
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
  });

  final ActivityRepository repository;
  final RouteDisplayMode routeDisplayMode;

  final Future<ActivityUploadResult> Function(Activity activity)? onRetryUpload;
  final VoidCallback? onStartFirstActivity;
  final Future<String?> Function(Activity activity)? onDeleteActivity;

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  bool _isLoading = true;
  Object? _error;
  List<Activity> _activities = const <Activity>[];
  StreamSubscription<List<Activity>>? _activitySubscription;
  ActivityType? _filterType;
  _HistoryDateRange _filterDateRange = _HistoryDateRange.all;
  _HistorySortOrder _sortOrder = _HistorySortOrder.newest;
  bool _onlyUnuploaded = false;
  bool get _useMatchedTrack => widget.routeDisplayMode != RouteDisplayMode.raw;

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
        setState(() {
          _activities = items.reversed.toList();
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
    final result = await callback(activity);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final base = ActivityUploadFeedbackMapper.toUserMessage(result, l10n);
    final status = result.statusCode;
    final detail = result.serverDetail;
    final withStatus = (!result.success && status != null)
        ? '$base (HTTP $status)'
        : base;
    final message = (detail != null && detail.isNotEmpty)
        ? '$withStatus - $detail'
        : withStatus;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDetail(BuildContext context, Activity activity) async {
    final detail = ActivityDetailScreen(
      activity: activity,
      useMatchedTrack: _useMatchedTrack,
      onRetryUpload: widget.onRetryUpload == null
          ? null
          : () => _retryUpload(activity),
      onRename: (name) async {
        final trimmed = name.trim();
        final updated = trimmed.isEmpty
            ? activity.copyWith(clearName: true)
            : activity.copyWith(name: trimmed);
        await widget.repository.update(updated);
      },
      onDelete: () => _confirmAndDelete(activity),
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
      final matchesType =
          _filterType == null || activity.activityType == _filterType;
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
      builder: (context) => _HistoryFilterBottomSheet(
        selectedType: _filterType,
        selectedDateRange: _filterDateRange,
        selectedSortOrder: _sortOrder,
        onlyUnuploaded: _onlyUnuploaded,
      ),
    );
    if (selected == null) return;
    setState(() {
      _filterType = selected.type;
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
    final updated = nextName.trim().isEmpty
        ? activity.copyWith(clearName: true)
        : activity.copyWith(name: nextName.trim());
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

  Future<void> _confirmAndDelete(Activity activity) async {
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
    if (confirmed != true) return;
    final callback = widget.onDeleteActivity;
    String? error;
    if (callback != null) {
      error = await callback(activity);
    } else {
      await widget.repository.delete(activity.id);
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (error == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.historyDeletedSuccess)),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(error)),
      );
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

    return ListView.separated(
      key: const Key('history-list'),
      itemCount: entries.length + 1,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _HistoryFilterBar(
            selectedType: _filterType,
            selectedDateRange: _filterDateRange,
            selectedSortOrder: _sortOrder,
            onlyUnuploaded: _onlyUnuploaded,
            onOpenFilters: _openFilterSheet,
          );
        }
        final entry = entries[index - 1];
        if (entry.isHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
            child: Text(
              entry.title!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }
        final activity = entry.activity!;
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openDetail(context, activity),
            onLongPress: () => _showItemActions(activity),
            child: Padding(
              key: Key(entry.key!),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _activityIconForType(activity.activityType),
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (activity.name == null || activity.name!.isEmpty)
                              ? _activityTypeLabel(l10n, activity.activityType)
                              : activity.name!,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 30,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatDate(activity.startedAt)} • ${_formatTime(activity.startedAt)}-${_formatTime(activity.endedAt ?? activity.startedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatDistance(activity.distanceMeters)} • ${MetricFormatter.formatDurationLabeled(activity.durationSeconds)} • +${activity.elevationGainMeters.toStringAsFixed(0)} ${l10n.trackingElevationUnitM}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!activity.uploaded) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.historyUploadPending,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _ActivityRouteMap(
                    points: activity.trackPoints,
                    interactive: false,
                    height: 110,
                    useMatchedTrack: _useMatchedTrack,
                    activityType: activity.activityType,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CompactMetric(
                        label: l10n.trackingDuration,
                        value: _formatDurationLabeled(
                          activity.durationSeconds,
                        ),
                        width: 126,
                      ),
                      _CompactMetric(
                        label: l10n.trackingDistance,
                        value: _formatDistance(activity.distanceMeters),
                        width: 126,
                      ),
                      _CompactMetric(
                        label: _formatMovementMetric(activity, l10n).label,
                        value: _formatMovementMetric(activity, l10n).value,
                        width: 126,
                      ),
                      _CompactMetric(
                        label: l10n.trackingElevationGain,
                        value:
                            '${activity.elevationGainMeters.toStringAsFixed(0)} ${l10n.trackingElevationUnitM}',
                        width: 126,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    return MetricFormatter.formatDistanceKm(distanceMeters, l10n.trackingDistanceUnitKm);
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
      result.add(_HistoryListEntry.item(activity, 'history-item-${activity.id}'));
    }
    return result;
  }

  _HistoryGroup _groupForDate(DateTime date, DateTime now) {
    final local = date.toLocal();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));

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

class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({
    super.key,
    required this.activity,
    this.useMatchedTrack = false,
    this.onRetryUpload,
    this.onRename,
    this.onDelete,
  });

  final Activity activity;
  final bool useMatchedTrack;
  final Future<void> Function()? onRetryUpload;
  final Future<void> Function(String name)? onRename;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final points = activity.trackPoints.length;
    final type = switch (activity.activityType) {
      ActivityType.run => l10n.activityTypeRun,
      ActivityType.ride => l10n.activityTypeRide,
      ActivityType.walk => l10n.activityTypeWalk,
    };
    final distance =
        '${(activity.distanceMeters / 1000).toStringAsFixed(2)} ${l10n.trackingDistanceUnitKm}';
    final movementMetric = _formatMovementMetric(activity, l10n);
    final elevationGain =
        '${activity.elevationGainMeters.toStringAsFixed(0)} ${l10n.trackingElevationUnitM}';
    final elevationLoss =
        '${activity.elevationLossMeters.toStringAsFixed(0)} ${l10n.trackingElevationUnitM}';
    final duration = _formatDurationLabeled(activity.durationSeconds);
    final activityIcon = _activityIconForType(activity.activityType);
    final compact = MediaQuery.sizeOf(context).width < 380;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(activityIcon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                activity.name?.isNotEmpty == true
                    ? activity.name!
                    : l10n.historyDetailTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (onRename != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final controller = TextEditingController(
                  text: activity.name ?? '',
                );
                final nextName = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(l10n.historyRenameTitle),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        maxLength: 60,
                        decoration: InputDecoration(
                          hintText: l10n.historyRenameHint,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(controller.text),
                          child: Text(l10n.save),
                        ),
                      ],
                    );
                  },
                );
                if (nextName == null) return;
                await onRename!(nextName);
              },
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ActivityRouteMap(
            points: activity.trackPoints,
            interactive: false,
            height: compact ? 206 : 240,
            useMatchedTrack: useMatchedTrack,
            activityType: activity.activityType,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => _RouteOverviewScreen(
                    activity: activity,
                    useMatchedTrack: useMatchedTrack,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _MapTapHint(
            text: l10n.historyTapMapForOverview,
            compact: compact,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: EdgeInsets.all(compact ? 10 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdaptiveMetricGrid(
                    compact: compact,
                    children: [
                      _MetricTile(
                        icon: activityIcon,
                        label: l10n.activityTypeLabel,
                        value: type,
                        compact: compact,
                      ),
                      _MetricTile(
                        icon: Icons.timer_outlined,
                        label: l10n.trackingDuration,
                        value: duration,
                        compact: compact,
                      ),
                      _MetricTile(
                        icon: Icons.straighten,
                        label: l10n.trackingDistance,
                        value: distance,
                        compact: compact,
                      ),
                      _MetricTile(
                        icon: Icons.speed,
                        label: movementMetric.label,
                        value: movementMetric.value,
                        compact: compact,
                      ),
                      _MetricTile(
                        icon: Icons.north_east_rounded,
                        label: l10n.trackingElevationGain,
                        value: elevationGain,
                        compact: compact,
                      ),
                      _MetricTile(
                        icon: Icons.south_east_rounded,
                        label: l10n.historyElevationLoss,
                        value: elevationLoss,
                        compact: compact,
                      ),
                      _MetricTile(
                        icon: Icons.pin_drop_outlined,
                        label: l10n.historyTrackPoints,
                        value: points.toString(),
                        compact: compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ElevationProfileCard(points: activity.trackPoints, compact: compact),
          if (onRetryUpload != null && !activity.uploaded) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('history-retry-upload-button'),
              onPressed: onRetryUpload,
              icon: const Icon(Icons.cloud_upload),
              label: Text('${l10n.retry} upload'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MovementMetric {
  const _MovementMetric({required this.label, required this.value});

  final String label;
  final String value;
}

_MovementMetric _formatMovementMetric(Activity activity, AppLocalizations l10n) {
  if (activity.activityType == ActivityType.ride) {
    final speed = activity.averageSpeedKmh;
    final value = MetricFormatter.formatSpeedKmh(speed, l10n.trackingSpeedUnitKmh);
    return _MovementMetric(label: l10n.trackingAverageSpeed, value: value);
  }
  final pace = _formatPace(activity.averagePaceSecondsPerKm, l10n);
  return _MovementMetric(label: l10n.trackingPace, value: pace);
}

String _formatPace(double? paceSecondsPerKm, AppLocalizations l10n) {
  return MetricFormatter.formatPace(paceSecondsPerKm, l10n.trackingPaceUnitMinKm);
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.width,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final double? width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? 164,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 8 : 9,
        ),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: compact ? 15 : 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: compact ? 6 : 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: compact ? 10.5 : null,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 12.5 : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDurationLabeled(int seconds) {
  return MetricFormatter.formatDurationLabeled(seconds);
}

class _AdaptiveMetricGrid extends StatelessWidget {
  const _AdaptiveMetricGrid({required this.children, required this.compact});

  final List<_MetricTile> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = compact ? 8.0 : 10.0;
        final minWidth = compact ? 136.0 : 156.0;
        final maxColumns = constraints.maxWidth >= 640 ? 3 : 2;
        final columns = ((constraints.maxWidth + spacing) / (minWidth + spacing))
            .floor()
            .clamp(1, maxColumns);
        final tileWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map(
                (tile) => _MetricTile(
                  icon: tile.icon,
                  label: tile.label,
                  value: tile.value,
                  compact: tile.compact,
                  width: tileWidth,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MapTapHint extends StatelessWidget {
  const _MapTapHint({required this.text, required this.compact});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.open_in_full_rounded,
          size: compact ? 14 : 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: compact ? 11.5 : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.label, required this.value, this.width});

  final String label;
  final String value;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryFilterBar extends StatelessWidget {
  const _HistoryFilterBar({
    required this.selectedType,
    required this.selectedDateRange,
    required this.selectedSortOrder,
    required this.onlyUnuploaded,
    required this.onOpenFilters,
  });

  final ActivityType? selectedType;
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
    final typeLabel = switch (selectedType) {
      ActivityType.run => l10n.activityTypeRun,
      ActivityType.ride => l10n.activityTypeRide,
      ActivityType.walk => l10n.activityTypeWalk,
      null => l10n.historyFilterAll,
    };
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
    required this.type,
    required this.dateRange,
    required this.sortOrder,
    required this.onlyUnuploaded,
  });

  final ActivityType? type;
  final _HistoryDateRange dateRange;
  final _HistorySortOrder sortOrder;
  final bool onlyUnuploaded;
}

class _HistoryFilterBottomSheet extends StatefulWidget {
  const _HistoryFilterBottomSheet({
    required this.selectedType,
    required this.selectedDateRange,
    required this.selectedSortOrder,
    required this.onlyUnuploaded,
  });

  final ActivityType? selectedType;
  final _HistoryDateRange selectedDateRange;
  final _HistorySortOrder selectedSortOrder;
  final bool onlyUnuploaded;

  @override
  State<_HistoryFilterBottomSheet> createState() =>
      _HistoryFilterBottomSheetState();
}

class _HistoryFilterBottomSheetState extends State<_HistoryFilterBottomSheet> {
  late ActivityType? _type = widget.selectedType;
  late _HistoryDateRange _range = widget.selectedDateRange;
  late _HistorySortOrder _sortOrder = widget.selectedSortOrder;
  late bool _onlyUnuploaded = widget.onlyUnuploaded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l10n.historyFilterAll),
                    selected: _type == null,
                    onSelected: (_) => setState(() => _type = null),
                  ),
                  ChoiceChip(
                    label: Text(l10n.activityTypeRun),
                    selected: _type == ActivityType.run,
                    onSelected: (_) => setState(() => _type = ActivityType.run),
                  ),
                  ChoiceChip(
                    label: Text(l10n.activityTypeRide),
                    selected: _type == ActivityType.ride,
                    onSelected: (_) =>
                        setState(() => _type = ActivityType.ride),
                  ),
                  ChoiceChip(
                    label: Text(l10n.activityTypeWalk),
                    selected: _type == ActivityType.walk,
                    onSelected: (_) =>
                        setState(() => _type = ActivityType.walk),
                  ),
                ],
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
                    onSelected: (_) =>
                        setState(() => _range = _HistoryDateRange.last7Days),
                  ),
                  ChoiceChip(
                    label: Text(l10n.historyRange30d),
                    selected: _range == _HistoryDateRange.last30Days,
                    onSelected: (_) =>
                        setState(() => _range = _HistoryDateRange.last30Days),
                  ),
                  ChoiceChip(
                    label: Text(l10n.historyRange90d),
                    selected: _range == _HistoryDateRange.last90Days,
                    onSelected: (_) =>
                        setState(() => _range = _HistoryDateRange.last90Days),
                  ),
                  ChoiceChip(
                    label: Text(l10n.historyRange1y),
                    selected: _range == _HistoryDateRange.last365Days,
                    onSelected: (_) =>
                        setState(() => _range = _HistoryDateRange.last365Days),
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
                    onSelected: (_) =>
                        setState(() => _sortOrder = _HistorySortOrder.newest),
                  ),
                  ChoiceChip(
                    label: Text(l10n.historySortOldest),
                    selected: _sortOrder == _HistorySortOrder.oldest,
                    onSelected: (_) =>
                        setState(() => _sortOrder = _HistorySortOrder.oldest),
                  ),
                  ChoiceChip(
                    label: Text(l10n.historySortLongest),
                    selected: _sortOrder == _HistorySortOrder.longest,
                    onSelected: (_) =>
                        setState(() => _sortOrder = _HistorySortOrder.longest),
                  ),
                  ChoiceChip(
                    label: Text(l10n.historySortShortest),
                    selected: _sortOrder == _HistorySortOrder.shortest,
                    onSelected: (_) =>
                        setState(() => _sortOrder = _HistorySortOrder.shortest),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _onlyUnuploaded,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) => setState(() => _onlyUnuploaded = value),
                title: Text(l10n.historyOnlyUnuploaded),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      _HistoryFilterSelection(
                        type: _type,
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
        ),
      ),
    );
  }
}

class _RouteOverviewScreen extends StatelessWidget {
  const _RouteOverviewScreen({
    required this.activity,
    required this.useMatchedTrack,
  });

  final Activity activity;
  final bool useMatchedTrack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final compact = MediaQuery.sizeOf(context).width < 380;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyDetailTitle)),
      body: ListView(
        padding: EdgeInsets.all(compact ? 12 : 16),
        children: [
          _ActivityRouteMap(
            points: activity.trackPoints,
            interactive: true,
            height: compact ? 280 : 340,
            useMatchedTrack: useMatchedTrack,
            activityType: activity.activityType,
          ),
          const SizedBox(height: 12),
          _AdaptiveMetricGrid(
            compact: compact,
            children: [
              _MetricTile(
                icon: Icons.timer_outlined,
                label: l10n.trackingDuration,
                value: _formatDurationLabeled(activity.durationSeconds),
                compact: compact,
              ),
              _MetricTile(
                icon: Icons.straighten,
                label: l10n.trackingDistance,
                value:
                    '${(activity.distanceMeters / 1000).toStringAsFixed(2)} ${l10n.trackingDistanceUnitKm}',
                compact: compact,
              ),
              _MetricTile(
                icon: Icons.north_east_rounded,
                label: l10n.trackingElevationGain,
                value:
                    '${activity.elevationGainMeters.toStringAsFixed(0)} ${l10n.trackingElevationUnitM}',
                compact: compact,
              ),
              _MetricTile(
                icon: Icons.south_east_rounded,
                label: l10n.historyElevationLoss,
                value:
                    '${activity.elevationLossMeters.toStringAsFixed(0)} ${l10n.trackingElevationUnitM}',
                compact: compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ElevationProfileCard(points: activity.trackPoints, compact: compact),
        ],
      ),
    );
  }
}

class _ElevationProfileCard extends StatelessWidget {
  const _ElevationProfileCard({required this.points, required this.compact});

  final List<TrackPoint> points;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final altitudes = points
        .map((point) => point.altitudeMeters)
        .whereType<double>()
        .toList();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.show_chart_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.historyElevationProfile,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 13 : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 10),
            if (altitudes.length < 2)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.historyNoAltitudeData,
                  ),
                ),
              )
            else
              SizedBox(
                height: 140,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ElevationProfilePainter(
                    altitudes: altitudes,
                    lineColor: Theme.of(context).colorScheme.primary,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.14),
                    gridColor: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.22),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ElevationProfilePainter extends CustomPainter {
  const _ElevationProfilePainter({
    required this.altitudes,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  final List<double> altitudes;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (altitudes.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }
    final min = altitudes.reduce((a, b) => a < b ? a : b);
    final max = altitudes.reduce((a, b) => a > b ? a : b);
    final span = (max - min).abs() < 0.0001 ? 1.0 : (max - min);
    final stepX = size.width / (altitudes.length - 1);

    final linePath = Path();
    for (var i = 0; i < altitudes.length; i++) {
      final x = stepX * i;
      final normalized = (altitudes[i] - min) / span;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ElevationProfilePainter oldDelegate) {
    return oldDelegate.altitudes != altitudes ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _ActivityRouteMap extends StatefulWidget {
  const _ActivityRouteMap({
    required this.points,
    required this.interactive,
    required this.height,
    required this.useMatchedTrack,
    required this.activityType,
    this.onTap,
  });

  static const _mapMatchingPreviewService = MapMatchingPreviewService();

  final List<TrackPoint> points;
  final bool interactive;
  final double height;
  final bool useMatchedTrack;
  final ActivityType activityType;
  final VoidCallback? onTap;

  @override
  State<_ActivityRouteMap> createState() => _ActivityRouteMapState();
}

class _ActivityRouteMapState extends State<_ActivityRouteMap> {
  List<TrackPoint>? _displayPoints;
  RouteMatchSource _routeSource = RouteMatchSource.raw;

  @override
  void initState() {
    super.initState();
    _resolveDisplayPoints();
  }

  @override
  void didUpdateWidget(covariant _ActivityRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pointsChanged = oldWidget.points != widget.points;
    final modeChanged = oldWidget.useMatchedTrack != widget.useMatchedTrack;
    final typeChanged = oldWidget.activityType != widget.activityType;
    if (pointsChanged || modeChanged || typeChanged) {
      _resolveDisplayPoints();
    }
  }

  Future<void> _resolveDisplayPoints() async {
    final result =
        await _ActivityRouteMap._mapMatchingPreviewService.resolveRouteDisplayAsync(
      rawPoints: widget.points,
      useMatchedPreview: widget.useMatchedTrack,
      activityType: widget.activityType,
    );
    if (!mounted) return;
    setState(() {
      _displayPoints = result.points;
      _routeSource = result.source;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayPoints =
        _displayPoints ??
        _ActivityRouteMap._mapMatchingPreviewService.pointsForDisplay(
          rawPoints: widget.points,
          useMatchedPreview: widget.useMatchedTrack,
        );
    if (displayPoints.length < 2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: widget.height,
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          alignment: Alignment.center,
          child: const Icon(Icons.route),
        ),
      );
    }
    final latLngPoints = displayPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    final center = latLngPoints[latLngPoints.length ~/ 2];
    final routeOutline = Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.92);
    const routeAccent = Color(0xFFFF5A1F);
    final map = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: widget.interactive ? 11.5 : 10.8,
            interactionOptions: InteractionOptions(
              flags: widget.interactive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: MapConstants.defaultTileServerUrl,
              userAgentPackageName: MapConstants.userAgent,
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: latLngPoints,
                  strokeWidth: 8,
                  color: routeOutline,
                ),
                Polyline(
                  points: latLngPoints,
                  strokeWidth: 4,
                  color: routeAccent,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  width: 24,
                  height: 24,
                  point: latLngPoints.first,
                  child: _RoutePointBadge(
                    label: 'A',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Marker(
                  width: 24,
                  height: 24,
                  point: latLngPoints.last,
                  child: _RoutePointBadge(
                    label: 'B',
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final statusText = switch (_routeSource) {
      RouteMatchSource.matched =>
        AppLocalizations.of(context)!.routeStatusMatched,
      RouteMatchSource.fallback =>
        AppLocalizations.of(context)!.routeStatusFallback,
      RouteMatchSource.raw => AppLocalizations.of(context)!.routeStatusRaw,
    };
    return Stack(
      children: [
        map,
        Positioned(
          top: 8,
          right: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                statusText,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        if (widget.onTap != null)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(onTap: widget.onTap),
            ),
          ),
      ],
    );
  }
}

class _RoutePointBadge extends StatelessWidget {
  const _RoutePointBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
