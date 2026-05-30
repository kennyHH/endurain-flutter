import 'dart:async';

import 'package:endurain/core/services/location_platform_adapter.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/features/activity/controllers/activity_recording_controller.dart';
import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/services/activity_recording_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;

void main() {
  group('ActivityRecordingController', () {
    test('starts recording with selected type', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(recordingService: service);
      addTearDown(controller.dispose);

      await controller.start(ActivityType.ride);
      await pumpEventQueue();

      expect(controller.selectedActivityType, ActivityType.ride);
      expect(controller.state.status, ActivityRecordingStatus.recording);
      expect(controller.state.activityType, ActivityType.ride);
    });

    test('ignores type changes while active', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(recordingService: service);
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      await pumpEventQueue();
      controller.selectActivityType(ActivityType.hike);

      expect(controller.selectedActivityType, ActivityType.run);
    });
  });
}

class _FakeLocationPlatformAdapter implements LocationPlatformAdapter {
  @override
  Future<LocationPermission> checkPermission() async {
    return LocationPermission.whileInUse;
  }

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  }) async {
    return _position();
  }

  @override
  Stream<Position> getPositionStream({
    required LocationSettings locationSettings,
  }) {
    return const Stream<Position>.empty();
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

Position _position() {
  return Position(
    latitude: 41,
    longitude: -8,
    timestamp: DateTime.utc(2026),
    accuracy: 5,
    altitude: 10,
    altitudeAccuracy: 1,
    heading: 90,
    headingAccuracy: 1,
    speed: 3,
    speedAccuracy: 1,
  );
}