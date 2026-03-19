import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/models/dynamic_map_zoom_preset.dart';
import 'package:endurain/core/models/gps_filter_mode.dart';
import 'package:endurain/core/models/route_display_mode.dart';
import 'package:endurain/core/services/activity_upload_service.dart';
import 'package:endurain/core/services/audio_feedback_service.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:endurain/core/services/power_management_service.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/core/constants/map_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, LocationPermission;
import 'package:latlong2/latlong.dart';
import 'package:endurain/features/map/controllers/dynamic_map_zoom_policy.dart';

class _BootstrapSeed {
  const _BootstrapSeed({required this.location, required this.source});

  final LatLng location;
  final String source;
}

enum GpsStartupState {
  idle,
  permissionPending,
  serviceDisabled,
  permissionDenied,
  bootstrapSeeded,
  liveFixConfirmed,
  streamingReady,
  uiReady,
}

class MapScreenController extends ChangeNotifier {
  MapScreenController({
    required this.locationService,
    required this.storage,
    required this.trackingSessionEngine,
    required this.audioFeedbackService,
    required this.powerManagementService,
    this.uploadService,
    this.routeDisplayMode = RouteDisplayMode.auto,
    this.gpsFilterMode = GpsFilterMode.auto,
  }) {
    _init();
  }

  final LocationService locationService;
  final SecureStorageService storage;
  final TrackingSessionEngine trackingSessionEngine;
  final AudioFeedbackService audioFeedbackService;
  final PowerManagementService powerManagementService;
  final ActivityUploadService? uploadService;
  final RouteDisplayMode routeDisplayMode;
  final GpsFilterMode gpsFilterMode;

  // State
  final MapController mapController = MapController();
  LatLng currentLocation = const LatLng(
    MapConstants.defaultLatitude,
    MapConstants.defaultLongitude,
  );
  String tileServerUrl = MapConstants.defaultTileServerUrl;
  bool isLoadingLocation = false;
  bool hasLocationPermission = false;
  bool isLocationLocked = true;
  double heading = 0.0;
  bool isNorthUp = false;
  bool isGpsSignalLost = false;
  bool isBatteryOptimizationIgnored = true;
  bool shouldShowPermissionOnboarding = false;
  bool isRunningPermissionOnboarding = false;
  GpsStartupState gpsStartupState = GpsStartupState.idle;
  bool audioEnabled = true;
  bool dynamicMapZoomEnabled = true;
  DynamicMapZoomPreset dynamicMapZoomPreset = DynamicMapZoomPreset.balanced;
  TrackingSessionSnapshot trackingSnapshot =
      const TrackingSessionSnapshot.idle();

  bool _isDisposed = false;
  bool _isPreparingStartLocal = false;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<TrackingSessionSnapshot>? _trackingSubscription;
  StreamSubscription<bool>? _audioEnabledSubscription;
  DateTime? _lastDerivedPositionAt;
  DateTime? _bootstrapFixAt;
  DateTime? _lastCompassUpdateAt;
  LatLng? _lastCourseHeadingSample;
  bool _hasStableBootstrapFix = false;
  int _stableFixCount = 0;
  DynamicMapZoomPolicy _dynamicZoomPolicy = DynamicMapZoomPolicy();
  final String _gpsDiagSessionId = _buildGpsDiagSessionId();
  DateTime? _gpsInitStartedAt;

  static const int _requiredStableFixSamples = 3;
  static const double _stableFixAccuracyMeters = 25;
  static const Duration _compassFreshnessWindow = Duration(seconds: 4);
  static const double _courseFallbackMinDistanceMeters = 6.0;
  static const double _courseFallbackMinSpeedMetersPerSecond = 1.6;
  static const double _courseFallbackMaxAccuracyMeters = 15.0;

  bool get shouldRenderUserLocation =>
      hasLocationPermission && gpsStartupState == GpsStartupState.uiReady;

  @override
  void dispose() {
    _isDisposed = true;
    powerManagementService.disableWakelock();
    _trackingSubscription?.cancel();
    _compassSubscription?.cancel();
    _audioEnabledSubscription?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void _init() {
    _gpsInitStartedAt = DateTime.now().toUtc();
    _logGpsDiag('controller_init');
    _setGpsStartupState(GpsStartupState.permissionPending, reason: 'init');
    _trackingSubscription = trackingSessionEngine.stream.listen((snapshot) {
      trackingSnapshot = snapshot;
      final latestPosition = snapshot.latestPosition;
      if (latestPosition != null &&
          _lastDerivedPositionAt != latestPosition.timestamp) {
        if (!hasLocationPermission) {
          hasLocationPermission = true;
          _logGpsDiag(
            'permission_healed_from_stream',
            details: <String, Object?>{
              'timestamp': latestPosition.timestamp.toIso8601String(),
            },
          );
        }
        _lastDerivedPositionAt = latestPosition.timestamp;
        _bootstrapFixAt = latestPosition.timestamp;
        currentLocation = LatLng(
          latestPosition.latitude,
          latestPosition.longitude,
        );
        _updateHeadingFromCourseIfNeeded(
          currentLocation,
          speedMetersPerSecond: latestPosition.speed,
          horizontalAccuracyMeters: latestPosition.horizontalAccuracyMeters,
        );
        storage.setLastLocation(
          latestPosition.latitude,
          latestPosition.longitude,
        );
        final accuracy = latestPosition.horizontalAccuracyMeters;
        final isStableFix =
            accuracy != null &&
            accuracy.isFinite &&
            accuracy > 0 &&
            accuracy <= _stableFixAccuracyForMode;
        _stableFixCount = isStableFix ? (_stableFixCount + 1) : 0;
        if (isStableFix) {
          _hasStableBootstrapFix = true;
        }
        if (isLocationLocked) {
          final currentZoom = mapController.camera.zoom;
          final speedKmh = (latestPosition.speed ?? 0) * 3.6;
          final effectiveZoom = _resolveDynamicZoom(
            speedKmh: speedKmh,
            timestamp: latestPosition.timestamp,
            currentZoom: currentZoom,
          );
          _updateMapCamera(
            currentLocation,
            heading,
            zoomOverride: effectiveZoom,
          );
        }
        _setGpsStartupState(
          GpsStartupState.streamingReady,
          reason: 'tracking_stream_position',
        );
        _logGpsDiag(
          'stream_position_received',
          details: <String, Object?>{
            'lat': latestPosition.latitude,
            'lng': latestPosition.longitude,
            'accuracy': latestPosition.horizontalAccuracyMeters,
            'speed': latestPosition.speed,
          },
        );
        _promoteGpsStartupUiReadyIfPossible();
      }
      if (snapshot.state != TrackingSessionState.initializing &&
          _isPreparingStartLocal) {
        _isPreparingStartLocal = false;
      }
      isGpsSignalLost = snapshot.isGpsSignalLost;
      notifyListeners();
    });

    _loadSettings();
    _loadUserLocation(requestPermissionIfNeeded: false);
    _startCompassUpdates();
    _initPowerManagement();
    _evaluatePermissionOnboarding();
    _syncAudioStateFromStorage();
    _audioEnabledSubscription = audioFeedbackService.enabledStream.listen((
      enabled,
    ) {
      if (audioEnabled == enabled) return;
      audioEnabled = enabled;
      notifyListeners();
    });
    _syncDynamicZoomConfigFromStorage();
  }

  Future<void> _syncAudioStateFromStorage() async {
    final enabledRaw = await storage.read(key: 'audio_enabled');
    audioEnabled = enabledRaw == null
        ? audioFeedbackService.isEnabled
        : enabledRaw == 'true';
    audioFeedbackService.toggleEnabled(audioEnabled);
    notifyListeners();
  }

  Future<void> _syncDynamicZoomConfigFromStorage() async {
    final raw = await storage.read(key: 'dynamic_map_zoom_enabled');
    dynamicMapZoomEnabled = raw == null ? true : raw == 'true';
    final presetRaw = await storage.read(key: 'dynamic_map_zoom_preset');
    dynamicMapZoomPreset = dynamicMapZoomPresetFromStorage(presetRaw);
    _dynamicZoomPolicy = DynamicMapZoomPolicy(preset: dynamicMapZoomPreset);
    if (!dynamicMapZoomEnabled) {
      _dynamicZoomPolicy.reset();
    }
    notifyListeners();
  }

  Future<void> _initPowerManagement() async {
    await powerManagementService.enableWakelock();
    await _refreshBatteryOptimizationStatus();
  }

  Future<void> _evaluatePermissionOnboarding() async {
    final completed = await storage.getPermissionsOnboardingCompleted();
    shouldShowPermissionOnboarding = !completed;
    notifyListeners();
  }

  Future<void> skipPermissionOnboarding() async {
    await storage.setPermissionsOnboardingCompleted(true);
    shouldShowPermissionOnboarding = false;
    notifyListeners();
  }

  Future<void> runPermissionOnboardingSetup() async {
    if (isRunningPermissionOnboarding) return;
    isRunningPermissionOnboarding = true;
    notifyListeners();
    try {
      await _requestLocationPermissionForOnboarding();
      await _requestBatteryOptimizationForOnboarding();
      final completed = hasLocationPermission;
      await storage.setPermissionsOnboardingCompleted(completed);
      shouldShowPermissionOnboarding = !completed;
    } finally {
      isRunningPermissionOnboarding = false;
      notifyListeners();
    }
  }

  Future<void> _requestLocationPermissionForOnboarding() async {
    final serviceEnabled = await locationService.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await locationService.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await locationService.requestPermission();
    }
    hasLocationPermission =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    if (hasLocationPermission) {
      await _loadUserLocation(requestPermissionIfNeeded: false);
    }
  }

  Future<void> _requestBatteryOptimizationForOnboarding() async {
    if (!PlatformUtils.isAndroid) return;
    await powerManagementService.requestBatteryExemption();
    await _refreshBatteryOptimizationStatus();
  }

  Future<void> _refreshBatteryOptimizationStatus() async {
    if (!PlatformUtils.isAndroid) {
      isBatteryOptimizationIgnored = true;
      notifyListeners();
      return;
    }
    final current = await powerManagementService.isBatteryOptimizationIgnored();
    if (current != isBatteryOptimizationIgnored) {
      isBatteryOptimizationIgnored = current;
      notifyListeners();
    }
  }

  void updateGpsFilterMode(GpsFilterMode mode) {
    if (gpsFilterMode != mode) {
      trackingSessionEngine.setGpsFilterMode(mode);
    }
  }

  Future<void> checkLocationPermission() async {
    await _refreshBatteryOptimizationStatus();
    final permission = await locationService.checkPermission();
    final hasPermission =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    final permissionChanged = hasPermission != hasLocationPermission;
    hasLocationPermission = hasPermission;

    if (!hasPermission) {
      _setGpsStartupState(
        GpsStartupState.permissionDenied,
        reason: 'lifecycle_permission_check_denied',
      );
      notifyListeners();
      return;
    }

    final shouldReinitialize =
        permissionChanged ||
        gpsStartupState == GpsStartupState.permissionPending ||
        gpsStartupState == GpsStartupState.permissionDenied ||
        gpsStartupState == GpsStartupState.serviceDisabled ||
        !hasRecentGpsFix;
    _logGpsDiag(
      'lifecycle_permission_check',
      details: <String, Object?>{
        'permission_changed': permissionChanged,
        'should_reinitialize': shouldReinitialize,
        'permission': permission.name,
      },
    );
    if (shouldReinitialize) {
      await _loadUserLocation(requestPermissionIfNeeded: false);
    } else {
      notifyListeners();
    }
  }

  Future<void> _loadSettings() async {
    final tileUrl = await storage.getTileServerUrl();
    if (tileUrl != null && tileUrl.isNotEmpty) {
      tileServerUrl = tileUrl;
      notifyListeners();
    }
  }

  Future<void> _loadUserLocation({
    required bool requestPermissionIfNeeded,
  }) async {
    _setGpsStartupState(
      GpsStartupState.permissionPending,
      reason: 'load_user_location',
    );
    isLoadingLocation = true;
    notifyListeners();

    try {
      _logGpsDiag(
        'location_init_started',
        details: <String, Object?>{
          'request_permission_if_needed': requestPermissionIfNeeded,
        },
      );
      final serviceEnabled = await locationService.isLocationServiceEnabled();
      _logGpsDiag(
        'location_service_checked',
        details: <String, Object?>{'enabled': serviceEnabled},
      );
      if (!serviceEnabled) {
        _setGpsStartupState(
          GpsStartupState.serviceDisabled,
          reason: 'location_service_disabled',
        );
        isLoadingLocation = false;
        notifyListeners();
        return;
      }

      var permission = await locationService.checkPermission();
      _logGpsDiag(
        'permission_checked',
        details: <String, Object?>{'permission': permission.name},
      );
      if (requestPermissionIfNeeded &&
          permission == LocationPermission.denied) {
        permission = await locationService.requestPermission();
        _logGpsDiag(
          'permission_requested',
          details: <String, Object?>{'permission': permission.name},
        );
      }

      final hasPermission =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      hasLocationPermission = hasPermission;

      if (!hasPermission) {
        _setGpsStartupState(
          GpsStartupState.permissionDenied,
          reason: 'location_permission_denied',
        );
        isLoadingLocation = false;
        notifyListeners();
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      final cachedLocFuture = storage.getLastLocation();
      final lastKnownFuture = locationService.getLastKnownPosition();

      final seed = await Future.any<_BootstrapSeed?>([
        cachedLocFuture.then((cachedLoc) {
          if (cachedLoc == null) return null;
          final (lat, lng) = cachedLoc;
          return _BootstrapSeed(location: LatLng(lat, lng), source: 'storage');
        }),
        lastKnownFuture.then((lastKnown) {
          if (lastKnown == null) return null;
          _registerBootstrapFix(
            timestamp: lastKnown.timestamp,
            horizontalAccuracyMeters: lastKnown.accuracy,
          );
          return _BootstrapSeed(
            location: LatLng(lastKnown.latitude, lastKnown.longitude),
            source: 'lastKnown',
          );
        }),
        Future<_BootstrapSeed?>.delayed(
          const Duration(milliseconds: 800),
          () => null,
        ),
      ]);

      if (seed != null) {
        _applyBootstrapLocation(seed.location, source: seed.source);
      } else {
        _logGpsDiag('bootstrap_seed_unavailable');
      }

      final position = await locationService.getCurrentPosition();
      if (position != null) {
        _registerBootstrapFix(
          timestamp: position.timestamp,
          horizontalAccuracyMeters: position.accuracy,
        );
        _applyLiveLocation(
          LatLng(position.latitude, position.longitude),
          source: 'singleFix',
        );
      } else {
        _logGpsDiag('single_fix_unavailable');
      }
    } catch (e) {
      _logGpsDiag(
        'location_init_error',
        details: <String, Object?>{'error': e.toString()},
      );
    } finally {
      if (isLoadingLocation) {
        isLoadingLocation = false;
        notifyListeners();
      }
      final startedAt = _gpsInitStartedAt;
      if (startedAt != null) {
        final elapsedMs = DateTime.now()
            .toUtc()
            .difference(startedAt)
            .inMilliseconds;
        _logGpsDiag(
          'location_init_finished',
          details: <String, Object?>{'elapsed_ms': elapsedMs},
        );
      }
    }
  }

  void _applyBootstrapLocation(LatLng latLng, {required String source}) {
    if (!_isCurrentLocationDefault()) return;
    currentLocation = latLng;
    _lastCourseHeadingSample = latLng;
    _setGpsStartupState(GpsStartupState.bootstrapSeeded, reason: source);
    _logGpsDiag(
      'bootstrap_location_applied',
      details: <String, Object?>{
        'source': source,
        'lat': latLng.latitude,
        'lng': latLng.longitude,
      },
    );
    notifyListeners();
    _updateMapCamera(latLng, heading);
    _promoteGpsStartupUiReadyIfPossible();
  }

  void _applyLiveLocation(LatLng latLng, {required String source}) {
    currentLocation = latLng;
    _lastCourseHeadingSample = latLng;
    _setGpsStartupState(GpsStartupState.liveFixConfirmed, reason: source);
    _logGpsDiag(
      'live_location_applied',
      details: <String, Object?>{
        'source': source,
        'lat': latLng.latitude,
        'lng': latLng.longitude,
      },
    );
    notifyListeners();
    if (isLocationLocked) {
      _updateMapCamera(currentLocation, heading);
    }
    _promoteGpsStartupUiReadyIfPossible();
  }

  bool _isCurrentLocationDefault() {
    return currentLocation.latitude == MapConstants.defaultLatitude &&
        currentLocation.longitude == MapConstants.defaultLongitude;
  }

  void _promoteGpsStartupUiReadyIfPossible() {
    if (!hasLocationPermission) return;
    final hasResolvedLocation = !_isCurrentLocationDefault();
    final hasRecentStreamPoint = _lastDerivedPositionAt != null;
    if (!hasResolvedLocation && !hasRecentStreamPoint) return;
    _setGpsStartupState(GpsStartupState.uiReady, reason: 'ui_readiness_met');
    _logGpsDiag(
      'ui_ready_promoted',
      details: <String, Object?>{
        'has_resolved_location': hasResolvedLocation,
        'has_recent_stream_point': hasRecentStreamPoint,
      },
    );
  }

  void _setGpsStartupState(GpsStartupState next, {required String reason}) {
    if (gpsStartupState == next) return;
    final previous = gpsStartupState;
    gpsStartupState = next;
    _logGpsDiag(
      'startup_state_transition',
      details: <String, Object?>{
        'from': previous.name,
        'to': next.name,
        'reason': reason,
      },
    );
  }

  static String _buildGpsDiagSessionId() {
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return micros.toRadixString(36);
  }

  void _logGpsDiag(String event, {Map<String, Object?> details = const {}}) {
    final payload = <String, Object?>{
      'scope': 'map_controller',
      'event': event,
      'session_id': _gpsDiagSessionId,
      'startup_state': gpsStartupState.name,
      ...details,
    };
    debugPrint('gps_diag:${jsonEncode(payload)}');
  }

  void _registerBootstrapFix({
    required DateTime timestamp,
    required double? horizontalAccuracyMeters,
  }) {
    _bootstrapFixAt = timestamp;
    final isStableFix =
        horizontalAccuracyMeters != null &&
        horizontalAccuracyMeters.isFinite &&
        horizontalAccuracyMeters > 0 &&
        horizontalAccuracyMeters <= _stableFixAccuracyForMode;
    if (isStableFix) {
      _hasStableBootstrapFix = true;
      _stableFixCount = _requiredStableFixSamplesForMode;
    }
  }

  void _startCompassUpdates() {
    if (PlatformUtils.isMobile) {
      _compassSubscription = FlutterCompass.events?.listen((
        CompassEvent event,
      ) {
        final rawHeading = event.heading;
        if (rawHeading != null && rawHeading.isFinite) {
          heading = normalizeHeadingDegrees(rawHeading);
          _lastCompassUpdateAt = DateTime.now().toUtc();
          _logGpsDiag(
            'compass_heading_update',
            details: <String, Object?>{
              'raw_heading': rawHeading,
              'heading': heading,
            },
          );
          notifyListeners();
          if (!isNorthUp && isLocationLocked) {
            _updateMapCamera(currentLocation, heading);
          }
        }
      });
    }
  }

  @visibleForTesting
  static double normalizeHeadingDegrees(double rawHeading) {
    final normalized = rawHeading % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  bool get _hasFreshCompassHeading {
    final last = _lastCompassUpdateAt;
    if (last == null) return false;
    return DateTime.now().toUtc().difference(last) <= _compassFreshnessWindow;
  }

  void _updateHeadingFromCourseIfNeeded(
    LatLng nextLocation, {
    required double? speedMetersPerSecond,
    required double? horizontalAccuracyMeters,
  }) {
    if (_hasFreshCompassHeading) {
      _lastCourseHeadingSample = nextLocation;
      return;
    }
    final previousSample = _lastCourseHeadingSample;
    _lastCourseHeadingSample = nextLocation;
    if (previousSample == null) return;
    final distance = Geolocator.distanceBetween(
      previousSample.latitude,
      previousSample.longitude,
      nextLocation.latitude,
      nextLocation.longitude,
    );
    final speed = speedMetersPerSecond ?? 0;
    final accuracy = horizontalAccuracyMeters ?? double.infinity;
    if (distance < _courseFallbackMinDistanceMeters ||
        speed < _courseFallbackMinSpeedMetersPerSecond ||
        accuracy > _courseFallbackMaxAccuracyMeters) {
      return;
    }
    final courseHeading = Geolocator.bearingBetween(
      previousSample.latitude,
      previousSample.longitude,
      nextLocation.latitude,
      nextLocation.longitude,
    );
    if (!courseHeading.isFinite) return;
    heading = (courseHeading + 360) % 360;
    _logGpsDiag(
      'course_heading_fallback',
      details: <String, Object?>{
        'heading': heading,
        'distance_m': distance,
        'speed_mps': speed,
        'accuracy_m': horizontalAccuracyMeters,
      },
    );
  }

  double _resolveDynamicZoom({
    required double speedKmh,
    required DateTime timestamp,
    required double currentZoom,
  }) {
    if (!dynamicMapZoomEnabled || isPreparingStart) {
      return currentZoom;
    }
    final candidate = _dynamicZoomPolicy.evaluate(
      speedKmh: speedKmh,
      timestamp: timestamp,
      currentZoom: currentZoom,
      minZoom: MapConstants.minZoom,
      maxZoom: MapConstants.maxZoom,
    );
    return candidate ?? currentZoom;
  }

  void _updateMapCamera(
    LatLng location,
    double heading, {
    double? zoomOverride,
  }) {
    if (!isLocationLocked) return;

    final double targetRotation = isNorthUp ? 0.0 : -heading;
    final double currentZoom = zoomOverride ?? mapController.camera.zoom;
    final shiftedCenter = _calculateShiftedCenter(
      location,
      currentZoom,
      targetRotation,
    );

    try {
      mapController.moveAndRotate(shiftedCenter, currentZoom, targetRotation);
    } catch (_) {
      mapController.move(shiftedCenter, currentZoom);
      mapController.rotate(targetRotation);
    }
  }

  LatLng _calculateShiftedCenter(
    LatLng userLoc,
    double zoom,
    double rotationDeg,
  ) {
    // Note: Assuming fixed screen height reference for logic simplicity here
    // Ideally we pass context or screen height.
    // Fallback to 800 if unknown.
    // In strict Clean Architecture, view logic shouldn't be here,
    // but map camera control is tied to this controller.
    const double screenHeight = 800; // Approximation or inject

    final latRad = userLoc.latitude * (math.pi / 180.0);
    final resolution = 156543.03 * math.cos(latRad) / math.pow(2, zoom);
    const shiftPixels = screenHeight * 0.15;
    final shiftMeters = shiftPixels * resolution;
    final bearingRad = (-rotationDeg + 180) * (math.pi / 180.0);
    const earthRadius = 6378137.0;
    final dLat = (shiftMeters / earthRadius) * math.cos(bearingRad);
    final dLon =
        (shiftMeters / earthRadius) * math.sin(bearingRad) / math.cos(latRad);

    return LatLng(
      userLoc.latitude + (dLat * 180 / math.pi),
      userLoc.longitude + (dLon * 180 / math.pi),
    );
  }

  void onMapMoved() {
    if (isLocationLocked) {
      isLocationLocked = false;
      _dynamicZoomPolicy.reset();
      notifyListeners();
    }
  }

  void toggleAudio() {
    audioEnabled = !audioEnabled;
    unawaited(audioFeedbackService.setEnabledWithAnnouncement(audioEnabled));
    notifyListeners();
  }

  void toggleCompassMode() {
    isNorthUp = !isNorthUp;
    isLocationLocked = true;
    _dynamicZoomPolicy.reset();
    notifyListeners();
    _updateMapCamera(currentLocation, heading);
  }

  void startTracking(ActivityType activityType, {int? activityTypeId}) {
    unawaited(_refreshBatteryOptimizationStatus());
    if (!hasLocationPermission) {
      return;
    } // UI should handle permission check too or callback
    if (trackingSnapshot.state == TrackingSessionState.recording ||
        trackingSnapshot.state == TrackingSessionState.paused ||
        isPreparingStart) {
      return;
    }

    if (!hasStableStartFix) {
      return;
    }

    _beginStartCountdown(activityType, activityTypeId: activityTypeId);
  }

  bool get hasRecentGpsFix {
    final lastPositionAt = trackingSnapshot.lastPositionAt;
    if (!hasLocationPermission) return false;
    if (lastPositionAt != null &&
        DateTime.now().difference(lastPositionAt) <=
            const Duration(seconds: 4)) {
      return true;
    }
    if (_bootstrapFixAt == null) return false;
    return DateTime.now().difference(_bootstrapFixAt!) <=
        const Duration(seconds: 12);
  }

  bool get hasStableStartFix =>
      hasRecentGpsFix &&
      (_stableFixCount >= _requiredStableFixSamplesForMode ||
          _hasStableBootstrapFix);

  bool get hasWarmStartLocation {
    if (!hasLocationPermission) return false;
    return currentLocation.latitude != MapConstants.defaultLatitude ||
        currentLocation.longitude != MapConstants.defaultLongitude;
  }

  int get _requiredStableFixSamplesForMode {
    return switch (gpsFilterMode) {
      GpsFilterMode.strict => 4,
      GpsFilterMode.normal => 2,
      GpsFilterMode.auto => _requiredStableFixSamples,
    };
  }

  double get _stableFixAccuracyForMode {
    return switch (gpsFilterMode) {
      GpsFilterMode.strict => 20,
      GpsFilterMode.normal => 30,
      GpsFilterMode.auto => _stableFixAccuracyMeters,
    };
  }

  bool get isPreparingStart =>
      _isPreparingStartLocal ||
      trackingSnapshot.state == TrackingSessionState.initializing;

  void _beginStartCountdown(ActivityType activityType, {int? activityTypeId}) {
    _isPreparingStartLocal = true;
    notifyListeners();
    trackingSessionEngine
        .start(activityType, activityTypeId: activityTypeId, useCountdown: true)
        .then((started) {
          if (!started && _isPreparingStartLocal) {
            _isPreparingStartLocal = false;
            notifyListeners();
          }
        })
        .catchError((Object e, StackTrace _) {
          _isPreparingStartLocal = false;
          notifyListeners();
          debugPrint('[GPS-DEBUG] Error starting tracking: $e');
        });
  }

  Future<void> pauseTracking() async {
    await trackingSessionEngine.pause();
  }

  Future<void> resumeTracking() async {
    await trackingSessionEngine.resume();
  }

  Future<Activity?> stopTracking() async {
    final activity = await trackingSessionEngine.stop();
    // Logic for "suspicious save" confirmation is UI logic (dialogs).
    // The controller just returns the activity.
    // The UI handles confirmation and calls delete/upload.
    // Wait, the controller should probably handle the state reset.
    // If UI decides to discard, it calls controller.discardActivity(id).
    // If UI decides to save, it calls controller.uploadActivity(activity).
    return activity;
  }

  Future<void> discardActivity(String id) async {
    await trackingSessionEngine.deleteSavedActivity(id);
    await trackingSessionEngine.reset();
  }

  Future<void> resetSession() async {
    await trackingSessionEngine.reset();
  }

  Future<ActivityUploadResult> uploadActivity(Activity activity) async {
    if (uploadService == null) {
      return ActivityUploadResult.failure(
        attempts: 0,
        failureType: ActivityUploadFailureType.configuration,
      );
    }
    return uploadService!.uploadActivity(activity);
  }
}
