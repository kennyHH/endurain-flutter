import 'package:endurain/core/models/activity.dart';

class GpxExporter {
  String export(Activity activity) {
    final normalizedPoints = _normalizeTrackPointsForExport(activity);
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="Endurain Mobile" xmlns="http://www.topografix.com/GPX/1/1">',
      )
      ..writeln('  <trk>')
      ..writeln('    <name>${_escapeXml(_buildActivityName(activity))}</name>')
      ..writeln('    <type>${activityTypeToJson(activity.activityType)}</type>')
      ..writeln('    <trkseg>');

    for (final point in normalizedPoints) {
      _validatePoint(point);
      final time = point.timestamp.toUtc().toIso8601String();
      final elevation = point.altitudeMeters;
      final elevationNode = elevation == null
          ? ''
          : '<ele>${elevation.toStringAsFixed(2)}</ele>';
      buffer.writeln(
        '      <trkpt lat="${point.latitude}" lon="${point.longitude}">$elevationNode<time>$time</time></trkpt>',
      );
    }

    buffer
      ..writeln('    </trkseg>')
      ..writeln('  </trk>')
      ..writeln('</gpx>');

    return buffer.toString();
  }

  List<TrackPoint> _normalizeTrackPointsForExport(Activity activity) {
    final points = List<TrackPoint>.from(activity.trackPoints);
    if (points.isEmpty) return points;
    final start = activity.startedAt;
    final end = activity.endedAt;
    final first = points.first;
    if (first.timestamp.isAfter(start)) {
      points.insert(0, first.copyWith(timestamp: start));
    }
    if (end != null) {
      final last = points.last;
      if (last.timestamp.isBefore(end)) {
        points.add(last.copyWith(timestamp: end));
      }
    }
    return points;
  }

  String _buildActivityName(Activity activity) {
    if (activity.name != null && activity.name!.trim().isNotEmpty) {
      return activity.name!.trim();
    }
    final label = switch (activity.activityType) {
      ActivityType.run => 'Run',
      ActivityType.ride => 'Ride',
      ActivityType.walk => 'Walk',
    };
    final local = activity.startedAt.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$label $year-$month-$day $hour:$minute';
  }

  void _validatePoint(TrackPoint point) {
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude < -90 ||
        point.latitude > 90 ||
        point.longitude < -180 ||
        point.longitude > 180 ||
        (point.altitudeMeters != null && !point.altitudeMeters!.isFinite)) {
      throw const FormatException('Invalid track point coordinates for GPX');
    }
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
