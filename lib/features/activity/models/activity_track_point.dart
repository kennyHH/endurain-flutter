import 'package:geolocator/geolocator.dart';

class ActivityTrackPoint {
  const ActivityTrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.elevationMeters,
    this.speedMetersPerSecond,
    this.headingDegrees,
    this.horizontalAccuracyMeters,
    this.verticalAccuracyMeters,
    this.speedAccuracyMetersPerSecond,
    this.headingAccuracyDegrees,
  }) : assert(latitude >= -90 && latitude <= 90),
       assert(longitude >= -180 && longitude <= 180);

  factory ActivityTrackPoint.fromPosition(Position position) {
    return ActivityTrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      elevationMeters: _finiteOrNull(position.altitude),
      speedMetersPerSecond: _nonNegativeOrNull(position.speed),
      headingDegrees: _headingOrNull(position.heading),
      horizontalAccuracyMeters: _nonNegativeOrNull(position.accuracy),
      verticalAccuracyMeters: _nonNegativeOrNull(position.altitudeAccuracy),
      speedAccuracyMetersPerSecond: _nonNegativeOrNull(position.speedAccuracy),
      headingAccuracyDegrees: _nonNegativeOrNull(position.headingAccuracy),
    );
  }

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? elevationMeters;
  final double? speedMetersPerSecond;
  final double? headingDegrees;
  final double? horizontalAccuracyMeters;
  final double? verticalAccuracyMeters;
  final double? speedAccuracyMetersPerSecond;
  final double? headingAccuracyDegrees;

  static double? _finiteOrNull(double value) {
    return value.isFinite ? value : null;
  }

  static double? _nonNegativeOrNull(double value) {
    return value.isFinite && !value.isNegative ? value : null;
  }

  static double? _headingOrNull(double value) {
    if (!value.isFinite || value.isNegative) {
      return null;
    }
    return value.remainder(360);
  }
}