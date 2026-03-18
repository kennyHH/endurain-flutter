import 'dart:math' as math;
import 'package:endurain/core/models/activity.dart';

class DouglasPeucker {
  /// Simplifies a list of TrackPoints using the Douglas-Peucker algorithm.
  /// [epsilon] is the tolerance in meters. Points closer than this to the line segment will be removed.
  static List<TrackPoint> simplify(List<TrackPoint> points, double epsilon) {
    if (points.length <= 2) return points;

    // Convert tolerance from meters to degrees (roughly) for simple calculation,
    // or better, project points. For small distances, we can treat lat/lon as cartesian
    // but scaling longitude by cos(lat).
    // Epsilon in meters (~5-10m for visual simplification).
    // 1 deg lat ~= 111km. 1 meter ~= 1/111000 deg ~= 0.000009 deg.
    final epsilonDeg = epsilon / 111000.0;

    return _simplifyRecursive(points, epsilonDeg);
  }

  static List<TrackPoint> _simplifyRecursive(
    List<TrackPoint> points,
    double epsilon,
  ) {
    if (points.length < 3) return points;

    final first = points.first;
    final last = points.last;

    double maxDistance = 0;
    int index = 0;

    for (var i = 1; i < points.length - 1; i++) {
      final d = _perpendicularDistance(points[i], first, last);
      if (d > maxDistance) {
        maxDistance = d;
        index = i;
      }
    }

    if (maxDistance > epsilon) {
      final left = _simplifyRecursive(points.sublist(0, index + 1), epsilon);
      final right = _simplifyRecursive(points.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [first, last];
    }
  }

  static double _perpendicularDistance(
    TrackPoint point,
    TrackPoint lineStart,
    TrackPoint lineEnd,
  ) {
    // Treat as simple cartesian on lat/lon for speed.
    // Ideally map to Web Mercator but for visual simplification of small segments this is fine.
    // If lineStart == lineEnd, distance is just point to start.
    if (lineStart.latitude == lineEnd.latitude &&
        lineStart.longitude == lineEnd.longitude) {
      return math.sqrt(
        math.pow(point.latitude - lineStart.latitude, 2) +
            math.pow(point.longitude - lineStart.longitude, 2),
      );
    }

    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    // Normalize
    final mag = math.sqrt(dx * dx + dy * dy);
    if (mag == 0) return 0;

    final u =
        ((point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy) /
        (mag * mag);

    double intersectionX, intersectionY;

    if (u < 0) {
      intersectionX = lineStart.longitude;
      intersectionY = lineStart.latitude;
    } else if (u > 1) {
      intersectionX = lineEnd.longitude;
      intersectionY = lineEnd.latitude;
    } else {
      intersectionX = lineStart.longitude + u * dx;
      intersectionY = lineStart.latitude + u * dy;
    }

    return math.sqrt(
      math.pow(point.longitude - intersectionX, 2) +
          math.pow(point.latitude - intersectionY, 2),
    );
  }
}
