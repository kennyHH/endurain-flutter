import 'package:endurain/features/activity/models/activity_recording_stats.dart';
import 'package:endurain/features/activity/models/activity_track_point.dart';
import 'package:latlong2/latlong.dart';

class ActivityStatsCalculator {
  ActivityStatsCalculator({Distance? distance})
    : _distance = distance ?? const Distance();

  final Distance _distance;

  ActivityRecordingStats calculate(List<ActivityTrackPoint> points) {
    if (points.isEmpty) {
      return const ActivityRecordingStats(distanceMeters: 0, durationSeconds: 0);
    }

    var distanceMeters = 0.0;
    var durationSeconds = 0;
    double? currentSpeedMetersPerSecond;

    for (var index = 1; index < points.length; index += 1) {
      final previous = points[index - 1];
      final current = points[index];
      final pairDistanceMeters = _distance.as(
        LengthUnit.Meter,
        LatLng(previous.latitude, previous.longitude),
        LatLng(current.latitude, current.longitude),
      );
      distanceMeters += pairDistanceMeters;

      final pairDurationSeconds = current.timestamp
          .difference(previous.timestamp)
          .inSeconds;
      if (pairDurationSeconds > 0) {
        durationSeconds += pairDurationSeconds;
        if (current.speedMetersPerSecond == null) {
          currentSpeedMetersPerSecond = pairDistanceMeters / pairDurationSeconds;
        }
      }
    }

    currentSpeedMetersPerSecond =
        points.last.speedMetersPerSecond ?? currentSpeedMetersPerSecond;

    final averageSpeedMetersPerSecond = durationSeconds > 0
        ? distanceMeters / durationSeconds
        : null;

    return ActivityRecordingStats(
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      averageSpeedMetersPerSecond: averageSpeedMetersPerSecond,
      currentSpeedMetersPerSecond: currentSpeedMetersPerSecond,
    );
  }
}