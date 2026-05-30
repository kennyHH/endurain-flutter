import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_track_point.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityRecordingState', () {
    test('copyWith updates state and keeps existing values', () {
      final startedAt = DateTime.utc(2026, 5, 30, 10);
      final state = ActivityRecordingState(
        status: ActivityRecordingStatus.recording,
        activityType: ActivityType.run,
        startedAt: startedAt,
      );

      final updated = state.copyWith(status: ActivityRecordingStatus.paused);

      expect(updated.status, ActivityRecordingStatus.paused);
      expect(updated.activityType, ActivityType.run);
      expect(updated.startedAt, startedAt);
      expect(updated.endedAt, isNull);
      expect(updated.points, isEmpty);
    });

    test('copyWith can clear nullable fields', () {
      final state = ActivityRecordingState(
        activityType: ActivityType.ride,
        startedAt: DateTime.utc(2026),
        endedAt: DateTime.utc(2026, 5, 30),
        lastErrorKey: 'activityRecordingFailed',
      );

      final updated = state.copyWith(
        activityType: null,
        startedAt: null,
        endedAt: null,
        lastErrorKey: null,
      );

      expect(updated.activityType, isNull);
      expect(updated.startedAt, isNull);
      expect(updated.endedAt, isNull);
      expect(updated.lastErrorKey, isNull);
    });

    test('does not expose mutable point lists', () {
      final point = _point();
      final source = [point];
      final state = ActivityRecordingState(points: source);

      source.clear();

      expect(state.points, [point]);
      expect(() => state.points.add(_point()), throwsUnsupportedError);
    });

    test('supports completed state without points', () {
      final state = ActivityRecordingState(
        status: ActivityRecordingStatus.completed,
        startedAt: DateTime.utc(2026),
        endedAt: DateTime.utc(2026, 5, 30),
      );

      expect(state.status, ActivityRecordingStatus.completed);
      expect(state.points, isEmpty);
    });

    test('addPoint returns a new state', () {
      final point = _point();
      final state = ActivityRecordingState();

      final updated = state.addPoint(point);

      expect(state.points, isEmpty);
      expect(updated.points, [point]);
    });
  });
}

ActivityTrackPoint _point() {
  return ActivityTrackPoint(
    latitude: 41,
    longitude: -8,
    timestamp: DateTime.utc(2026),
  );
}