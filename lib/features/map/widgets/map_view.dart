import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/models/route_display_mode.dart';
import 'package:endurain/core/services/map_matching_preview_service.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

double resolveMarkerDisplayHeading({
  required double heading,
  required double mapRotation,
}) {
  final normalized = (heading + mapRotation) % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}

double resolveFinalRenderedHeading({
  required double markerHeading,
  required double mapRotation,
  required bool counterRotateMarker,
}) {
  final normalized = counterRotateMarker
      ? markerHeading
      : markerHeading + mapRotation;
  final wrapped = normalized % 360;
  return wrapped < 0 ? wrapped + 360 : wrapped;
}

double resolveMarkerDisplayHeadingWithSafeRotation({
  required double heading,
  required double Function() mapRotationReader,
}) {
  double mapRotation;
  try {
    mapRotation = mapRotationReader();
  } catch (_) {
    mapRotation = 0.0;
  }
  return resolveMarkerDisplayHeading(
    heading: heading,
    mapRotation: mapRotation,
  );
}

List<TrackPoint> resolvePolylineTrackPointsForDisplay({
  required List<TrackPoint> displayTrackPoints,
  required TrackingSessionState sessionState,
  required LatLng currentLocation,
}) {
  if (displayTrackPoints.length >= 2) {
    return displayTrackPoints;
  }
  if (sessionState != TrackingSessionState.recording ||
      displayTrackPoints.isEmpty) {
    return displayTrackPoints;
  }
  final first = displayTrackPoints.first;
  final firstLatLng = LatLng(first.latitude, first.longitude);
  final segmentMeters = const Distance().as(
    LengthUnit.Meter,
    firstLatLng,
    currentLocation,
  );
  if (segmentMeters < 2.0) {
    return displayTrackPoints;
  }
  return [
    ...displayTrackPoints,
    TrackPoint(
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
      timestamp: first.timestamp,
    ),
  ];
}

class MapView extends StatelessWidget {
  const MapView({
    super.key,
    required this.mapController,
    required this.currentLocation,
    required this.tileServerUrl,
    this.tileProvider,
    required this.trackingSnapshot,
    required this.routeDisplayMode,
    required this.heading,
    required this.hasLocationPermission,
    required this.onMapMoved,
  });

  final MapController mapController;
  final LatLng currentLocation;
  final String tileServerUrl;
  final TileProvider? tileProvider;
  final TrackingSessionSnapshot trackingSnapshot;
  final RouteDisplayMode routeDisplayMode;
  final double heading;
  final bool hasLocationPermission;
  final VoidCallback onMapMoved;

  static const _mapMatchingPreviewService = MapMatchingPreviewService();

  bool get _useMatchedRoutePreview => routeDisplayMode != RouteDisplayMode.raw;

  @override
  Widget build(BuildContext context) {
    final markerHeading = resolveMarkerDisplayHeadingWithSafeRotation(
      heading: heading,
      mapRotationReader: () => mapController.camera.rotation,
    );
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: currentLocation,
        initialZoom: MapConstants.defaultZoom,
        minZoom: MapConstants.minZoom,
        maxZoom: MapConstants.maxZoom,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) {
            onMapMoved();
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: tileServerUrl,
          userAgentPackageName: MapConstants.userAgent,
          tileProvider: tileProvider,
        ),
        _buildPolylineLayer(context),
        _buildMarkerLayer(context),
        if (hasLocationPermission)
          MarkerLayer(
            markers: [
              Marker(
                point: currentLocation,
                width: LocationMarkerConstants.markerSize,
                height: LocationMarkerConstants.markerSize,
                alignment: Alignment.center,
                rotate: true,
                child: _LocationMarker(heading: markerHeading),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPolylineLayer(BuildContext context) {
    final baseTrackPoints = _mapMatchingPreviewService.pointsForDisplay(
      rawPoints: trackingSnapshot.trackPoints,
      useMatchedPreview: _useMatchedRoutePreview,
    );
    final displayTrackPoints = resolvePolylineTrackPointsForDisplay(
      displayTrackPoints: baseTrackPoints,
      sessionState: trackingSnapshot.state,
      currentLocation: currentLocation,
    );

    if (displayTrackPoints.length <= 1) return const SizedBox.shrink();

    final routeOutline = Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.92);
    const routeAccent = Color(0xFFFF5A1F);

    final points = displayTrackPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    return PolylineLayer(
      polylines: [
        Polyline(points: points, strokeWidth: 8, color: routeOutline),
        Polyline(points: points, strokeWidth: 4, color: routeAccent),
      ],
    );
  }

  Widget _buildMarkerLayer(BuildContext context) {
    final displayTrackPoints = _mapMatchingPreviewService.pointsForDisplay(
      rawPoints: trackingSnapshot.trackPoints,
      useMatchedPreview: _useMatchedRoutePreview,
    );

    if (displayTrackPoints.isEmpty) return const SizedBox.shrink();

    return MarkerLayer(
      markers: [
        Marker(
          point: LatLng(
            displayTrackPoints.first.latitude,
            displayTrackPoints.first.longitude,
          ),
          width: 24,
          height: 24,
          child: _RoutePointBadge(
            label: 'A',
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Marker(
          point: LatLng(
            displayTrackPoints.last.latitude,
            displayTrackPoints.last.longitude,
          ),
          width: 24,
          height: 24,
          child: _RoutePointBadge(
            label: 'B',
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }
}

class _RoutePointBadge extends StatelessWidget {
  const _RoutePointBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _LocationMarker extends StatelessWidget {
  const _LocationMarker({required this.heading});

  final double heading;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * math.pi / 180,
      child: CustomPaint(
        size: const Size(
          LocationMarkerConstants.markerSize,
          LocationMarkerConstants.markerSize,
        ),
        painter: _LocationMarkerPainter(),
      ),
    );
  }
}

class _LocationMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 5;

    final conePaint = Paint()
      ..color = Colors.blue.withValues(
        alpha: LocationMarkerConstants.coneOpacity,
      )
      ..style = PaintingStyle.fill;

    final conePath = ui.Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(
        center.dx - radius * LocationMarkerConstants.coneWidthMultiplier,
        center.dy - radius * LocationMarkerConstants.coneHeightMultiplier,
      )
      ..arcToPoint(
        Offset(
          center.dx + radius * LocationMarkerConstants.coneWidthMultiplier,
          center.dy - radius * LocationMarkerConstants.coneHeightMultiplier,
        ),
        radius: Radius.circular(
          radius * LocationMarkerConstants.coneArcRadiusMultiplier,
        ),
        clockwise: true,
      )
      ..close();

    canvas.drawPath(conePath, conePaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      center,
      radius + LocationMarkerConstants.borderWidth,
      borderPaint,
    );

    final dotPaint = Paint()
      ..color = const Color(LocationMarkerConstants.markerBlue)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
