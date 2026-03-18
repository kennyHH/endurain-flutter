import 'package:endurain/core/models/activity.dart';

String buildHistoryRouteThumbnailCacheKey(Activity activity) {
  final startedMs = activity.startedAt.millisecondsSinceEpoch;
  final endedMs = activity.endedAt?.millisecondsSinceEpoch ?? -1;
  final distance = activity.distanceMeters.toStringAsFixed(2);
  final duration = activity.durationSeconds;
  final uploaded = activity.uploaded ? 1 : 0;
  return '${activity.id}|$startedMs|$endedMs|$distance|$duration|$uploaded';
}
