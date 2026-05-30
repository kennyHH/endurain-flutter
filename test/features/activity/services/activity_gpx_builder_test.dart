import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_track_point.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/services/activity_gpx_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityGpxBuilder', () {
    const builder = ActivityGpxBuilder();

    test('builds GPX for valid points', () {
      final gpx = builder.build(
        ActivityRecordingState(
          status: ActivityRecordingStatus.completed,
          activityType: ActivityType.run,
          points: [
            _point(latitude: 41.1, longitude: -8.6, elevationMeters: 20),
            _point(latitude: 41.2, longitude: -8.7, elevationMeters: 25),
          ],
        ),
      );

      expect(gpx, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(gpx, contains('<gpx version="1.1" creator="Endurain Mobile"'));
      expect(gpx, contains('<name>run</name>'));
      expect(gpx, contains('<trkpt lat="41.1" lon="-8.6">'));
      expect(gpx, contains('<ele>20.0</ele>'));
      expect(gpx, contains('<time>2026-05-30T10:00:00.000Z</time>'));
      expect(gpx, contains('</gpx>'));
    });

    test('omits elevation when missing', () {
      final gpx = builder.build(
        ActivityRecordingState(
          status: ActivityRecordingStatus.completed,
          points: [_point(elevationMeters: null)],
        ),
      );

      expect(gpx, isNot(contains('<ele>')));
      expect(gpx, contains('<time>2026-05-30T10:00:00.000Z</time>'));
    });

    test('builds well-formed empty track segments', () {
      final gpx = builder.build(
        ActivityRecordingState(status: ActivityRecordingStatus.completed),
      );

      expect(gpx, contains('<trkseg>'));
      expect(gpx, contains('</trkseg>'));
      expect(gpx, isNot(contains('<trkpt')));
    });

    test('escapes XML metadata values', () {
      final gpx = builder.build(
        ActivityRecordingState(status: ActivityRecordingStatus.completed),
        trackName: 'A&B "run" <test>',
      );

      expect(gpx, contains('<name>A&amp;B &quot;run&quot; &lt;test&gt;</name>'));
    });
  });
}

ActivityTrackPoint _point({
  double latitude = 41,
  double longitude = -8,
  double? elevationMeters = 20,
}) {
  return ActivityTrackPoint(
    latitude: latitude,
    longitude: longitude,
    elevationMeters: elevationMeters,
    timestamp: DateTime.utc(2026, 5, 30, 10),
  );
}