import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/services/activity_recording_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityRecordingService', () {
    test('starts recording and emits state', () async {
      final startedAt = DateTime.utc(2026, 5, 30, 10);
      final service = ActivityRecordingService(now: () => startedAt);
      addTearDown(service.dispose);

      await service.start(activityType: 'run');

      expect(service.state.status, ActivityRecordingStatus.recording);
      expect(service.state.activityType, 'run');
      expect(service.state.startedAt, startedAt);
      expect(service.state.points, isEmpty);
    });

    test('pause and resume update state', () async {
      final service = ActivityRecordingService();
      addTearDown(service.dispose);

      await service.start(activityType: 'ride');
      await service.pause();

      expect(service.state.status, ActivityRecordingStatus.paused);

      await service.resume();

      expect(service.state.status, ActivityRecordingStatus.recording);
    });

    test('stop emits stopping then completed', () async {
      final completedAt = DateTime.utc(2026, 5, 30, 11);
      var calls = 0;
      final service = ActivityRecordingService(
        now: () => calls++ == 0 ? DateTime.utc(2026, 5, 30, 10) : completedAt,
      );
      addTearDown(service.dispose);
      final states = <ActivityRecordingState>[];
      final subscription = service.stateStream.listen(states.add);
      addTearDown(subscription.cancel);

      await service.start(activityType: 'walk');
      await service.stop();
      await pumpEventQueue();

      expect(
        states.map((state) => state.status),
        [
          ActivityRecordingStatus.recording,
          ActivityRecordingStatus.stopping,
          ActivityRecordingStatus.completed,
        ],
      );
      expect(service.state.endedAt, completedAt);
    });

    test('duplicate start keeps current recording', () async {
      final service = ActivityRecordingService();
      addTearDown(service.dispose);

      await service.start(activityType: 'run');
      final startedAt = service.state.startedAt;
      await service.start(activityType: 'ride');

      expect(service.state.status, ActivityRecordingStatus.recording);
      expect(service.state.activityType, 'run');
      expect(service.state.startedAt, startedAt);
    });

    test('invalid pause moves to failed state without raw error details', () async {
      final service = ActivityRecordingService();
      addTearDown(service.dispose);

      await service.pause();

      expect(service.state.status, ActivityRecordingStatus.failed);
      expect(
        service.state.lastErrorKey,
        ActivityRecordingErrorKeys.invalidTransition,
      );
    });

    test('discard is idempotent and clears state', () async {
      final service = ActivityRecordingService();
      addTearDown(service.dispose);

      await service.start(activityType: 'hike');
      await service.discard();
      await service.discard();

      expect(service.state.status, ActivityRecordingStatus.idle);
      expect(service.state.activityType, isNull);
      expect(service.state.points, isEmpty);
    });
  });
}