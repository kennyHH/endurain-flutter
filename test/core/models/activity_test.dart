import 'package:endurain/core/models/activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Activity model', () {
    test('toJson/fromJson roundtrip bleibt konsistent', () {
      final activity = Activity(
        id: 'a1',
        name: 'Morning run',
        activityType: ActivityType.run,
        activityTypeId: 2,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:15:00Z'),
        distanceMeters: 3123.4,
        trackPoints: [
          TrackPoint(
            latitude: 38.72,
            longitude: -9.13,
            timestamp: DateTime(2026, 3, 9, 10, 0, 0),
            altitudeMeters: 100,
            heartRate: 148,
            cadence: 84,
          ),
          TrackPoint(
            latitude: 38.73,
            longitude: -9.12,
            timestamp: DateTime(2026, 3, 9, 10, 5, 0),
            altitudeMeters: 110,
            heartRate: 152,
            cadence: 86,
          ),
        ],
      );

      final decoded = Activity.fromJson(activity.toJson());

      expect(decoded.id, equals('a1'));
      expect(decoded.name, equals('Morning run'));
      expect(decoded.activityType, equals(ActivityType.run));
      expect(decoded.activityTypeId, equals(2));
      expect(decoded.distanceMeters, closeTo(3123.4, 0.001));
      expect(decoded.trackPoints, hasLength(2));
      expect(decoded.trackPoints.first.latitude, closeTo(38.72, 0.000001));
      expect(decoded.trackPoints.first.altitudeMeters, closeTo(100, 0.001));
      expect(decoded.trackPoints.first.heartRate, equals(148));
      expect(decoded.trackPoints.first.cadence, equals(84));
    });

    test('copyWith und Status-Helfer funktionieren', () {
      final activity = Activity(
        id: 'a2',
        activityType: ActivityType.walk,
        activityTypeId: 30,
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
        activityTypeId: 33,
      );

      expect(completed.isCompleted, isTrue);
      expect(completed.name, equals('Lunch walk'));
      expect(completed.activityTypeId, equals(33));
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

    test('elevation noise unterhalb Schwellwert wird ignoriert', () {
      final activity = Activity(
        id: 'a4',
        activityType: ActivityType.run,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:01:00Z'),
        distanceMeters: 120,
        trackPoints: [
          TrackPoint(
            latitude: 38.72,
            longitude: -9.13,
            timestamp: DateTime.parse('2026-03-09T10:00:00Z'),
            altitudeMeters: 170.0,
          ),
          TrackPoint(
            latitude: 38.7201,
            longitude: -9.1299,
            timestamp: DateTime.parse('2026-03-09T10:00:10Z'),
            altitudeMeters: 170.9,
          ),
          TrackPoint(
            latitude: 38.7202,
            longitude: -9.1298,
            timestamp: DateTime.parse('2026-03-09T10:00:20Z'),
            altitudeMeters: 170.1,
          ),
          TrackPoint(
            latitude: 38.7203,
            longitude: -9.1297,
            timestamp: DateTime.parse('2026-03-09T10:00:30Z'),
            altitudeMeters: 171.0,
          ),
          TrackPoint(
            latitude: 38.7204,
            longitude: -9.1296,
            timestamp: DateTime.parse('2026-03-09T10:00:40Z'),
            altitudeMeters: 170.2,
          ),
        ],
      );

      expect(activity.elevationGainMeters, closeTo(0, 0.001));
      expect(activity.elevationLossMeters, closeTo(0, 0.001));
    });

    test('echte vertikale Bewegung bleibt erhalten', () {
      final activity = Activity(
        id: 'a5',
        activityType: ActivityType.run,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:02:00Z'),
        distanceMeters: 300,
        trackPoints: [
          TrackPoint(
            latitude: 38.72,
            longitude: -9.13,
            timestamp: DateTime.parse('2026-03-09T10:00:00Z'),
            altitudeMeters: 170.0,
          ),
          TrackPoint(
            latitude: 38.7203,
            longitude: -9.1297,
            timestamp: DateTime.parse('2026-03-09T10:00:30Z'),
            altitudeMeters: 172.0,
          ),
          TrackPoint(
            latitude: 38.7206,
            longitude: -9.1294,
            timestamp: DateTime.parse('2026-03-09T10:01:00Z'),
            altitudeMeters: 174.0,
          ),
          TrackPoint(
            latitude: 38.7209,
            longitude: -9.1291,
            timestamp: DateTime.parse('2026-03-09T10:01:30Z'),
            altitudeMeters: 172.2,
          ),
        ],
      );

      expect(activity.elevationGainMeters, closeTo(4.0, 0.001));
      expect(activity.elevationLossMeters, closeTo(1.8, 0.001));
    });

    test(
      'nutzt Quality-Metrics-Fallback fuer elevation gain ohne Trackpunkte',
      () {
        final activity = Activity(
          id: 'a6',
          activityType: ActivityType.run,
          startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
          endedAt: DateTime.parse('2026-03-09T11:11:36Z'),
          distanceMeters: 11420,
          trackPoints: const [],
          qualityMetrics: const <String, dynamic>{
            'filtered_elevation_gain_meters': 436,
          },
        );

        expect(activity.elevationGainMeters, closeTo(436, 0.001));
      },
    );

    test('durchschnittliche Herzfrequenz und Cadence werden berechnet', () {
      final activity = Activity(
        id: 'a7',
        activityType: ActivityType.run,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:30:00Z'),
        distanceMeters: 6000,
        trackPoints: [
          TrackPoint(
            latitude: 38.72,
            longitude: -9.13,
            timestamp: DateTime.parse('2026-03-09T10:00:00Z'),
            heartRate: 150,
            cadence: 82,
          ),
          TrackPoint(
            latitude: 38.73,
            longitude: -9.12,
            timestamp: DateTime.parse('2026-03-09T10:15:00Z'),
            heartRate: 154,
            cadence: 86,
          ),
        ],
      );

      expect(activity.averageHeartRateBpm, closeTo(152, 0.001));
      expect(activity.averageCadenceRpm, closeTo(84, 0.001));
    });

    test(
      'nutzt Quality-Metrics-Fallback fuer HR und Cadence ohne Trackpunkte',
      () {
        final activity = Activity(
          id: 'a8',
          activityType: ActivityType.ride,
          startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
          endedAt: DateTime.parse('2026-03-09T10:30:00Z'),
          distanceMeters: 12000,
          trackPoints: const [],
          qualityMetrics: const <String, dynamic>{
            'avg_heart_rate_bpm': 141.0,
            'avg_cadence_rpm': 89.0,
          },
        );

        expect(activity.averageHeartRateBpm, closeTo(141, 0.001));
        expect(activity.averageCadenceRpm, closeTo(89, 0.001));
      },
    );

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
