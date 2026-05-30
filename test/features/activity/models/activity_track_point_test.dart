import 'package:endurain/features/activity/models/activity_track_point.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  group('ActivityTrackPoint', () {
    test('converts representative position data', () {
      final timestamp = DateTime.utc(2026, 5, 30, 12);
      final position = _position(
        latitude: 41.1579,
        longitude: -8.6291,
        timestamp: timestamp,
        altitude: 93,
        speed: 3.4,
        heading: 181,
        accuracy: 4.2,
        altitudeAccuracy: 1.5,
        speedAccuracy: 0.3,
        headingAccuracy: 2.1,
      );

      final point = ActivityTrackPoint.fromPosition(position);

      expect(point.latitude, 41.1579);
      expect(point.longitude, -8.6291);
      expect(point.timestamp, timestamp);
      expect(point.elevationMeters, 93);
      expect(point.speedMetersPerSecond, 3.4);
      expect(point.headingDegrees, 181);
      expect(point.horizontalAccuracyMeters, 4.2);
      expect(point.verticalAccuracyMeters, 1.5);
      expect(point.speedAccuracyMetersPerSecond, 0.3);
      expect(point.headingAccuracyDegrees, 2.1);
    });

    test('drops invalid optional values safely', () {
      final point = ActivityTrackPoint.fromPosition(
        _position(
          altitude: double.nan,
          speed: -1,
          heading: -1,
          accuracy: -1,
          altitudeAccuracy: -1,
          speedAccuracy: -1,
          headingAccuracy: -1,
        ),
      );

      expect(point.elevationMeters, isNull);
      expect(point.speedMetersPerSecond, isNull);
      expect(point.headingDegrees, isNull);
      expect(point.horizontalAccuracyMeters, isNull);
      expect(point.verticalAccuracyMeters, isNull);
      expect(point.speedAccuracyMetersPerSecond, isNull);
      expect(point.headingAccuracyDegrees, isNull);
    });
  });
}

Position _position({
  double latitude = 41,
  double longitude = -8,
  DateTime? timestamp,
  double altitude = 10,
  double speed = 3,
  double heading = 90,
  double accuracy = 5,
  double altitudeAccuracy = 1,
  double speedAccuracy = 1,
  double headingAccuracy = 1,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.utc(2026),
    accuracy: accuracy,
    altitude: altitude,
    altitudeAccuracy: altitudeAccuracy,
    heading: heading,
    headingAccuracy: headingAccuracy,
    speed: speed,
    speedAccuracy: speedAccuracy,
  );
}
