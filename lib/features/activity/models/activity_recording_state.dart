import 'dart:collection';

import 'package:endurain/features/activity/models/activity_track_point.dart';
import 'package:endurain/features/activity/models/activity_type.dart';

enum ActivityRecordingStatus {
  idle,
  recording,
  paused,
  stopping,
  completed,
  failed,
}

class ActivityRecordingState {
  ActivityRecordingState({
    this.status = ActivityRecordingStatus.idle,
    this.activityType,
    this.startedAt,
    this.endedAt,
    this.lastErrorKey,
    this.elapsedDurationSeconds = 0,
    List<ActivityTrackPoint> points = const [],
  }) : _points = List<ActivityTrackPoint>.unmodifiable(points);

  final ActivityRecordingStatus status;
  final ActivityType? activityType;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? lastErrorKey;
  final int elapsedDurationSeconds;
  final List<ActivityTrackPoint> _points;

  List<ActivityTrackPoint> get points => UnmodifiableListView(_points);

  bool get isActive {
    return status == ActivityRecordingStatus.recording ||
        status == ActivityRecordingStatus.paused;
  }

  ActivityRecordingState copyWith({
    ActivityRecordingStatus? status,
    Object? activityType = _unset,
    Object? startedAt = _unset,
    Object? endedAt = _unset,
    Object? lastErrorKey = _unset,
    int? elapsedDurationSeconds,
    List<ActivityTrackPoint>? points,
  }) {
    return ActivityRecordingState(
      status: status ?? this.status,
      activityType: identical(activityType, _unset)
          ? this.activityType
          : activityType as ActivityType?,
      startedAt: identical(startedAt, _unset)
          ? this.startedAt
          : startedAt as DateTime?,
      endedAt: identical(endedAt, _unset) ? this.endedAt : endedAt as DateTime?,
      lastErrorKey: identical(lastErrorKey, _unset)
          ? this.lastErrorKey
          : lastErrorKey as String?,
      elapsedDurationSeconds:
          elapsedDurationSeconds ?? this.elapsedDurationSeconds,
      points: points ?? _points,
    );
  }

  ActivityRecordingState addPoint(ActivityTrackPoint point) {
    return copyWith(points: [..._points, point]);
  }

  static const Object _unset = Object();
}
