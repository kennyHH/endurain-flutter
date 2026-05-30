import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityType', () {
    test('maps supported API values', () {
      expect(ActivityType.fromApiValue('run'), ActivityType.run);
      expect(ActivityType.fromApiValue('ride'), ActivityType.ride);
      expect(ActivityType.fromApiValue('walk'), ActivityType.walk);
      expect(ActivityType.fromApiValue('hike'), ActivityType.hike);
      expect(ActivityType.fromApiValue('other'), ActivityType.other);
    });

    test('maps unknown and missing API values to other', () {
      expect(ActivityType.fromApiValue('swim'), ActivityType.other);
      expect(ActivityType.fromApiValue(null), ActivityType.other);
    });
  });
}
