import 'dart:collection';

import 'package:endurain/features/activity/models/activity_track_point.dart';

class ActivityTrackSegment {
  ActivityTrackSegment({List<ActivityTrackPoint> points = const []})
    : _points = List<ActivityTrackPoint>.unmodifiable(points);

  final List<ActivityTrackPoint> _points;

  List<ActivityTrackPoint> get points => UnmodifiableListView(_points);

  ActivityTrackSegment addPoint(ActivityTrackPoint point) {
    return ActivityTrackSegment(points: [..._points, point]);
  }
}
