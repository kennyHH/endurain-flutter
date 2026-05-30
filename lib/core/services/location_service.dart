import 'package:geolocator/geolocator.dart';
import 'package:endurain/core/services/location_platform_adapter.dart';

class LocationService {
  LocationService({LocationPlatformAdapter? platformAdapter})
    : _platformAdapter =
          platformAdapter ?? const GeolocatorLocationPlatformAdapter();

  final LocationPlatformAdapter _platformAdapter;

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return _platformAdapter.isLocationServiceEnabled();
  }

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    return _platformAdapter.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return _platformAdapter.requestPermission();
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
      return await _platformAdapter.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get position stream for continuous tracking
  Stream<Position> getPositionStream() {
    return _platformAdapter.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Get device heading/bearing (0-360 degrees, 0 = North)
  /// Returns null if heading is unavailable
  Future<double?> getHeading() async {
    try {
      final position = await _platformAdapter.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return position.heading;
    } catch (e) {
      return null;
    }
  }

  /// Open app settings (useful when permission is permanently denied)
  Future<bool> openAppSettings() async {
    return _platformAdapter.openAppSettings();
  }
}
