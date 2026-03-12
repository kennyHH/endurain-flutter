import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/models/gps_filter_mode.dart';
import 'package:endurain/core/models/route_display_mode.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/activity_upload_service.dart';
import 'package:endurain/core/services/map_matching_preview_service.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:endurain/core/services/audio_feedback_service.dart';
import 'package:endurain/core/utils/activity_upload_feedback_mapper.dart';
import 'package:endurain/core/utils/metric_formatter.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/core/theme/endurain_design_system.dart';
import 'package:endurain/features/map/widgets/tracking_controls.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.locationService,
    this.storage,
    this.trackingSessionEngine,
    this.uploadService,
    this.onUploadFinished,
    this.routeDisplayMode = RouteDisplayMode.auto,
    this.gpsFilterMode = GpsFilterMode.auto,
    this.suggestedActivityType,
  });

  final LocationService? locationService;
  final SecureStorageService? storage;
  final TrackingSessionEngine? trackingSessionEngine;
  final ActivityUploadService? uploadService;
  final Future<void> Function(Activity activity, bool success)?
  onUploadFinished;
  final RouteDisplayMode routeDisplayMode;
  final GpsFilterMode gpsFilterMode;
  final ActivityType? suggestedActivityType;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _mapMatchingPreviewService = MapMatchingPreviewService();
  static const int _startTrackingCountdownSeconds = 6;
  static const int _requiredStableFixSamples = 3;
  static const double _stableFixAccuracyMeters = 25;
  final MapController _mapController = MapController();
  final LocationService _defaultLocationService = LocationService();
  final SecureStorageService _defaultStorage = SecureStorageService();
  TrackingSessionEngine? _ownedTrackingSessionEngine;
  LatLng _currentLocation = const LatLng(
    MapConstants.defaultLatitude,
    MapConstants.defaultLongitude,
  );
  String _tileServerUrl = MapConstants.defaultTileServerUrl;
  bool _isLoadingLocation = false;
  bool _hasLocationPermission = false;
  bool _isLocationLocked = true; // Track if location is locked to user
  double _heading = 0.0;
  bool _isNorthUp = false; // Device heading in degrees
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<TrackingSessionSnapshot>? _trackingSubscription;
  Timer? _gpsWatchdogTimer;
  Timer? _startCountdownTimer;
  TrackingSessionSnapshot _trackingSnapshot =
      const TrackingSessionSnapshot.idle();
  DateTime? _lastPositionAt;
  int _stableFixCount = 0;
  bool _isGpsSignalLost = false;
  bool _audioEnabled = true;
  int _startCountdownRemaining = 0;

  LocationService get _locationService =>
      widget.locationService ?? _defaultLocationService;
  SecureStorageService get _storage => widget.storage ?? _defaultStorage;
  TrackingSessionEngine get _trackingSessionEngine =>
      widget.trackingSessionEngine ?? _ownedTrackingSessionEngine!;

  @override
  void initState() {
    super.initState();
    if (widget.trackingSessionEngine == null) {
      _ownedTrackingSessionEngine = TrackingSessionEngine(
        repository: InMemoryActivityRepository(),
        positionStreamProvider: LocationServicePositionStreamProvider(
          _locationService,
        ),
        gpsFilterMode: widget.gpsFilterMode,
      );
    }
    _trackingSubscription = _trackingSessionEngine.stream.listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _trackingSnapshot = snapshot;
        if (snapshot.state == TrackingSessionState.idle ||
            snapshot.state == TrackingSessionState.stopped) {
          _isGpsSignalLost = false;
        }
      });
    });
    _loadSettings();
    _loadUserLocation();
    _startCompassUpdates();
    _startGpsWatchdog();
    _audioEnabled = AudioFeedbackService().isEnabled;
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gpsFilterMode != widget.gpsFilterMode) {
      _trackingSessionEngine.setGpsFilterMode(widget.gpsFilterMode);
    }
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    _trackingSubscription?.cancel();
    _gpsWatchdogTimer?.cancel();
    _cancelStartCountdown(updateUi: false);
    _ownedTrackingSessionEngine?.dispose();
    super.dispose();
  }
  /// Start listening to compass heading updates
  /// Start listening to compass heading updates
  void _startCompassUpdates() {
    if (PlatformUtils.isMobile) {
      _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
        if (mounted && event.heading != null) {
          final heading = event.heading!;
          setState(() {
            _heading = heading;
          });
          if (!_isNorthUp && _isLocationLocked) {
             _updateMapCamera(_currentLocation, heading);
          }
        }
      });
    }
  }

  Future<void> _loadSettings() async {
    final tileUrl = await _storage.getTileServerUrl();
    if (mounted && tileUrl != null && tileUrl.isNotEmpty) {
      setState(() {
        _tileServerUrl = tileUrl;
      });
    }
  }

  Future<void> _loadUserLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    // Optimization: Try to get last known position first for immediate fix
    final lastKnown = await _locationService.getLastKnownPosition();
    if (mounted && lastKnown != null) {
      final latLng = LatLng(lastKnown.latitude, lastKnown.longitude);
      // Only update if we are still at default location or if it's a valid fix
      if (_currentLocation.latitude == MapConstants.defaultLatitude) {
         setState(() {
           _currentLocation = latLng;
           _hasLocationPermission = true;
           // Don't stop loading yet, wait for fresh fix
         });
         // Move map immediately
         WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateMapCamera(latLng, _heading);
            }
         });
      }
    }

    final position = await _locationService.getCurrentPosition();

    if (mounted) {
      if (position != null) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _hasLocationPermission = true;
          _isLoadingLocation = false;
        });
        // Wait for next frame to ensure map is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateMapCamera(_currentLocation, _heading);
        });
        // Start continuous position tracking
        _startPositionUpdates();
      } else {
        setState(() {
          _hasLocationPermission = false;
          _isLoadingLocation = false;
        });
      }
    }
  }

  /// Start listening to continuous position updates
  void _startPositionUpdates() {
    _positionSubscription = _locationService.getPositionStream().listen(
      (Position position) {
        if (mounted) {
          final newLocation = LatLng(position.latitude, position.longitude);
          setState(() {
            _currentLocation = newLocation;
            _lastPositionAt = DateTime.now();
            final accuracy = position.accuracy;
            final isStableFix =
                accuracy.isFinite &&
                accuracy > 0 &&
                accuracy <= _stableFixAccuracyForMode;
            _stableFixCount = isStableFix ? (_stableFixCount + 1) : 0;
            _isGpsSignalLost = false;
          });

          // If location is locked, move map to follow user
          if (_isLocationLocked) {
            _updateMapCamera(newLocation, _heading);
          }
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isGpsSignalLost = true;
        });
      },
    );
  }

  void _startGpsWatchdog() {
    _gpsWatchdogTimer?.cancel();
    _gpsWatchdogTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final isTracking =
          _trackingSnapshot.state == TrackingSessionState.recording;
      if (!isTracking) {
        if (_isGpsSignalLost) {
          setState(() {
            _isGpsSignalLost = false;
          });
        }
        return;
      }
      final lastPositionAt = _lastPositionAt;
      final lost =
          lastPositionAt == null ||
          DateTime.now().difference(lastPositionAt) >
              const Duration(seconds: 12);
      if (lost != _isGpsSignalLost) {
        setState(() {
          _isGpsSignalLost = lost;
        });
      }
    });
  }

  /// Center map on user location and keep position visible.
    void _toggleAudio() {
    setState(() {
      _audioEnabled = !_audioEnabled;
    });
    AudioFeedbackService().toggleEnabled(_audioEnabled);
  }

        void _toggleCompassMode() {
    setState(() {
      _isNorthUp = !_isNorthUp;
      _isLocationLocked = true; // Re-lock and center on mode switch
    });
    // Immediate smooth transition
    _updateMapCamera(_currentLocation, _heading);
  }


  



  /// Keep user marker visible even while interacting with the map.
  
  void _updateMapCamera(LatLng location, double heading) {
    if (!_isLocationLocked) return;

    final double targetRotation = _isNorthUp ? 0.0 : -heading;
    final double currentZoom = _mapController.camera.zoom;
    
    // Shift center to keep user in upper part (visually centered above UI)
    final shiftedCenter = _calculateShiftedCenter(location, currentZoom, targetRotation);
    
    // Use moveAndRotate if available. Assuming flutter_map 6+.
    // If not, try-catch or separate calls. 
    // Since we don't know the exact version, let's use move and rotate separately if needed,
    // but moveAndRotate is standard now.
    try {
      _mapController.moveAndRotate(shiftedCenter, currentZoom, targetRotation);
    } catch (_) {
      _mapController.move(shiftedCenter, currentZoom);
      _mapController.rotate(targetRotation);
    }
  }

  LatLng _calculateShiftedCenter(LatLng userLoc, double zoom, double rotationDeg) {
    // Shift map center "down" so user appears "up"
    // 15% screen height shift
    // This is approximate but effective for standard projections
    
    // We need to move the center point from UserLoc in direction (Rotation + 180)
    // Distance in meters corresponding to 15% screen height pixels
    
    // Simple Approximation:
    // At zoom 15, ~4 meters/pixel (equator)
    // Resolution = 156543.03 * cos(lat) / 2^zoom
    
    final latRad = userLoc.latitude * (math.pi / 180.0);
    final resolution = 156543.03 * math.cos(latRad) / math.pow(2, zoom);
    
    // Shift pixels (e.g., 100px)
    // We don't have context size easily here without LayoutBuilder context or MediaQuery.
    // But we are in a State class, so context is available.
    double screenHeight = 800; // Default fallback
    if (mounted) {
       screenHeight = MediaQuery.of(context).size.height;
    }
    
    final shiftPixels = screenHeight * 0.15; 
    final shiftMeters = shiftPixels * resolution;
    
    // Bearing (radians) - Screen Down is +180 relative to Screen Up (0)
    // Screen Up is -Rotation relative to North.
    // So Screen Down is -Rotation + 180 relative to North.
    // Wait.
    // Map Rotation R means North is rotated R degrees clockwise?
    // Usually standard map rotation: 0 = North Up. 90 = East Up.
    // If Map is rotated -90 (West Up), North is to the Right.
    // Screen Down is always +180 relative to Screen Up.
    // Screen Up corresponds to bearing -R on map?
    // Let's test: R=0 (North Up). Screen Up = North (0). Screen Down = South (180). Correct.
    // R=90 (East Up). Screen Up = East (90). Screen Down = West (270).
    // Formula: Bearing = -R + 180?
    // If R=90, -90+180 = 90 (East). Wrong.
    // If Map is rotated 90 deg clockwise, North is at 3 o'clock.
    // Up is West (270). Down is East (90).
    // Rotation usually means camera rotation.
    // If Camera Rot = 90, Heading = 90.
    // Map rotates -90.
    // Let's trust `rotationDeg` passed in which is `_mapController.rotation`.
    // If rotation is 0, Up is North. Down is South (180).
    // If rotation is 90, Up is West? (Map rotates CW).
    // Let's use `radians = (rotationDeg + 180) * (pi/180)`?
    // If R=0 -> 180 (South). Correct.
    // If R=90 -> 270 (West).
    // Let's verify standard behavior.
    
    // Actually, flutter_map rotation:
    // 0 = North Up.
    // 90 = North is Right. (Map rotated CW).
    // So Up is West (270). Down is East (90).
    // My formula `(R + 180)` gives `270`. Which is West.
    // Wait. `R=90`. `90+180=270`.
    // If `R=90` (North Right), Up is West (270). Down is East (90).
    // So `R+180` gives West (Up). We want Down.
    // So `R` gives Down?
    // If `R=90`, `90` is East (Down). Yes!
    // If `R=0`, `0` is North (Up). No, we want Down (South, 180).
    // So `R + 180`?
    // If `R=0`, `180` is South (Down). Correct.
    // If `R=90`, `270` is West (Up). Wrong.
    
    // Let's rethink.
    // Vector pointing UP on screen corresponds to bearing `-rotation` on map.
    // Vector pointing DOWN on screen corresponds to bearing `-rotation + 180`.
    
    final bearingRad = (-rotationDeg + 180) * (math.pi / 180.0);
    
    // Destination point
    const earthRadius = 6378137.0;
    final dLat = (shiftMeters / earthRadius) * math.cos(bearingRad);
    final dLon = (shiftMeters / earthRadius) * math.sin(bearingRad) / math.cos(latRad);
    
    return LatLng(
      userLoc.latitude + (dLat * 180 / math.pi),
      userLoc.longitude + (dLon * 180 / math.pi),
    );
  }


    void _onMapMoved() {
    // Unlock if user manually drags map
    if (_isLocationLocked) {
      setState(() {
        _isLocationLocked = false;
      });
    }
  }

  /// Build map options with common configuration
  MapOptions _buildMapOptions() {
    return MapOptions(
      initialCenter: _currentLocation,
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

  bool get _useMatchedRoutePreview =>
      widget.routeDisplayMode != RouteDisplayMode.raw;

  String _liveRouteStatusLabel(AppLocalizations l10n) {
    if (!_useMatchedRoutePreview) return l10n.routeStatusRaw;
    if (_trackingSnapshot.trackPoints.length < 3) return l10n.routeStatusRaw;
    // Live map uses local smoothing during recording; persisted sessions can
    // later be OSRM-matched in history/detail.
    return l10n.routeStatusFallback;
  }

  /// Build map layers (tile + marker)
  List<Widget> _buildMapLayers() {
    final displayTrackPoints = _mapMatchingPreviewService.pointsForDisplay(
      rawPoints: _trackingSnapshot.trackPoints,
      useMatchedPreview: _useMatchedRoutePreview,
    );
    final routeOutline = Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.92);
    const routeAccent = Color(0xFFFF5A1F);
    return [
      TileLayer(
        urlTemplate: _tileServerUrl,
        userAgentPackageName: MapConstants.userAgent,
      ),
      if (displayTrackPoints.length > 1)
        PolylineLayer(
          polylines: [
            Polyline(
              points: displayTrackPoints
                  .map((point) => LatLng(point.latitude, point.longitude))
                  .toList(),
              strokeWidth: 8,
              color: routeOutline,
            ),
            Polyline(
              points: displayTrackPoints
                  .map((point) => LatLng(point.latitude, point.longitude))
                  .toList(),
              strokeWidth: 4,
              color: routeAccent,
            ),
          ],
        ),
      if (displayTrackPoints.isNotEmpty)
        MarkerLayer(
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
        ),
      if (_hasLocationPermission)
        MarkerLayer(
          markers: [
            Marker(
              point: _currentLocation,
              width: LocationMarkerConstants.markerSize,
              height: LocationMarkerConstants.markerSize,
              alignment: Alignment.center,
              child: _LocationMarker(heading: _heading),
            ),
          ],
        ),
    ];
  }

  void _handleStartTracking(ActivityType activityType) {
    if (!_hasLocationPermission) {
      _showTrackingPermissionError();
      return;
    }
    if (_trackingSnapshot.state == TrackingSessionState.recording ||
        _trackingSnapshot.state == TrackingSessionState.paused ||
        _isPreparingStart) {
      return;
    }
    if (!_hasStableStartFix) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.trackingGpsNeedStableFix)));
      return;
    }
    HapticFeedback.selectionClick();
    _beginStartCountdown(activityType);
  }

  bool get _hasRecentGpsFix {
    final lastPositionAt = _lastPositionAt;
    if (lastPositionAt == null || !_hasLocationPermission) return false;
    return DateTime.now().difference(lastPositionAt) <=
        const Duration(seconds: 4);
  }

  bool get _hasStableStartFix =>
      _hasRecentGpsFix && _stableFixCount >= _requiredStableFixSamplesForMode;

  int get _requiredStableFixSamplesForMode {
    return switch (widget.gpsFilterMode) {
      GpsFilterMode.strict => 4,
      GpsFilterMode.normal => 2,
      GpsFilterMode.auto => _requiredStableFixSamples,
    };
  }

  double get _stableFixAccuracyForMode {
    return switch (widget.gpsFilterMode) {
      GpsFilterMode.strict => 20,
      GpsFilterMode.normal => 30,
      GpsFilterMode.auto => _stableFixAccuracyMeters,
    };
  }

  bool get _isPreparingStart => _startCountdownRemaining > 0;

  void _beginStartCountdown(ActivityType activityType) {
    _cancelStartCountdown();
    setState(() {
      _startCountdownRemaining = _startTrackingCountdownSeconds;
    });
    
    // Start Engine countdown immediately (it handles audio and delay)
    // We don't await it here so UI timer can run in parallel
    unawaited(_trackingSessionEngine.start(activityType, useCountdown: true));
    
    _startCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_startCountdownRemaining <= 1) {
        timer.cancel();
        setState(() {
          _startCountdownRemaining = 0;
        });
        HapticFeedback.mediumImpact();
        return;
      }
      setState(() {
        _startCountdownRemaining -= 1;
      });
    });
  }

  void _cancelStartCountdown({bool updateUi = true}) {
    _startCountdownTimer?.cancel();
    _startCountdownTimer = null;
    if (updateUi && _startCountdownRemaining != 0 && mounted) {
      setState(() {
        _startCountdownRemaining = 0;
      });
    } else if (!updateUi) {
      _startCountdownRemaining = 0;
    }
  }

  Future<void> _handlePauseTracking() async {
    await _trackingSessionEngine.pause();
    await HapticFeedback.lightImpact();
  }

  Future<void> _handleResumeTracking() async {
    await _trackingSessionEngine.resume();
    await HapticFeedback.lightImpact();
  }

  Future<void> _handleStopTracking() async {
    final activity = await _trackingSessionEngine.stop();
    if (activity == null) return;
    final shouldSave = await _confirmSuspiciousSaveIfNeeded(activity);
    if (!shouldSave) {
      await _trackingSessionEngine.deleteSavedActivity(activity.id);
      await _trackingSessionEngine.reset();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.trackingDiscardedActivity)));
      return;
    }
    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    _showSaveCelebration();

    try {
      final uploadService = widget.uploadService;
      if (uploadService == null) return;
      final l10n = AppLocalizations.of(context)!;
      final messenger = ScaffoldMessenger.maybeOf(context);

      final result = await uploadService.uploadActivity(activity);
      if (!mounted) return;
      await widget.onUploadFinished?.call(activity, result.success);
      final baseMessage = ActivityUploadFeedbackMapper.toUserMessage(
        result,
        l10n,
      );
      final detail = result.serverDetail;
      final messageWithStatus = (!result.success && result.statusCode != null)
          ? '$baseMessage (HTTP ${result.statusCode})'
          : baseMessage;
      final message = result.success
          ? baseMessage
          : ((detail != null && detail.isNotEmpty)
                ? '$messageWithStatus - $detail'
                : messageWithStatus);

      if (messenger == null) return;
      if (!result.success) {
        await HapticFeedback.heavyImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: l10n.trackingRetryInBackground,
              onPressed: () {
                unawaited(_retryUploadInBackground(activity));
              },
            ),
          ),
        );
      } else {
        await HapticFeedback.lightImpact();
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      // After stop, always reset UI state so a new activity starts from zero.
      await _trackingSessionEngine.reset();
    }
  }

  bool _isSuspiciousActivity(Activity activity) {
    final duration = activity.durationSeconds;
    final distance = activity.distanceMeters;
    if (duration < 20 || distance < 50) return true;
    final speed = activity.averageSpeedKmh;
    if (speed == null) return false;
    if (activity.activityType == ActivityType.ride) return speed > 80;
    return speed > 30;
  }

  Future<bool> _confirmSuspiciousSaveIfNeeded(Activity activity) async {
    if (!_isSuspiciousActivity(activity) || !mounted) return true;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trackingSuspiciousSaveTitle),
        content: Text(
          l10n.trackingSuspiciousSaveMessage(
            MetricFormatter.formatDurationLabeled(activity.durationSeconds),
            MetricFormatter.formatDistanceKm(
              activity.distanceMeters,
              l10n.trackingDistanceUnitKm,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.trackingDiscardAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _retryUploadInBackground(Activity activity) async {
    final uploadService = widget.uploadService;
    if (uploadService == null) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await uploadService.uploadActivity(activity);
    if (!mounted) return;
    await widget.onUploadFinished?.call(activity, result.success);
    final baseMessage = ActivityUploadFeedbackMapper.toUserMessage(
      result,
      l10n,
    );
    final detail = result.serverDetail;
    final message = result.success
        ? baseMessage
        : ((detail != null && detail.isNotEmpty)
              ? '$baseMessage - $detail'
              : baseMessage);
    if (messenger == null) return;
    if (result.success) {
      await HapticFeedback.lightImpact();
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSaveCelebration() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1300),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.celebration_rounded, size: 18),
            const SizedBox(width: 8),
            Text(l10n.trackingActivitySavedCelebration),
          ],
        ),
      ),
    );
  }

  void _showTrackingPermissionError() {
    final l10n = AppLocalizations.of(context)!;
    if (PlatformUtils.isApplePlatform) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(l10n.error),
          content: Text(l10n.trackingPermissionRequired),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.trackingPermissionRequired)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Cupertino style for iOS/macOS
    if (PlatformUtils.isApplePlatform) {
      return CupertinoPageScaffold(
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: _buildMapOptions(),
              children: _buildMapLayers(),
            ),
            if (_isLoadingLocation)
              const Center(child: CupertinoActivityIndicator()),
            // Position button with SafeArea to avoid tab bar
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(
                    LocationMarkerConstants.buttonOuterPadding,
                  ),
                  child: CupertinoButton.filled(
                    color: const Color(0xCC16212B),
                    padding: const EdgeInsets.all(
                      LocationMarkerConstants.buttonInnerPadding,
                    ),
                    onPressed: _toggleAudio,
                    child: Tooltip(
                      message: _audioEnabled ? "Mute Voice Coach" : "Enable Voice Coach", // TODO: Localize
                      child: Icon(
                        _audioEnabled
                            ? CupertinoIcons.volume_up
                            : CupertinoIcons.volume_off,
                        color: const Color(0xFF1FC8B6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(
                    LocationMarkerConstants.buttonOuterPadding,
                  ),
                  child: CupertinoButton.filled(
                    color: const Color(0xCC16212B),
                    padding: const EdgeInsets.all(
                      LocationMarkerConstants.buttonInnerPadding,
                    ),
                    onPressed: _toggleCompassMode,
                    child: Tooltip(
                    message: _isNorthUp ? "Map is North Up. Tap to follow heading." : "Map follows heading. Tap to lock North Up.", // TODO: Localize
                    child: _isNorthUp
                        ? const Icon(
                            CupertinoIcons.compass,
                            color: Color(0xFF1FC8B6),
                          )
                        : Transform.rotate(
                            angle: (_heading * math.pi / 180) * -1,
                            child: const Icon(
                              CupertinoIcons.location_north_fill,
                              color: Color(0xFF1FC8B6),
                            ),
                          ),
                  ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    EndurainSpacing.sm,
                    EndurainSpacing.sm,
                    EndurainSpacing.sm,
                    62,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final controlsNeedExtraHeight =
                          _trackingSnapshot.state ==
                              TrackingSessionState.recording ||
                          _trackingSnapshot.state ==
                              TrackingSessionState.paused;
                      final compactHeight = constraints.maxHeight <= 700;
                      final heightFactor = compactHeight
                          ? (controlsNeedExtraHeight ? 0.53 : 0.49)
                          : (controlsNeedExtraHeight ? 0.48 : 0.44);
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: FractionallySizedBox(
                          heightFactor: heightFactor,
                          alignment: Alignment.bottomCenter,
                          child: TrackingControls(
                            snapshot: _trackingSnapshot,
                            suggestedActivityType: widget.suggestedActivityType,
                            hasGpsFix: _hasStableStartFix,
                            isPreparingStart: _isPreparingStart,
                            startCountdownSeconds: _startCountdownRemaining,
                            onStart: _handleStartTracking,
                            onPause: () {
                              unawaited(_handlePauseTracking());
                            },
                            onResume: () {
                              unawaited(_handleResumeTracking());
                            },
                            onStop: () {
                              unawaited(_handleStopTracking());
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (_trackingSnapshot.state == TrackingSessionState.recording &&
                _isGpsSignalLost)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      EndurainSpacing.xl,
                      EndurainSpacing.sm,
                      EndurainSpacing.xl,
                      172,
                    ),
                    child: _GpsSignalWarningBanner(
                      message: l10n.trackingGpsSignalLost,
                    ),
                  ),
                ),
              ),
            if (_useMatchedRoutePreview &&
                _trackingSnapshot.state == TrackingSessionState.recording)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: EndurainSpacing.sm),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey5,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.map_pin_ellipse,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _liveRouteStatusLabel(l10n),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Material style for Android
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: _buildMapOptions(),
            children: _buildMapLayers(),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  EndurainSpacing.sm,
                  EndurainSpacing.sm,
                  EndurainSpacing.sm,
                  62,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final controlsNeedExtraHeight =
                        _trackingSnapshot.state ==
                            TrackingSessionState.recording ||
                        _trackingSnapshot.state == TrackingSessionState.paused;
                    final compactHeight = constraints.maxHeight <= 700;
                    final heightFactor = compactHeight
                        ? (controlsNeedExtraHeight ? 0.53 : 0.49)
                        : (controlsNeedExtraHeight ? 0.48 : 0.44);
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: FractionallySizedBox(
                        heightFactor: heightFactor,
                        alignment: Alignment.bottomCenter,
                        child: TrackingControls(
                          snapshot: _trackingSnapshot,
                          suggestedActivityType: widget.suggestedActivityType,
                          hasGpsFix: _hasStableStartFix,
                          isPreparingStart: _isPreparingStart,
                          startCountdownSeconds: _startCountdownRemaining,
                          onStart: _handleStartTracking,
                          onPause: () {
                            unawaited(_handlePauseTracking());
                          },
                          onResume: () {
                            unawaited(_handleResumeTracking());
                          },
                          onStop: () {
                            unawaited(_handleStopTracking());
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (_trackingSnapshot.state == TrackingSessionState.recording &&
              _isGpsSignalLost)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    EndurainSpacing.xl,
                    EndurainSpacing.sm,
                    EndurainSpacing.xl,
                    172,
                  ),
                  child: _GpsSignalWarningBanner(
                    message: l10n.trackingGpsSignalLost,
                  ),
                ),
              ),
            ),
          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator()),
          if (_useMatchedRoutePreview &&
              _trackingSnapshot.state == TrackingSessionState.recording)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: EndurainSpacing.sm),
                  child: Chip(
                    avatar: const Icon(Icons.alt_route, size: 16),
                    label: Text(_liveRouteStatusLabel(l10n)),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(
                  LocationMarkerConstants.buttonOuterPadding,
                ),
                child: FloatingActionButton.small(
                  heroTag: 'audio_toggle', // Unique tag
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHigh,
                  foregroundColor: _audioEnabled 
                      ? Theme.of(context).colorScheme.primary 
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  onPressed: _toggleAudio,
                  tooltip: _audioEnabled ? "Mute Voice Coach" : "Enable Voice Coach", // TODO: Localize
                  child: Icon(_audioEnabled ? Icons.volume_up : Icons.volume_off),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(
                  LocationMarkerConstants.buttonOuterPadding,
                ),
                child: FloatingActionButton.small(
                  heroTag: 'compass_btn',
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHigh,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: _toggleCompassMode,
                  tooltip: _isNorthUp ? "Map is North Up" : "Follow Heading", // TODO: Localize
                  child: _isNorthUp
                      ? const Icon(Icons.explore) // Compass
                      : Transform.rotate(
                          angle: (_heading * math.pi / 180) * -1,
                          child: const Icon(Icons.navigation), // Arrow
                        ),
                ),
              ),
            ),
          ),
        ],
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

class _GpsSignalWarningBanner extends StatelessWidget {
  const _GpsSignalWarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isApplePlatform) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.systemYellow.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.location_slash, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.gps_off_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
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
