import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:endurain/core/services/gpx_exporter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/utils/metric_formatter.dart';
import 'package:endurain/features/history/widgets/activity_route_map.dart';
import 'package:endurain/features/history/widgets/history_metric_widgets.dart';
import 'package:endurain/features/history/widgets/activity_charts.dart';

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

  Future<void> _shareActivity(BuildContext context) async {
    try {
      final exporter = GpxExporter();
      final gpxString = exporter.export(activity);
      final filename = exporter.buildExportFilename(activity);
      final typeStr = activity.activityType.name;

      final xFile = XFile.fromData(
        Uint8List.fromList(utf8.encode(gpxString)),
        mimeType: 'application/gpx+xml',
        name: filename,
        lastModified: DateTime.now(),
      );

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [xFile],
        subject: 'Endurain Activity: ${activity.name ?? typeStr}',
        text: 'Check out my activity on Endurain!',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export GPX: $e')));
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
    final avgHeartRate = activity.averageHeartRateBpm;
    final avgCadence = activity.averageCadenceRpm;
    final avgHeartRateText = avgHeartRate == null
        ? null
        : '${avgHeartRate.round()} bpm';
    final avgCadenceText = avgCadence == null
        ? null
        : '${avgCadence.round()} rpm';
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
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export GPX',
            onPressed: () => _shareActivity(context),
          ),

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
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ActivityRouteMap(
                  points: activity.trackPoints,
                  interactive: true,
                  height: compact ? 274 : 330,
                  useMatchedTrack: useMatchedTrack,
                  activityType: activity.activityType,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 10 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AdaptiveMetricGrid(
                          compact: compact,
                          children: [
                            MetricTile(
                              icon: activityIcon,
                              label: l10n.activityTypeLabel,
                              value: type,
                              compact: compact,
                            ),
                            MetricTile(
                              icon: Icons.timer_outlined,
                              label: l10n.trackingDuration,
                              value: duration,
                              compact: compact,
                            ),
                            MetricTile(
                              icon: Icons.straighten,
                              label: l10n.trackingDistance,
                              value: distance,
                              compact: compact,
                            ),
                            MetricTile(
                              icon: Icons.speed,
                              label: movementMetric.label,
                              value: movementMetric.value,
                              compact: compact,
                            ),
                            MetricTile(
                              icon: Icons.north_east_rounded,
                              label: l10n.trackingElevationGain,
                              value: elevationGain,
                              compact: compact,
                            ),
                            MetricTile(
                              icon: Icons.south_east_rounded,
                              label: l10n.historyElevationLoss,
                              value: elevationLoss,
                              compact: compact,
                            ),
                            if (avgHeartRateText != null)
                              MetricTile(
                                icon: Icons.favorite_outline,
                                label: l10n.historyHeartRate,
                                value: avgHeartRateText,
                                compact: compact,
                              ),
                            if (avgCadenceText != null)
                              MetricTile(
                                icon: Icons.pedal_bike_outlined,
                                label: 'Cadence',
                                value: avgCadenceText,
                                compact: compact,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ActivityCharts(activity: activity),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: (onRetryUpload != null && !activity.uploaded)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  key: const Key('history-retry-upload-button'),
                  onPressed: onRetryUpload,
                  icon: const Icon(Icons.cloud_upload),
                  label: Text('${l10n.retry} Upload'),
                ),
              ),
            )
          : null,
    );
  }
}

class _MovementMetric {
  const _MovementMetric({required this.label, required this.value});

  final String label;
  final String value;
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
