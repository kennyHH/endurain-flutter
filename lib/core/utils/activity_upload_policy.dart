import 'package:endurain/core/models/activity.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;

enum ActivityUploadPolicyStatus { uploadable, warning, blocked }

class ActivityUploadPolicyResult {
  const ActivityUploadPolicyResult._({
    required this.status,
    this.message,
  });

  final ActivityUploadPolicyStatus status;
  final String? message;

  bool get isUploadable => status != ActivityUploadPolicyStatus.blocked;

  factory ActivityUploadPolicyResult.uploadable() {
    return const ActivityUploadPolicyResult._(
      status: ActivityUploadPolicyStatus.uploadable,
    );
  }

  factory ActivityUploadPolicyResult.warning(String message) {
    return ActivityUploadPolicyResult._(
      status: ActivityUploadPolicyStatus.warning,
      message: message,
    );
  }

  factory ActivityUploadPolicyResult.blocked(String message) {
    return ActivityUploadPolicyResult._(
      status: ActivityUploadPolicyStatus.blocked,
      message: message,
    );
  }
}

class ActivityUploadPolicy {
  static ActivityUploadPolicyResult evaluate(Activity activity) {
    final durationSeconds = activity.durationSeconds;
    final distanceMeters = activity.distanceMeters;
    final trackPointCount = activity.trackPoints.length;

    if (trackPointCount < 2) {
      return ActivityUploadPolicyResult.blocked(
        'Activity has too few GPS points for upload.',
      );
    }
    if (durationSeconds < 10) {
      return ActivityUploadPolicyResult.blocked(
        'Activity duration is too short for upload.',
      );
    }
    if (distanceMeters < 10) {
      return ActivityUploadPolicyResult.blocked(
        'Activity distance is too short for upload.',
      );
    }

    switch (activity.activityType) {
      case ActivityType.run:
      case ActivityType.walk:
        if (durationSeconds < 20 || distanceMeters < 25) {
          return ActivityUploadPolicyResult.blocked(
            'Run/Walk activity is too short for upload.',
          );
        }
        final pace = activity.averagePaceSecondsPerKm;
        if (distanceMeters < 100 &&
            pace != null &&
            (pace < 120 || pace > 1200)) {
          return ActivityUploadPolicyResult.warning(
            'Pace seems implausible for a short run/walk.',
          );
        }
      case ActivityType.ride:
        if (durationSeconds < 20 || distanceMeters < 40) {
          return ActivityUploadPolicyResult.blocked(
            'Ride activity is too short for upload.',
          );
        }
        final speed = activity.averageSpeedKmh;
        if (distanceMeters < 200 && speed != null && speed > 80) {
          return ActivityUploadPolicyResult.warning(
            'Speed seems implausible for a short ride.',
          );
        }
    }

    if (_isLikelyStationaryJitter(activity)) {
      return ActivityUploadPolicyResult.blocked(
        'Activity appears stationary and contains mostly GPS jitter.',
      );
    }

    return ActivityUploadPolicyResult.uploadable();
  }

  static bool _isLikelyStationaryJitter(Activity activity) {
    if (activity.trackPoints.length < 2) return false;
    if (activity.durationSeconds < 10) return false;
    if (activity.distanceMeters >= 15) return false;

    var minLat = activity.trackPoints.first.latitude;
    var maxLat = activity.trackPoints.first.latitude;
    var minLon = activity.trackPoints.first.longitude;
    var maxLon = activity.trackPoints.first.longitude;

    for (final point in activity.trackPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    final diagonalMeters = Geolocator.distanceBetween(
      minLat,
      minLon,
      maxLat,
      maxLon,
    );
    return diagonalMeters < 8;
  }
}
