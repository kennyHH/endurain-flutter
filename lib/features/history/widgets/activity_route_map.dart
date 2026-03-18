import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/map_matching_preview_service.dart';
import 'package:endurain/core/services/route_thumbnail_cache_service.dart';
import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/l10n/app_localizations.dart';

class ActivityRouteMap extends StatefulWidget {
  const ActivityRouteMap({
    super.key,
    required this.points,
    required this.interactive,
    required this.height,
    required this.useMatchedTrack,
    required this.activityType,
    this.thumbnailCacheKey,
    this.onThumbnailReady,
    this.showRouteStatus = true,
  });

  static const _mapMatchingPreviewService = MapMatchingPreviewService();
  static final _routeThumbnailCacheService = RouteThumbnailCacheService();

  final List<TrackPoint> points;
  final bool interactive;
  final double height;
  final bool useMatchedTrack;
  final ActivityType activityType;
  final String? thumbnailCacheKey;
  final VoidCallback? onThumbnailReady;
  final bool showRouteStatus;

  static Future<void> warmUpInOverlay({
    required BuildContext context,
    required List<TrackPoint> points,
    required bool useMatchedTrack,
    required ActivityType activityType,
    required String thumbnailCacheKey,
    double height = 116,
  }) async {
    if (points.length < 2) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final completer = Completer<void>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final width = (MediaQuery.sizeOf(overlayContext).width - 28).clamp(
          220.0,
          820.0,
        );
        return IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: Opacity(
              opacity: 0.001,
              child: SizedBox(
                width: width,
                height: height,
                child: ActivityRouteMap(
                  points: points,
                  interactive: false,
                  height: height,
                  useMatchedTrack: useMatchedTrack,
                  activityType: activityType,
                  thumbnailCacheKey: thumbnailCacheKey,
                  showRouteStatus: false,
                  onThumbnailReady: () {
                    if (!completer.isCompleted) completer.complete();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    try {
      await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
    } finally {
      entry.remove();
    }
  }

  @override
  State<ActivityRouteMap> createState() => _ActivityRouteMapState();
}

class _ActivityRouteMapState extends State<ActivityRouteMap> {
  List<TrackPoint>? _displayPoints;
  RouteMatchSource _routeSource = RouteMatchSource.raw;

  @override
  void initState() {
    super.initState();
    if (widget.interactive) {
      _resolveDisplayPoints();
    }
  }

  @override
  void didUpdateWidget(covariant ActivityRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pointsChanged = oldWidget.points != widget.points;
    final modeChanged = oldWidget.useMatchedTrack != widget.useMatchedTrack;
    final typeChanged = oldWidget.activityType != widget.activityType;
    final interactiveChanged = oldWidget.interactive != widget.interactive;
    if (interactiveChanged && !widget.interactive) {
      setState(() {
        _displayPoints = null;
        _routeSource = RouteMatchSource.raw;
      });
      return;
    }
    if (widget.interactive && (pointsChanged || modeChanged || typeChanged)) {
      _resolveDisplayPoints();
    }
  }

  Future<void> _resolveDisplayPoints() async {
    final result = await ActivityRouteMap._mapMatchingPreviewService
        .resolveRouteDisplayAsync(
          rawPoints: widget.points,
          useMatchedPreview: widget.useMatchedTrack,
          activityType: widget.activityType,
        );
    if (!mounted) return;
    setState(() {
      _displayPoints = result.points;
      _routeSource = result.source;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.interactive) {
      return _StaticRoutePreview(
        points: widget.points,
        height: widget.height,
        thumbnailCacheKey: widget.thumbnailCacheKey,
        onThumbnailReady: widget.onThumbnailReady,
      );
    }

    final displayPoints =
        _displayPoints ??
        ActivityRouteMap._mapMatchingPreviewService.pointsForDisplay(
          rawPoints: widget.points,
          useMatchedPreview: widget.useMatchedTrack,
        );
    if (displayPoints.length < 2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: widget.height,
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          alignment: Alignment.center,
          child: const Icon(Icons.route),
        ),
      );
    }
    final latLngPoints = displayPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    final routeOutline = Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.92);
    const routeAccent = Color(0xFFFF5A1F);
    final map = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(latLngPoints),
              padding: const EdgeInsets.all(30),
            ),
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: MapConstants.defaultTileServerUrl,
              userAgentPackageName: MapConstants.userAgent,
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: latLngPoints,
                  strokeWidth: 8,
                  color: routeOutline,
                ),
                Polyline(
                  points: latLngPoints,
                  strokeWidth: 4,
                  color: routeAccent,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  width: 24,
                  height: 24,
                  point: latLngPoints.first,
                  child: _RoutePointBadge(
                    label: 'A',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Marker(
                  width: 24,
                  height: 24,
                  point: latLngPoints.last,
                  child: _RoutePointBadge(
                    label: 'B',
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final statusText = switch (_routeSource) {
      RouteMatchSource.matched => AppLocalizations.of(
        context,
      )!.routeStatusMatched,
      RouteMatchSource.fallback => AppLocalizations.of(
        context,
      )!.routeStatusFallback,
      RouteMatchSource.raw => AppLocalizations.of(context)!.routeStatusRaw,
    };
    return Stack(
      children: [
        map,
        if (widget.showRouteStatus)
          Positioned(
            top: 8,
            right: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  statusText,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StaticRoutePreview extends StatefulWidget {
  const _StaticRoutePreview({
    required this.points,
    required this.height,
    this.thumbnailCacheKey,
    this.onThumbnailReady,
  });

  final List<TrackPoint> points;
  final double height;
  final String? thumbnailCacheKey;
  final VoidCallback? onThumbnailReady;

  @override
  State<_StaticRoutePreview> createState() => _StaticRoutePreviewState();
}

class _StaticRoutePreviewState extends State<_StaticRoutePreview> {
  String? _activeSignature;
  Future<Uint8List>? _thumbnailFuture;
  final GlobalKey _mapBoundaryKey = GlobalKey();
  bool _thumbnailReadyNotified = false;

  @override
  Widget build(BuildContext context) {
    if (widget.points.length < 2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: widget.height,
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          alignment: Alignment.center,
          child: const Icon(Icons.route),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dpr = MediaQuery.devicePixelRatioOf(context);
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 320.0;
            final widthPx = (width * dpr).round().clamp(240, 2048);
            final heightPx = (widget.height * dpr).round().clamp(120, 1024);
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            final cacheKey =
                widget.thumbnailCacheKey ??
                '${widget.points.length}:${widget.points.first.timestamp.millisecondsSinceEpoch}:${widget.points.last.timestamp.millisecondsSinceEpoch}';
            final signature =
                '$cacheKey|$widthPx|$heightPx|${isDarkMode ? 1 : 0}';
            if (_activeSignature != signature) {
              _activeSignature = signature;
              _thumbnailReadyNotified = false;
              _thumbnailFuture = ActivityRouteMap._routeThumbnailCacheService
                  .getOrCreate(
                    cacheKey: cacheKey,
                    widthPx: widthPx,
                    heightPx: heightPx,
                    isDarkMode: isDarkMode,
                    createBytes: () => _captureMapImage(dpr: dpr),
                  );
            }
            return FutureBuilder<Uint8List>(
              future: _thumbnailFuture,
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes != null && bytes.isNotEmpty) {
                  if (!_thumbnailReadyNotified) {
                    _thumbnailReadyNotified = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      widget.onThumbnailReady?.call();
                    });
                  }
                  return Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: widget.height,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                  );
                }
                return RepaintBoundary(
                  key: _mapBoundaryKey,
                  child: _buildTileRouteMap(context),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTileRouteMap(BuildContext context) {
    final latLngPoints = widget.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    final routeOutline = Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.92);
    const routeAccent = Color(0xFFFF5A1F);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(latLngPoints),
            padding: const EdgeInsets.all(30),
          ),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: MapConstants.defaultTileServerUrl,
            userAgentPackageName: MapConstants.userAgent,
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: latLngPoints,
                strokeWidth: 8,
                color: routeOutline,
              ),
              Polyline(
                points: latLngPoints,
                strokeWidth: 4,
                color: routeAccent,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                width: 24,
                height: 24,
                point: latLngPoints.first,
                child: _RoutePointBadge(
                  label: 'A',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Marker(
                width: 24,
                height: 24,
                point: latLngPoints.last,
                child: _RoutePointBadge(
                  label: 'B',
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _captureMapImage({required double dpr}) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final renderObject = _mapBoundaryKey.currentContext?.findRenderObject();
      if (renderObject is RenderRepaintBoundary &&
          !renderObject.debugNeedsPaint) {
        final image = await renderObject.toImage(pixelRatio: dpr);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes != null) {
          return bytes.buffer.asUint8List();
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 140));
    }
    return Uint8List(0);
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
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
