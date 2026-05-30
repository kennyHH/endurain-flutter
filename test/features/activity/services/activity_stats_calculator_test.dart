import 'package:endurain/features/activity/models/activity_track_point.dart';
import 'package:endurain/features/activity/services/activity_stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityStatsCalculator', () {
    final calculator = ActivityStatsCalculator();

    test('returns zero stats for zero points', () {
      final stats = calculator.calculate([]);

      expect(stats.distanceMeters, 0);
      expect(stats.durationSeconds, 0);
      expect(stats.averageSpeedMetersPerSecond, isNull);
      expect(stats.currentSpeedMetersPerSecond, isNull);
    });

    test('returns zero stats for one point', () {
      final stats = calculator.calculate([_point(latitude: 0, longitude: 0)]);

      expect(stats.distanceMeters, 0);
      expect(stats.durationSeconds, 0);
      expect(stats.averageSpeedMetersPerSecond, isNull);
      expect(stats.currentSpeedMetersPerSecond, isNull);
    });

    test('handles duplicate points', () {
      final stats = calculator.calculate([
        _point(latitude: 41, longitude: -8, seconds: 0),
        _point(latitude: 41, longitude: -8, seconds: 60),
      ]);

      expect(stats.distanceMeters, 0);
      expect(stats.durationSeconds, 60);
      expect(stats.averageSpeedMetersPerSecond, 0);
      expect(stats.currentSpeedMetersPerSecond, 0);
    });

    test('calculates distance duration and speed for multiple points', () {
      final stats = calculator.calculate([
        _point(latitude: 0, longitude: 0, seconds: 0),
        _point(latitude: 0, longitude: 0.001, seconds: 60),
        _point(latitude: 0, longitude: 0.002, seconds: 120, speed: 2.5),
      ]);

      expect(stats.distanceMeters, closeTo(222, 0.5));
      expect(stats.durationSeconds, 120);
      expect(stats.averageSpeedMetersPerSecond, closeTo(1.85, 0.01));
      expect(stats.currentSpeedMetersPerSecond, 2.5);
    });

    test('ignores non-monotonic timestamp pairs for duration', () {
      final stats = calculator.calculate([
        _point(latitude: 0, longitude: 0, seconds: 60),
        _point(latitude: 0, longitude: 0.001, seconds: 30),
        _point(latitude: 0, longitude: 0.002, seconds: 90),
      ]);

      expect(stats.distanceMeters, closeTo(222, 0.5));
      expect(stats.durationSeconds, 60);
      expect(stats.averageSpeedMetersPerSecond, closeTo(3.7, 0.01));
    });
  });
}

ActivityTrackPoint _point({
  required double latitude,
  required double longitude,
  int seconds = 0,
  double? speed,
}) {
  return ActivityTrackPoint(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.utc(2026).add(Duration(seconds: seconds)),
    speedMetersPerSecond: speed,
  );
}
