import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:endurain/core/services/app_scope.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/features/activity/controllers/activity_recording_controller.dart';
import 'package:endurain/features/activity/services/activity_recording_service.dart';
import 'package:endurain/features/activity/services/activity_upload_service.dart';
import 'package:endurain/features/activity/widgets/activity_recording_controls.dart';
import 'package:endurain/features/activity/widgets/activity_stop_confirmation_dialog.dart';
import 'package:endurain/features/map/map_settings_repository.dart';
import 'package:endurain/features/map/map_state_controller.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/shared/adaptive/adaptive.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.controller,
    this.activityController,
    this.locationService,
    this.storage,
  });

  final MapStateController? controller;
  final ActivityRecordingController? activityController;
  final LocationService? locationService;
  final SecureStorageService? storage;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  late final MapStateController _controller;
  late final ActivityRecordingController _activityController;
  late final bool _ownsController;
  late final bool _ownsActivityController;
  LatLng? _lastFollowedLocation;
  bool _centeredInitialLocation = false;
  bool _isStopConfirmationOpen = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _ownsActivityController = widget.activityController == null;
    _controller = widget.controller ?? _createController();
    _activityController = widget.activityController ?? _createActivityController();
    _controller.addListener(_handleControllerChanged);
    _activityController.addListener(_handleControllerChanged);
    _controller.initialize();
  }

  MapStateController _createController() {
    final services = AppScope.servicesOf(context, listen: false);
    return MapStateController(
      locationService: widget.locationService ?? services.location,
      mapSettingsRepository: MapSettingsRepository(
        storage: widget.storage ?? services.secureStorage,
      ),
    );
  }

  ActivityRecordingController _createActivityController() {
    final services = AppScope.servicesOf(context, listen: false);
    return ActivityRecordingController(
      recordingService: ActivityRecordingService(
        locationService: widget.locationService ?? services.location,
      ),
      uploadService: ActivityUploadService(apiClient: services.apiClient),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _activityController.removeListener(_handleControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    if (_ownsActivityController) {
      _activityController.dispose();
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
    _syncMapToLocationState();
  }

  void _syncMapToLocationState() {
    if (!_controller.hasLocationPermission) {
      return;
    }

    if (!_centeredInitialLocation) {
      _centeredInitialLocation = true;
      _lastFollowedLocation = _controller.currentLocation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          _controller.currentLocation,
          MapConstants.initialLoadZoom,
        );
      });
      return;
    }

    if (!_controller.isLocationLocked ||
        _lastFollowedLocation == _controller.currentLocation) {
      return;
    }

    _lastFollowedLocation = _controller.currentLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(
        _controller.currentLocation,
        _mapController.camera.zoom,
      );
    });
  }

  /// Toggle location lock
  void _toggleLocationLock() {
    _controller.toggleLocationLock();

    // If locking, center on current position
    if (_controller.isLocationLocked && _controller.hasLocationPermission) {
      _mapController.move(
        _controller.currentLocation,
        _mapController.camera.zoom,
      );
    }
  }

  /// Handle map movement by user - unlock location
  void _onMapMoved() {
    _controller.unlockLocation();
  }

  Future<void> _confirmStopActivity() async {
    if (_isStopConfirmationOpen || !_activityController.state.isActive) {
      return;
    }

    _isStopConfirmationOpen = true;
    final action = await showActivityStopConfirmationDialog(context);
    _isStopConfirmationOpen = false;

    if (!mounted) {
      return;
    }

    switch (action) {
      case ActivityStopAction.cancel:
        return;
      case ActivityStopAction.stop:
        await _activityController.stop();
      case ActivityStopAction.discard:
        await _activityController.discard();
    }
  }

  /// Build map options with common configuration
  MapOptions _buildMapOptions() {
    return MapOptions(
      initialCenter: _controller.currentLocation,
      initialZoom: MapConstants.defaultZoom,
      minZoom: MapConstants.minZoom,
      maxZoom: MapConstants.maxZoom,
      onPositionChanged: (position, hasGesture) {
        // Only unlock if user manually moved the map
        if (hasGesture) {
          _onMapMoved();
        }
      },
    );
  }

  /// Build map layers (tile + marker)
  List<Widget> _buildMapLayers() {
    return [
      TileLayer(
        urlTemplate: _controller.tileServerUrl,
        userAgentPackageName: MapConstants.userAgent,
      ),
      if (_controller.hasLocationPermission)
        MarkerLayer(
          markers: [
            Marker(
              point: _controller.currentLocation,
              width: LocationMarkerConstants.markerSize,
              height: LocationMarkerConstants.markerSize,
              alignment: Alignment.center,
              child: _LocationMarker(heading: _controller.heading),
            ),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AdaptiveScaffold(
      safeArea: false,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: _buildMapOptions(),
            children: _buildMapLayers(),
          ),
          if (_controller.isLoadingLocation)
            const Center(child: AdaptiveLoadingIndicator()),
          ActivityRecordingControls(
            state: _activityController.state,
            selectedActivityType: _activityController.selectedActivityType,
            onActivityTypeChanged: _activityController.selectActivityType,
            onStart: _activityController.start,
            onPause: _activityController.pause,
            onResume: _activityController.resume,
            onStop: _confirmStopActivity,
            uploadStatus: _activityController.uploadStatus,
            uploadError: _activityController.uploadError,
            onRetryUpload: _activityController.uploadCompletedGpx,
            onDiscard: _activityController.discard,
          ),
        ],
      ),
      floatingActionButton: AdaptiveFloatingActionButton(
        onPressed: _toggleLocationLock,
        tooltip: l10n.myLocation,
        materialIcon: _controller.isLocationLocked
            ? Icons.my_location
            : Icons.location_searching,
        cupertinoIcon: _controller.isLocationLocked
            ? CupertinoIcons.location_solid
            : CupertinoIcons.location,
      ),
    );
  }
}

/// Blue dot with white border and directional cone
class _LocationMarker extends StatelessWidget {
  const _LocationMarker({required this.heading});

  final double heading;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * math.pi / 180, // Convert degrees to radians
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

/// Custom painter for the location marker
class _LocationMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 5;

    // Draw directional cone (pointing upward when heading is 0)
    final conePaint = Paint()
      ..color = Colors.blue.withValues(
        alpha: LocationMarkerConstants.coneOpacity,
      )
      ..style = PaintingStyle.fill;

    final conePath = ui.Path()
      ..moveTo(center.dx, center.dy) // Center of circle
      ..lineTo(
        center.dx - radius * LocationMarkerConstants.coneWidthMultiplier,
        center.dy - radius * LocationMarkerConstants.coneHeightMultiplier,
      ) // Left point
      ..arcToPoint(
        Offset(
          center.dx + radius * LocationMarkerConstants.coneWidthMultiplier,
          center.dy - radius * LocationMarkerConstants.coneHeightMultiplier,
        ), // Right point
        radius: Radius.circular(
          radius * LocationMarkerConstants.coneArcRadiusMultiplier,
        ),
        clockwise: true,
      )
      ..close();

    canvas.drawPath(conePath, conePaint);

    // Draw white border circle
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      center,
      radius + LocationMarkerConstants.borderWidth,
      borderPaint,
    );

    // Draw blue dot
    final dotPaint = Paint()
      ..color = const Color(LocationMarkerConstants.markerBlue)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
