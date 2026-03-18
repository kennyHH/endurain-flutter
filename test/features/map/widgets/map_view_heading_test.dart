import 'package:endurain/features/map/widgets/map_view.dart';
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveMarkerDisplayHeading', () {
    test('zeigt im North-Up-Modus die echte Blickrichtung', () {
      expect(
        resolveMarkerDisplayHeading(heading: 95, mapRotation: 0),
        closeTo(95, 0.001),
      );
    });

    test('zeigt im Heading-Up-Modus Marker nach oben', () {
      expect(
        resolveMarkerDisplayHeading(heading: 95, mapRotation: -95),
        closeTo(0, 0.001),
      );
    });

    test('normalisiert negative und >360 Werte korrekt', () {
      expect(
        resolveMarkerDisplayHeading(heading: 350, mapRotation: -370),
        closeTo(340, 0.001),
      );
    });
  });

  group('resolveMarkerDisplayHeadingWithSafeRotation', () {
    test('fällt ohne Crash auf 0° Kartenrotation zurück', () {
      final heading = resolveMarkerDisplayHeadingWithSafeRotation(
        heading: 110,
        mapRotationReader: () => throw StateError('camera not ready'),
      );
      expect(heading, closeTo(110, 0.001));
    });
  });

  group('resolveFinalRenderedHeading', () {
    test('keeps heading-up cone pointing forward on screen', () {
      final markerHeading = resolveMarkerDisplayHeading(
        heading: 95,
        mapRotation: -95,
      );
      final rendered = resolveFinalRenderedHeading(
        markerHeading: markerHeading,
        mapRotation: -95,
        counterRotateMarker: true,
      );
      expect(rendered, closeTo(0, 0.001));
    });

    test('shows real world heading in north-up mode', () {
      final markerHeading = resolveMarkerDisplayHeading(
        heading: 140,
        mapRotation: 0,
      );
      final rendered = resolveFinalRenderedHeading(
        markerHeading: markerHeading,
        mapRotation: 0,
        counterRotateMarker: true,
      );
      expect(rendered, closeTo(140, 0.001));
    });
  });

  group('resolvePolylineTrackPointsForDisplay', () {
    test(
      'zeigt bei einem Startpunkt im Recording sofort provisorisches Segment',
      () {
        final start = TrackPoint(
          latitude: 52.5200,
          longitude: 13.4050,
          timestamp: DateTime.utc(2026, 1, 1),
        );
        final result = resolvePolylineTrackPointsForDisplay(
          displayTrackPoints: [start],
          sessionState: TrackingSessionState.recording,
          currentLocation: const LatLng(52.52008, 13.4050),
        );
        expect(result.length, 2);
        expect(result.last.latitude, closeTo(52.52008, 0.0000001));
      },
    );

    test('fügt kein provisorisches Segment außerhalb recording hinzu', () {
      final start = TrackPoint(
        latitude: 52.5200,
        longitude: 13.4050,
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final result = resolvePolylineTrackPointsForDisplay(
        displayTrackPoints: [start],
        sessionState: TrackingSessionState.paused,
        currentLocation: const LatLng(52.52008, 13.4050),
      );
      expect(result.length, 1);
    });

    test('behält vorhandene Mehrpunkt-Route unverändert', () {
      final start = TrackPoint(
        latitude: 52.5200,
        longitude: 13.4050,
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final second = TrackPoint(
        latitude: 52.52003,
        longitude: 13.4050,
        timestamp: DateTime.utc(2026, 1, 1, 0, 0, 5),
      );
      final result = resolvePolylineTrackPointsForDisplay(
        displayTrackPoints: [start, second],
        sessionState: TrackingSessionState.recording,
        currentLocation: const LatLng(52.52008, 13.4050),
      );
      expect(result.length, 2);
      expect(result.last.latitude, closeTo(second.latitude, 0.0000001));
    });
  });
}
