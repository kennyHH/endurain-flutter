import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/map_matching_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';

List<TrackPoint> _buildLinearTrack({
  required double latitudeStart,
  required double latitudeStep,
  required int count,
}) {
  final start = DateTime.utc(2026, 3, 16, 12, 0, 0);
  return List<TrackPoint>.generate(count, (index) {
    return TrackPoint(
      latitude: latitudeStart + latitudeStep * index,
      longitude: 13.405,
      timestamp: start.add(Duration(seconds: index)),
    );
  });
}

void main() {
  group('MapMatchingPreviewService Gate-1 fallback smoothing', () {
    const service = MapMatchingPreviewService();

    test('keeps short tracks raw to avoid urban house cut-through', () {
      final raw = _buildLinearTrack(
        latitudeStart: 52.52,
        latitudeStep: 0.00005,
        count: 6,
      );

      final display = service.pointsForDisplay(
        rawPoints: raw,
        useMatchedPreview: true,
      );

      expect(display.length, raw.length);
      expect(display[2].latitude, closeTo(raw[2].latitude, 1e-12));
      expect(display[2].longitude, closeTo(raw[2].longitude, 1e-12));
    });

    test('still smooths longer tracks in fallback mode', () {
      final start = DateTime.utc(2026, 3, 16, 12, 0, 0);
      final raw = <TrackPoint>[
        TrackPoint(latitude: 52.5200, longitude: 13.4050, timestamp: start),
        TrackPoint(
          latitude: 52.5205,
          longitude: 13.4050,
          timestamp: start.add(const Duration(seconds: 1)),
        ),
        TrackPoint(
          latitude: 52.5210,
          longitude: 13.4065,
          timestamp: start.add(const Duration(seconds: 2)),
        ),
        TrackPoint(
          latitude: 52.5215,
          longitude: 13.4050,
          timestamp: start.add(const Duration(seconds: 3)),
        ),
        TrackPoint(
          latitude: 52.5220,
          longitude: 13.4050,
          timestamp: start.add(const Duration(seconds: 4)),
        ),
        TrackPoint(
          latitude: 52.5225,
          longitude: 13.4050,
          timestamp: start.add(const Duration(seconds: 5)),
        ),
      ];

      final display = service.pointsForDisplay(
        rawPoints: raw,
        useMatchedPreview: true,
      );

      expect(display.length, raw.length);
      expect(display[0].latitude, closeTo(raw[0].latitude, 1e-12));
      expect(display.last.latitude, closeTo(raw.last.latitude, 1e-12));
      expect(display[2].longitude, isNot(closeTo(raw[2].longitude, 1e-12)));
    });

    test('returns raw when matched preview is disabled', () {
      final raw = _buildLinearTrack(
        latitudeStart: 52.52,
        latitudeStep: 0.00050,
        count: 6,
      );

      final display = service.pointsForDisplay(
        rawPoints: raw,
        useMatchedPreview: false,
      );

      expect(display.length, raw.length);
      expect(display[2].latitude, closeTo(raw[2].latitude, 1e-12));
    });
  });
}
