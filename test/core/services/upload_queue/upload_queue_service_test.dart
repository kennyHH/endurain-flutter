import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/upload_queue/upload_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UploadQueueService', () {
    late UploadQueueService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = UploadQueueService();
    });

    test('queue starts empty', () async {
      final queue = await service.getQueue();
      expect(queue, isEmpty);
    });

    test('adds activity to queue', () async {
      final activity = Activity(
        id: '1',
        activityType: ActivityType.run,
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        distanceMeters: 100,
        trackPoints: [],
      );

      await service.addToQueue(activity);
      final queue = await service.getQueue();
      
      expect(queue.length, 1);
      expect(queue.first.id, '1');
    });

    test('removes activity from queue', () async {
      final activity = Activity(
        id: '1',
        activityType: ActivityType.run,
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        distanceMeters: 100,
        trackPoints: [],
      );

      await service.addToQueue(activity);
      await service.removeFromQueue('1');
      final queue = await service.getQueue();
      
      expect(queue, isEmpty);
    });

    test('ignores duplicates', () async {
      final activity = Activity(
        id: '1',
        activityType: ActivityType.run,
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        distanceMeters: 100,
        trackPoints: [],
      );

      await service.addToQueue(activity);
      await service.addToQueue(activity);
      final queue = await service.getQueue();
      
      expect(queue.length, 1);
    });
  });
}
