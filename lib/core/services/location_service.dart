import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@singleton
class LocationService {
  bool _isEcoMode = false;

  void setEcoMode(bool enabled) {
    _isEcoMode = enabled;
  }

  static const LocationSettings _singleFixSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    timeLimit: Duration(seconds: 20),
  );

  static final AndroidSettings _androidWarmupSingleFixSettings =
      AndroidSettings(
        accuracy: LocationAccuracy.high,
        forceLocationManager: false,
        timeLimit: const Duration(seconds: 6),
      );

  LocationSettings _streamSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (_isEcoMode) {
        return AndroidSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 10,
          intervalDuration: const Duration(seconds: 5),
          forceLocationManager:
              false, // Use FusedLocationProvider for better battery
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Endurain Tracking (Eco Mode)',
            notificationText: 'Saving battery while tracking',
            enableWakeLock: false, // Allow CPU to sleep between updates
          ),
        );
      }
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
        forceLocationManager: false,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Endurain Tracking',
          notificationText: 'Recording your activity in background',
          enableWakeLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: _isEcoMode
            ? LocationAccuracy.medium
            : LocationAccuracy.bestForNavigation,
        distanceFilter: _isEcoMode ? 10 : 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically:
            _isEcoMode, // Allow auto-pause in Eco
      );
    }
    return LocationSettings(
      accuracy: _isEcoMode
          ? LocationAccuracy.medium
          : LocationAccuracy.bestForNavigation,
      distanceFilter: _isEcoMode ? 10 : 0,
    );
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return Geolocator.requestPermission();
  }

  /// Get current position
  /// Returns null if permission is denied or location service is disabled
  /// Get last known position (faster than waiting for a fix)
  Future<Position?> getLastKnownPosition() async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    final permission = await checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      return null;
    }
  }

  Future<Position?> getCurrentPosition() async {
    // Check if location services are enabled
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    // Check permission
    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final warmup = await Geolocator.getCurrentPosition(
            locationSettings: _androidWarmupSingleFixSettings,
          );
          return warmup;
        } catch (_) {}
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: _singleFixSettings,
      );
    } catch (e) {
      debugPrint(
        'LocationService: Single fix failed: $e',
      ); // Add internal logging
      return null;
    }
  }

  /// Get position stream for continuous tracking
  Stream<Position> getPositionStream() async* {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('LocationService: Stream skipped, service disabled');
      return;
    }

    final permission = await checkPermission();
    final hasPermission =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    if (!hasPermission) {
      debugPrint('LocationService: Stream skipped, permission=$permission');
      return;
    }

    yield* Geolocator.getPositionStream(locationSettings: _streamSettings());
  }

  /// Get device heading/bearing (0-360 degrees, 0 = North)
  /// Returns null if heading is unavailable
  Future<double?> getHeading() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _singleFixSettings,
      );
      return position.heading;
    } catch (e) {
      return null;
    }
  }

  /// Open app settings (useful when permission is permanently denied)
  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }
}
