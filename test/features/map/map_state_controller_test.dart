import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:endurain/core/services/location_platform_adapter.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/features/map/map_settings_repository.dart';
import 'package:endurain/features/map/map_state_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('MapStateController', () {
    test('loads tile settings and current location', () async {
      final storage = SecureStorageService();
      await storage.setTileServerUrl(
        'https://tiles.example.test/{z}/{x}/{y}.png',
      );
      final platform = _FakeLocationPlatformAdapter(
        currentPosition: _position(
          latitude: 41.1,
          longitude: -8.6,
          heading: 45,
        ),
      );
      final controller = MapStateController(
        locationService: LocationService(platformAdapter: platform),
        mapSettingsRepository: MapSettingsRepository(storage: storage),
      );

      await controller.initialize();

      expect(
        controller.tileServerUrl,
        'https://tiles.example.test/{z}/{x}/{y}.png',
      );
      expect(controller.hasLocationPermission, isTrue);
      expect(controller.currentLocation.latitude, 41.1);
      expect(controller.currentLocation.longitude, -8.6);
      expect(controller.heading, 45);
      controller.dispose();
    });

    test('updates location from the position stream', () async {
      final platform = _FakeLocationPlatformAdapter(
        currentPosition: _position(latitude: 41.1, longitude: -8.6),
      );
      final controller = MapStateController(
        locationService: LocationService(platformAdapter: platform),
        mapSettingsRepository: MapSettingsRepository(
          storage: SecureStorageService(),
        ),
      );

      await controller.initialize();
      platform.addPosition(
        _position(latitude: 42.0, longitude: -9.0, heading: 180),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentLocation.latitude, 42.0);
      expect(controller.currentLocation.longitude, -9.0);
      expect(controller.heading, 180);
      controller.dispose();
      await platform.close();
    });

    test('toggles and unlocks location lock', () {
      final controller = MapStateController(
        locationService: LocationService(
          platformAdapter: _FakeLocationPlatformAdapter(),
        ),
        mapSettingsRepository: MapSettingsRepository(
          storage: SecureStorageService(),
        ),
      );

      expect(controller.isLocationLocked, isTrue);
      controller.toggleLocationLock();
      expect(controller.isLocationLocked, isFalse);
      controller.unlockLocation();
      expect(controller.isLocationLocked, isFalse);
      controller.dispose();
    });
  });
}

Position _position({
  required double latitude,
  required double longitude,
  double heading = 0,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.utc(2026),
    accuracy: 5,
    altitude: 10,
    altitudeAccuracy: 1,
    heading: heading,
    headingAccuracy: 1,
    speed: 3,
    speedAccuracy: 1,
  );
}

class _FakeLocationPlatformAdapter implements LocationPlatformAdapter {
  _FakeLocationPlatformAdapter({Position? currentPosition})
    : currentPosition =
          currentPosition ?? _position(latitude: 41.0, longitude: -8.0);

  final Position currentPosition;
  final _positionController = StreamController<Position>.broadcast();

  void addPosition(Position position) {
    _positionController.add(position);
  }

  Future<void> close() {
    return _positionController.close();
  }

  @override
  Future<LocationPermission> checkPermission() async {
    return LocationPermission.whileInUse;
  }

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  }) async {
    return currentPosition;
  }

  @override
  Stream<Position> getPositionStream({
    required LocationSettings locationSettings,
  }) {
    return _positionController.stream;
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    return true;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    return LocationPermission.whileInUse;
  }
}
