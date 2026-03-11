import 'package:endurain/core/models/activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Activity model', () {
    test('toJson/fromJson roundtrip bleibt konsistent', () {
      final activity = Activity(
        id: 'a1',
        name: 'Morning run',
        activityType: ActivityType.run,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:15:00Z'),
        distanceMeters: 3123.4,
        trackPoints: [
          TrackPoint(
            latitude: 38.72,
            longitude: -9.13,
            timestamp: DateTime(2026, 3, 9, 10, 0, 0),
            altitudeMeters: 100,
          ),
          TrackPoint(
            latitude: 38.73,
            longitude: -9.12,
            timestamp: DateTime(2026, 3, 9, 10, 5, 0),
            altitudeMeters: 110,
          ),
        ],
      );

      final decoded = Activity.fromJson(activity.toJson());

      expect(decoded.id, equals('a1'));
      expect(decoded.name, equals('Morning run'));
      expect(decoded.activityType, equals(ActivityType.run));
      expect(decoded.distanceMeters, closeTo(3123.4, 0.001));
      expect(decoded.trackPoints, hasLength(2));
      expect(decoded.trackPoints.first.latitude, closeTo(38.72, 0.000001));
      expect(decoded.trackPoints.first.altitudeMeters, closeTo(100, 0.001));
    });

    test('copyWith und Status-Helfer funktionieren', () {
      final activity = Activity(
        id: 'a2',
        activityType: ActivityType.walk,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: null,
        distanceMeters: 12,
        trackPoints: const [],
      );

      expect(activity.isInProgress, isTrue);
      expect(activity.isCompleted, isFalse);

      final completed = activity.copyWith(
        endedAt: DateTime.parse('2026-03-09T10:00:42Z'),
        name: 'Lunch walk',
        distanceMeters: 42,
      );

      expect(completed.isCompleted, isTrue);
      expect(completed.name, equals('Lunch walk'));
      expect(completed.durationSeconds, equals(42));
      expect(completed.distanceMeters, equals(42));
    });

    test('pace und elevation gain werden korrekt berechnet', () {
      final activity = Activity(
        id: 'a3',
        activityType: ActivityType.ride,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:10:00Z'),
        distanceMeters: 2500,
        trackPoints: [
          TrackPoint(
            latitude: 38.72,
            longitude: -9.13,
            timestamp: DateTime.parse('2026-03-09T10:00:00Z'),
            altitudeMeters: 100,
          ),
          TrackPoint(
            latitude: 38.73,
            longitude: -9.12,
            timestamp: DateTime.parse('2026-03-09T10:05:00Z'),
            altitudeMeters: 130,
          ),
          TrackPoint(
            latitude: 38.74,
            longitude: -9.11,
            timestamp: DateTime.parse('2026-03-09T10:10:00Z'),
            altitudeMeters: 120,
          ),
        ],
      );

      expect(activity.averagePaceSecondsPerKm, closeTo(240, 0.001));
      expect(activity.elevationGainMeters, closeTo(30, 0.001));
      expect(activity.elevationLossMeters, closeTo(10, 0.001));
    });

    test('ungueltige lat/lng Werte werden abgelehnt', () {
      expect(
        () => TrackPoint(
          latitude: 91,
          longitude: -9.13,
          timestamp: DateTime.parse('2026-03-09T10:00:00Z'),
        ),
        throwsArgumentError,
      );
      expect(
        () => TrackPoint(
          latitude: 38.72,
          longitude: 181,
          timestamp: DateTime.parse('2026-03-09T10:00:00Z'),
        ),
        throwsArgumentError,
      );
    });
  });
}
