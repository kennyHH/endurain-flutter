import 'dart:convert';

import 'package:endurain/core/models/activity.dart';
import 'package:http/http.dart' as http;

enum RouteMatchSource { raw, matched, fallback }

class RouteDisplayResult {
  const RouteDisplayResult({required this.points, required this.source});

  final List<TrackPoint> points;
  final RouteMatchSource source;
}

class MapMatchingPreviewService {
  const MapMatchingPreviewService();

  static final Map<String, List<TrackPoint>> _matchedCache =
      <String, List<TrackPoint>>{};

  List<TrackPoint> pointsForDisplay({
    required List<TrackPoint> rawPoints,
    required bool useMatchedPreview,
  }) {
    if (!useMatchedPreview || rawPoints.length < 3) {
      return rawPoints;
    }

    try {
      return _smoothByMovingAverage(rawPoints);
    } catch (_) {
      // Hard fallback: never break rendering because of preview matching.
      return rawPoints;
    }
  }

  Future<List<TrackPoint>> pointsForDisplayAsync({
    required List<TrackPoint> rawPoints,
    required bool useMatchedPreview,
    required ActivityType activityType,
  }) async {
    final result = await resolveRouteDisplayAsync(
      rawPoints: rawPoints,
      useMatchedPreview: useMatchedPreview,
      activityType: activityType,
    );
    return result.points;
  }

  Future<RouteDisplayResult> resolveRouteDisplayAsync({
    required List<TrackPoint> rawPoints,
    required bool useMatchedPreview,
    required ActivityType activityType,
  }) async {
    if (!useMatchedPreview || rawPoints.length < 3) {
      return RouteDisplayResult(points: rawPoints, source: RouteMatchSource.raw);
    }
    final cacheKey = _cacheKey(rawPoints, activityType);
    final cached = _matchedCache[cacheKey];
    if (cached != null) {
      final source = _sourceForCache(cacheKey, useMatchedPreview);
      return RouteDisplayResult(points: cached, source: source);
    }
    try {
      final matched = await _matchViaOsrm(
        rawPoints: rawPoints,
        activityType: activityType,
      );
      if (matched.length >= 2) {
        _matchedCache[cacheKey] = matched;
        _storeSource(cacheKey, RouteMatchSource.matched);
        return RouteDisplayResult(
          points: matched,
          source: RouteMatchSource.matched,
        );
      }
    } catch (_) {
      // Network matching is best-effort only.
    }
    final fallback = _smoothByMovingAverage(rawPoints);
    _matchedCache[cacheKey] = fallback;
    _storeSource(cacheKey, RouteMatchSource.fallback);
    return RouteDisplayResult(points: fallback, source: RouteMatchSource.fallback);
  }

  Future<List<TrackPoint>> _matchViaOsrm({
    required List<TrackPoint> rawPoints,
    required ActivityType activityType,
  }) async {
    final profile = activityType == ActivityType.ride ? 'cycling' : 'walking';
    final compact = _samplePoints(rawPoints, maxPoints: 90);
    final coordinates = compact
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');
    final uri = Uri.parse(
      'https://router.project-osrm.org/match/v1/$profile/$coordinates'
      '?overview=full&geometries=geojson&tidy=true',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('OSRM match failed (${response.statusCode})');
    }
    final payload = json.decode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw StateError('Invalid map-matching payload');
    }
    final matchings = payload['matchings'];
    if (matchings is! List || matchings.isEmpty) {
      throw StateError('No matchings returned');
    }
    final first = matchings.first;
    if (first is! Map<String, dynamic>) {
      throw StateError('Invalid matching entry');
    }
    final geometry = first['geometry'];
    if (geometry is! Map<String, dynamic>) {
      throw StateError('Missing geometry');
    }
    final coords = geometry['coordinates'];
    if (coords is! List || coords.length < 2) {
      throw StateError('Not enough matched coordinates');
    }
    final start = rawPoints.first.timestamp;
    final end = rawPoints.last.timestamp;
    final totalMillis = end.difference(start).inMilliseconds;
    final matched = <TrackPoint>[];
    for (var i = 0; i < coords.length; i++) {
      final value = coords[i];
      if (value is! List || value.length < 2) continue;
      final lng = (value[0] as num).toDouble();
      final lat = (value[1] as num).toDouble();
      final ratio = coords.length == 1 ? 0.0 : i / (coords.length - 1);
      final timestamp = start.add(
        Duration(milliseconds: (totalMillis * ratio).round()),
      );
      matched.add(
        TrackPoint(
          latitude: lat,
          longitude: lng,
          timestamp: timestamp,
        ),
      );
    }
    return matched.length >= 2 ? matched : rawPoints;
  }

  List<TrackPoint> _samplePoints(List<TrackPoint> points, {int maxPoints = 90}) {
    if (points.length <= maxPoints) return points;
    final sampled = <TrackPoint>[points.first];
    final stride = (points.length - 1) / (maxPoints - 1);
    for (var i = 1; i < maxPoints - 1; i++) {
      final index = (i * stride).round().clamp(1, points.length - 2);
      sampled.add(points[index]);
    }
    sampled.add(points.last);
    return sampled;
  }

  String _cacheKey(List<TrackPoint> points, ActivityType activityType) {
    final first = points.first.timestamp.microsecondsSinceEpoch;
    final last = points.last.timestamp.microsecondsSinceEpoch;
    return '${activityType.name}:${points.length}:$first:$last';
  }

  static final Map<String, RouteMatchSource> _sourceCache =
      <String, RouteMatchSource>{};

  void _storeSource(String key, RouteMatchSource source) {
    _sourceCache[key] = source;
  }

  RouteMatchSource _sourceForCache(String key, bool useMatchedPreview) {
    if (!useMatchedPreview) return RouteMatchSource.raw;
    return _sourceCache[key] ?? RouteMatchSource.fallback;
  }

  List<TrackPoint> _smoothByMovingAverage(List<TrackPoint> rawPoints) {
    final smoothed = <TrackPoint>[rawPoints.first];
    for (var i = 1; i < rawPoints.length - 1; i++) {
      final prev = rawPoints[i - 1];
      final curr = rawPoints[i];
      final next = rawPoints[i + 1];
      smoothed.add(
        TrackPoint(
          latitude: (prev.latitude + curr.latitude + next.latitude) / 3,
          longitude: (prev.longitude + curr.longitude + next.longitude) / 3,
          timestamp: curr.timestamp,
          altitudeMeters: curr.altitudeMeters,
        ),
      );
    }
    smoothed.add(rawPoints.last);
    return smoothed;
  }
}
