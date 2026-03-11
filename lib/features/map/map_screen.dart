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
import 'package:endurain/core/utils/activity_upload_feedback_mapper.dart';
import 'package:endurain/core/utils/metric_formatter.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/core/constants/map_constants.dart';
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
  double _heading = 0.0; // Device heading in degrees
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
  void _startCompassUpdates() {
    // Compass is only supported on iOS and Android (not macOS)
    if (PlatformUtils.isMobile) {
      _compassSubscription = FlutterCompass.events?.listen((
        CompassEvent event,
      ) {
        if (mounted && event.heading != null) {
          setState(() {
            _heading = event.heading!;
          });
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
          _mapController.move(_currentLocation, MapConstants.initialLoadZoom);
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
            _mapController.move(newLocation, _mapController.camera.zoom);
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

  /// Toggle location lock
  void _toggleLocationLock() {
    setState(() {
      _isLocationLocked = !_isLocationLocked;
    });

    // If locking, center on current position
    if (_isLocationLocked && _hasLocationPermission) {
      _mapController.move(_currentLocation, _mapController.camera.zoom);
    }
  }

  /// Handle map movement by user - unlock location
  void _onMapMoved() {
    if (_trackingSnapshot.state == TrackingSessionState.recording) {
      return;
    }
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
        _trackingSessionEngine.start(activityType);
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
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l10n.trackingDiscardedActivity)),
      );
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
      final message = (detail != null && detail.isNotEmpty)
          ? '$messageWithStatus - $detail'
          : messageWithStatus;

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
    final message = (detail != null && detail.isNotEmpty)
        ? '$baseMessage - $detail'
        : baseMessage;
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
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(
                    LocationMarkerConstants.buttonOuterPadding,
                  ),
                  child: CupertinoButton.filled(
                    padding: const EdgeInsets.all(
                      LocationMarkerConstants.buttonInnerPadding,
                    ),
                    onPressed: _toggleLocationLock,
                    child: Icon(
                      _isLocationLocked
                          ? CupertinoIcons.location_solid
                          : CupertinoIcons.location,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
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
                ),
              ),
            ),
            if (_trackingSnapshot.state == TrackingSessionState.recording &&
                _isGpsSignalLost)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 172),
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
                    padding: const EdgeInsets.only(top: 12),
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
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
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
              ),
            ),
          ),
          if (_trackingSnapshot.state == TrackingSessionState.recording &&
              _isGpsSignalLost)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 172),
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
                  padding: const EdgeInsets.only(top: 12),
                  child: Chip(
                    avatar: const Icon(Icons.alt_route, size: 16),
                    label: Text(_liveRouteStatusLabel(l10n)),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleLocationLock,
        tooltip: l10n.mapCenterOnLocation,
        child: Icon(
          _isLocationLocked ? Icons.my_location : Icons.location_searching,
        ),
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
