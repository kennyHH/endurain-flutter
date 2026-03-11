import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static const LocationSettings _singleFixSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
  );

  LocationSettings _streamSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
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

    // Get position
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _singleFixSettings,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get position stream for continuous tracking
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: _streamSettings(),
    );
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
