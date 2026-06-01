import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_track_segment.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/models/activity_track_point.dart';

class ActivityGpxBuilder {
  const ActivityGpxBuilder();

  String build(ActivityRecordingState state, {String? trackName}) {
    final name = trackName ?? _defaultTrackName(state.activityType);
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="Endurain Mobile" '
        'xmlns="http://www.topografix.com/GPX/1/1">',
      )
      ..writeln('  <trk>')
      ..writeln('    <name>${_escapeXml(name)}</name>');

    for (final segment in _segmentsForGpx(state)) {
      buffer.writeln('    <trkseg>');
      for (final point in segment.points) {
        _writeTrackPoint(buffer, point);
      }
      buffer.writeln('    </trkseg>');
    }

    buffer
      ..writeln('  </trk>')
      ..writeln('</gpx>');

    return buffer.toString();
  }

  String _defaultTrackName(ActivityType? activityType) {
    return activityType?.apiValue ?? ActivityType.other.apiValue;
  }

  List<ActivityTrackSegment> _segmentsForGpx(ActivityRecordingState state) {
    final segments = state.segments
        .where((segment) => segment.points.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return [ActivityTrackSegment()];
    }
    return segments;
  }

  void _writeTrackPoint(StringBuffer buffer, ActivityTrackPoint point) {
    buffer.writeln(
      '      <trkpt lat="${point.latitude}" lon="${point.longitude}">',
    );

    if (point.elevationMeters != null) {
      buffer.writeln('        <ele>${point.elevationMeters}</ele>');
    }

    buffer.writeln('        <time>${_formatTimestamp(point.timestamp)}</time>');
    buffer.writeln('      </trkpt>');
  }

  String _formatTimestamp(DateTime timestamp) {
    return timestamp.toUtc().toIso8601String();
  }

  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
