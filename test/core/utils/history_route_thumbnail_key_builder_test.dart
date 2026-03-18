import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/utils/history_route_thumbnail_key_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildHistoryRouteThumbnailCacheKey', () {
    test('liefert stabilen key aus activity-metadaten', () {
      final activity = Activity(
        id: 'activity-123',
        activityType: ActivityType.run,
        startedAt: DateTime.parse('2026-03-18T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-18T11:10:00Z'),
        distanceMeters: 11420,
        trackPoints: const <TrackPoint>[],
        uploaded: true,
      );

      final key = buildHistoryRouteThumbnailCacheKey(activity);
      final expected =
          '${activity.id}|${activity.startedAt.millisecondsSinceEpoch}|${activity.endedAt!.millisecondsSinceEpoch}|11420.00|4200|1';

      expect(key, equals(expected));
    });
  });
}
