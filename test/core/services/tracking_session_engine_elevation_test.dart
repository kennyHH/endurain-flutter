import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrackingSessionEngine elevation gain filter', () {
    test('ignores altitude jitter below threshold', () {
      final points = <TrackPoint>[
        TrackPoint(
          latitude: 51.0,
          longitude: 13.0,
          timestamp: DateTime.parse('2026-03-17T10:00:00Z'),
          altitudeMeters: 170.0,
        ),
        TrackPoint(
          latitude: 51.0001,
          longitude: 13.0001,
          timestamp: DateTime.parse('2026-03-17T10:00:05Z'),
          altitudeMeters: 170.8,
        ),
        TrackPoint(
          latitude: 51.0002,
          longitude: 13.0002,
          timestamp: DateTime.parse('2026-03-17T10:00:10Z'),
          altitudeMeters: 170.1,
        ),
        TrackPoint(
          latitude: 51.0003,
          longitude: 13.0003,
          timestamp: DateTime.parse('2026-03-17T10:00:15Z'),
          altitudeMeters: 170.9,
        ),
      ];

      final gain = TrackingSessionEngine.calculateElevationGainMeters(points);
      expect(gain, closeTo(0, 0.001));
    });

    test('keeps meaningful climbs above threshold', () {
      final points = <TrackPoint>[
        TrackPoint(
          latitude: 51.0,
          longitude: 13.0,
          timestamp: DateTime.parse('2026-03-17T10:00:00Z'),
          altitudeMeters: 170.0,
        ),
        TrackPoint(
          latitude: 51.0001,
          longitude: 13.0001,
          timestamp: DateTime.parse('2026-03-17T10:00:05Z'),
          altitudeMeters: 171.7,
        ),
        TrackPoint(
          latitude: 51.0002,
          longitude: 13.0002,
          timestamp: DateTime.parse('2026-03-17T10:00:10Z'),
          altitudeMeters: 173.5,
        ),
      ];

      final gain = TrackingSessionEngine.calculateElevationGainMeters(points);
      expect(gain, closeTo(3.5, 0.001));
    });
  });
}
