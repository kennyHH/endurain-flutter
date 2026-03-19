import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'dart:math';

const _enableTrackingPhaseBDistanceConsistency = bool.fromEnvironment(
  'ENDURAIN_PHASE_B_DISTANCE_CONSISTENCY',
  defaultValue: false,
);

enum DistanceAxisUnit { meters, kilometers }

class ActivityChartDistanceFormatter {
  static DistanceAxisUnit resolveUnitForMaxDistanceKm(double maxDistanceKm) {
    return maxDistanceKm < 1.0
        ? DistanceAxisUnit.meters
        : DistanceAxisUnit.kilometers;
  }

  @visibleForTesting
  static String formatAxisLabelKm(double valueKm, DistanceAxisUnit unit) {
    if (unit == DistanceAxisUnit.meters) {
      final meters = (valueKm * 1000).round();
      return '$meters m';
    }
    if (valueKm >= 10) {
      return '${valueKm.toStringAsFixed(0)} km';
    }
    return '${valueKm.toStringAsFixed(1)} km';
  }

  @visibleForTesting
  static String formatTooltipDistanceKm(double valueKm, DistanceAxisUnit unit) {
    if (unit == DistanceAxisUnit.meters) {
      final meters = (valueKm * 1000).round();
      return '$meters m';
    }
    return '${valueKm.toStringAsFixed(2)} km';
  }
}

class ActivityCharts extends StatelessWidget {
  const ActivityCharts({
    super.key,
    required this.activity,
    this.enforcePhaseBDistanceConsistency,
  });

  final Activity activity;
  final bool? enforcePhaseBDistanceConsistency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasHeartRate = activity.trackPoints.any((p) => p.heartRate != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activity.trackPoints.isNotEmpty) ...[
          _ChartCard(
            title: l10n.historyElevationProfile,
            icon: Icons.terrain_rounded,
            child: _ElevationChart(
              points: activity.trackPoints,
              activityDistanceMeters: activity.distanceMeters,
              qualityMetrics: activity.qualityMetrics,
              enforcePhaseBDistanceConsistency:
                  enforcePhaseBDistanceConsistency ??
                  _enableTrackingPhaseBDistanceConsistency,
            ),
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: l10n.trackingPace,
            icon: Icons.speed_rounded,
            child: _PaceChart(
              points: activity.trackPoints,
              activityDistanceMeters: activity.distanceMeters,
              qualityMetrics: activity.qualityMetrics,
              enforcePhaseBDistanceConsistency:
                  enforcePhaseBDistanceConsistency ??
                  _enableTrackingPhaseBDistanceConsistency,
            ),
          ),
          if (hasHeartRate) ...[
            const SizedBox(height: 12),
            _ChartCard(
              title: l10n.historyHeartRate,
              icon: Icons.monitor_heart_rounded,
              child: _HeartRateChart(points: activity.trackPoints),
            ),
          ],
        ],
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: child),
          ],
        ),
      ),
    );
  }
}

class _ElevationChart extends StatelessWidget {
  const _ElevationChart({
    required this.points,
    required this.activityDistanceMeters,
    required this.qualityMetrics,
    required this.enforcePhaseBDistanceConsistency,
  });

  final List<TrackPoint> points;
  final double activityDistanceMeters;
  final Map<String, dynamic>? qualityMetrics;
  final bool enforcePhaseBDistanceConsistency;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox();

    final cumulativeDistanceMeters = _buildCumulativeDistanceMeters(points);
    final totalDistanceKm = _resolveChartTotalDistanceKm(
      activityDistanceMeters: activityDistanceMeters,
      cumulativeDistanceMeters: cumulativeDistanceMeters,
      qualityMetrics: qualityMetrics,
      enforcePhaseBDistanceConsistency: enforcePhaseBDistanceConsistency,
    );
    final effectiveDomainMaxX = totalDistanceKm > 0 ? totalDistanceKm : 0.001;

    final sampleSize = points.length > 500 ? points.length ~/ 500 : 1;
    final dataPoints = <FlSpot>[];
    for (var i = 0; i < points.length; i += sampleSize) {
      final altitude = points[i].altitudeMeters;
      if (altitude != null) {
        dataPoints.add(FlSpot(cumulativeDistanceMeters[i] / 1000, altitude));
      }
    }

    if (dataPoints.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.historyNoAltitudeData,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final minY = dataPoints.map((e) => e.y).reduce(min);
    final maxY = dataPoints.map((e) => e.y).reduce(max);
    final buffer = (maxY - minY) * 0.1;
    final distanceUnit =
        ActivityChartDistanceFormatter.resolveUnitForMaxDistanceKm(
          effectiveDomainMaxX,
        );

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    ActivityChartDistanceFormatter.formatAxisLabelKm(
                      value,
                      distanceUnit,
                    ),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: effectiveDomainMaxX,
        minY: minY - buffer,
        maxY: maxY + buffer,
        lineBarsData: [
          LineChartBarData(
            spots: dataPoints,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(0)} m\n${ActivityChartDistanceFormatter.formatTooltipDistanceKm(spot.x, distanceUnit)}',
                  Theme.of(context).textTheme.bodySmall!,
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

class _PaceChart extends StatelessWidget {
  const _PaceChart({
    required this.points,
    required this.activityDistanceMeters,
    required this.qualityMetrics,
    required this.enforcePhaseBDistanceConsistency,
  });

  final List<TrackPoint> points;
  final double activityDistanceMeters;
  final Map<String, dynamic>? qualityMetrics;
  final bool enforcePhaseBDistanceConsistency;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox();

    final cumulativeDistanceMeters = _buildCumulativeDistanceMeters(points);
    final totalDistanceKm = _resolveChartTotalDistanceKm(
      activityDistanceMeters: activityDistanceMeters,
      cumulativeDistanceMeters: cumulativeDistanceMeters,
      qualityMetrics: qualityMetrics,
      enforcePhaseBDistanceConsistency: enforcePhaseBDistanceConsistency,
    );
    final effectiveDomainMaxX = totalDistanceKm > 0 ? totalDistanceKm : 0.001;

    final dataPoints = <FlSpot>[];

    final windowSize = _resolvePaceWindowSize(
      totalDistanceKm: effectiveDomainMaxX,
      pointsLength: points.length,
    );

    final startIndex = effectiveDomainMaxX <= 0.2 ? 1 : windowSize;
    for (var i = startIndex; i < points.length; i++) {
      final lookback = effectiveDomainMaxX <= 0.2
          ? (i < windowSize ? i : windowSize)
          : windowSize;
      final p1 = points[i - lookback];
      final p2 = points[i];

      final dist = _calculateDistance(p1, p2);
      final time = p2.timestamp.difference(p1.timestamp).inSeconds;

      if (dist > 0 && time > 0) {
        final paceMinPerKm = (time / 60) / (dist / 1000);

        if (paceMinPerKm > 0 && paceMinPerKm < 30) {
          dataPoints.add(
            FlSpot(cumulativeDistanceMeters[i] / 1000, paceMinPerKm),
          );
        }
      }
    }

    final displayPoints = <FlSpot>[];
    final sampleSize = dataPoints.length > 300 ? dataPoints.length ~/ 300 : 1;
    for (var i = 0; i < dataPoints.length; i += sampleSize) {
      displayPoints.add(dataPoints[i]);
    }

    if (displayPoints.isEmpty) {
      return Center(
        child: Text(
          'Not enough data for pace chart',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final minY = displayPoints.map((e) => e.y).reduce(min);
    final maxY = displayPoints.map((e) => e.y).reduce(max);
    final distanceUnit =
        ActivityChartDistanceFormatter.resolveUnitForMaxDistanceKm(
          effectiveDomainMaxX,
        );

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    ActivityChartDistanceFormatter.formatAxisLabelKm(
                      value,
                      distanceUnit,
                    ),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatPace(value),
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: effectiveDomainMaxX,
        minY: max(0, minY - 1),
        maxY: maxY + 1,
        lineBarsData: [
          LineChartBarData(
            spots: displayPoints,
            isCurved: true,
            color: Theme.of(context).colorScheme.secondary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${_formatPace(spot.y)} /km\n${ActivityChartDistanceFormatter.formatTooltipDistanceKm(spot.x, distanceUnit)}',
                  Theme.of(context).textTheme.bodySmall!,
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  String _formatPace(double paceMinPerKm) {
    final int minutes = paceMinPerKm.floor();
    final int seconds = ((paceMinPerKm - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

int _resolvePaceWindowSize({
  required double totalDistanceKm,
  required int pointsLength,
}) {
  final maxAllowed = max(2, pointsLength - 1);
  if (totalDistanceKm <= 0.15) return min(2, maxAllowed);
  if (totalDistanceKm <= 0.3) return min(3, maxAllowed);
  if (totalDistanceKm <= 0.6) return min(4, maxAllowed);
  return min(5, maxAllowed);
}

List<double> _buildCumulativeDistanceMeters(List<TrackPoint> points) {
  if (points.isEmpty) return const <double>[];
  final values = List<double>.filled(points.length, 0);
  double cumulative = 0;
  for (var i = 1; i < points.length; i++) {
    cumulative += _calculateDistance(points[i - 1], points[i]);
    values[i] = cumulative;
  }
  return values;
}

double _resolveChartTotalDistanceKm({
  required double activityDistanceMeters,
  required List<double> cumulativeDistanceMeters,
  required Map<String, dynamic>? qualityMetrics,
  required bool enforcePhaseBDistanceConsistency,
}) {
  if (enforcePhaseBDistanceConsistency) {
    final acceptedTrackDistanceMeters = _asPositiveDouble(
      qualityMetrics?['accepted_track_distance_meters'],
    );
    if (acceptedTrackDistanceMeters != null) {
      return acceptedTrackDistanceMeters / 1000;
    }
  }
  final recordedKm = activityDistanceMeters > 0
      ? activityDistanceMeters / 1000
      : 0.0;
  final computedKm = cumulativeDistanceMeters.isNotEmpty
      ? cumulativeDistanceMeters.last / 1000
      : 0.0;
  if (recordedKm > 0) return recordedKm;
  return computedKm;
}

double? _asPositiveDouble(Object? value) {
  if (value is num) {
    final parsed = value.toDouble();
    if (parsed.isFinite && parsed > 0) return parsed;
  }
  return null;
}

class _HeartRateChart extends StatelessWidget {
  const _HeartRateChart({required this.points});

  final List<TrackPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox();

    // Filter points with HR data
    final hrPoints = points.where((p) => p.heartRate != null).toList();

    if (hrPoints.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.historyNoHeartRateData,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    // Downsample points for performance
    final sampleSize = hrPoints.length > 500 ? hrPoints.length ~/ 500 : 1;
    final dataPoints = <FlSpot>[];

    // We need to calculate distance relative to the FULL set of points to be accurate,
    // but since we only care about HR points, we can approximate or recalculate.
    // For simplicity, let's just use index/time or recalculate distance if needed.
    // Let's stick to distance for consistency with other charts.

    double currentDistance = 0;
    // Map full points to distance
    final pointDistances = <int, double>{}; // index -> cumulative distance
    double d = 0;
    for (int i = 1; i < points.length; i++) {
      d += _calculateDistance(points[i - 1], points[i]);
      pointDistances[i] = d;
    }
    pointDistances[0] = 0;

    for (var i = 0; i < hrPoints.length; i += sampleSize) {
      final p = hrPoints[i];
      // Find original index to get distance? Too slow.
      // Let's just assume hrPoints are sequential and recalculate distance between them
      // This is an approximation if we skipped points without HR.
      if (i > 0) {
        currentDistance += _calculateDistance(hrPoints[i - sampleSize], p);
      }

      dataPoints.add(FlSpot(currentDistance / 1000, p.heartRate!.toDouble()));
    }

    final minY = dataPoints.map((e) => e.y).reduce(min);
    final maxY = dataPoints.map((e) => e.y).reduce(max);
    final buffer = (maxY - minY) * 0.1;
    final distanceUnit =
        ActivityChartDistanceFormatter.resolveUnitForMaxDistanceKm(
          dataPoints.last.x,
        );

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    ActivityChartDistanceFormatter.formatAxisLabelKm(
                      value,
                      distanceUnit,
                    ),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: dataPoints.first.x,
        maxX: dataPoints.last.x,
        minY: max(0, minY - buffer),
        maxY: maxY + buffer,
        lineBarsData: [
          LineChartBarData(
            spots: dataPoints,
            isCurved: true,
            color: Colors.redAccent,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.redAccent.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(0)} bpm\n${ActivityChartDistanceFormatter.formatTooltipDistanceKm(spot.x, distanceUnit)}',
                  Theme.of(context).textTheme.bodySmall!,
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

// Shared helper function
double _calculateDistance(TrackPoint p1, TrackPoint p2) {
  const p = 0.017453292519943295;
  final a =
      0.5 -
      cos((p2.latitude - p1.latitude) * p) / 2 +
      cos(p1.latitude * p) *
          cos(p2.latitude * p) *
          (1 - cos((p2.longitude - p1.longitude) * p)) /
          2;
  return 12742 * asin(sqrt(a)) * 1000;
}
