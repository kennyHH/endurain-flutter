import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/utils/activity_upload_policy.dart';
import 'package:flutter_test/flutter_test.dart';

Activity _activity({
  required String id,
  required ActivityType type,
  required int durationSeconds,
  required double distanceMeters,
  required List<TrackPoint> trackPoints,
}) {
  final start = DateTime.parse('2026-03-19T11:22:00Z');
  return Activity(
    id: id,
    activityType: type,
    startedAt: start,
    endedAt: start.add(Duration(seconds: durationSeconds)),
    distanceMeters: distanceMeters,
    trackPoints: trackPoints,
  );
}

void main() {
  group('ActivityUploadPolicy', () {
    test('blockiert Aktivität mit zu wenigen Trackpunkten', () {
      final activity = _activity(
        id: 'a1',
        type: ActivityType.run,
        durationSeconds: 40,
        distanceMeters: 100,
        trackPoints: [
          TrackPoint(
            latitude: 51.0,
            longitude: 12.0,
            timestamp: DateTime.parse('2026-03-19T11:22:00Z'),
          ),
        ],
      );

      final result = ActivityUploadPolicy.evaluate(activity);

      expect(result.isUploadable, isFalse);
      expect(result.status, equals(ActivityUploadPolicyStatus.blocked));
    });

    test('blockiert sehr kurze Run Activity', () {
      final start = DateTime.parse('2026-03-19T11:22:00Z');
      final activity = _activity(
        id: 'a2',
        type: ActivityType.run,
        durationSeconds: 12,
        distanceMeters: 20,
        trackPoints: [
          TrackPoint(latitude: 51.0, longitude: 12.0, timestamp: start),
          TrackPoint(
            latitude: 51.00001,
            longitude: 12.00001,
            timestamp: start.add(const Duration(seconds: 12)),
          ),
        ],
      );

      final result = ActivityUploadPolicy.evaluate(activity);

      expect(result.isUploadable, isFalse);
    });

    test('erlaubt valide Run Activity', () {
      final start = DateTime.parse('2026-03-19T11:22:00Z');
      final activity = _activity(
        id: 'a3',
        type: ActivityType.run,
        durationSeconds: 180,
        distanceMeters: 600,
        trackPoints: [
          TrackPoint(latitude: 51.0, longitude: 12.0, timestamp: start),
          TrackPoint(
            latitude: 51.0030,
            longitude: 12.0030,
            timestamp: start.add(const Duration(seconds: 180)),
          ),
        ],
      );

      final result = ActivityUploadPolicy.evaluate(activity);

      expect(result.isUploadable, isTrue);
      expect(result.status, equals(ActivityUploadPolicyStatus.uploadable));
    });
  });
}
