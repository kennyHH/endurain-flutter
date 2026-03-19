import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/utils/metric_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MetricFormatter.serverCompatiblePaceSecondsPerKm', () {
    test('nutzt Track-Geometrie statt nur distanceMeters fuer Pace', () {
      final start = DateTime.parse('2026-03-19T11:22:00Z');
      final activity = Activity(
        id: 'run-pace-parity',
        activityType: ActivityType.run,
        startedAt: start,
        endedAt: start.add(const Duration(seconds: 67)),
        distanceMeters: 78.4,
        trackPoints: [
          TrackPoint(
            latitude: 51.2836584,
            longitude: 12.7632926,
            timestamp: start,
          ),
          TrackPoint(
            latitude: 51.2843810,
            longitude: 12.7632926,
            timestamp: start.add(const Duration(seconds: 67)),
          ),
        ],
      );

      final directPace = activity.averagePaceSecondsPerKm!;
      final serverCompatible = MetricFormatter.serverCompatiblePaceSecondsPerKm(
        activity,
      )!;

      expect(serverCompatible, lessThan(directPace));
      expect(serverCompatible, closeTo(834, 10));
    });

    test('faellt ohne Trackpunkte auf distanceMeters zurueck', () {
      final start = DateTime.parse('2026-03-19T11:22:00Z');
      final activity = Activity(
        id: 'run-distance-fallback',
        activityType: ActivityType.run,
        startedAt: start,
        endedAt: start.add(const Duration(seconds: 67)),
        distanceMeters: 80.0,
        trackPoints: const [],
      );

      final result = MetricFormatter.serverCompatiblePaceSecondsPerKm(activity);

      expect(result, closeTo(activity.averagePaceSecondsPerKm!, 0.001));
    });
  });
}
