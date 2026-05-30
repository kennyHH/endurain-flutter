import 'dart:async';

import 'package:endurain/core/services/location_platform_adapter.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/services/activity_recording_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;

void main() {
  group('ActivityRecordingService', () {
    test('starts recording and emits state', () async {
      final startedAt = DateTime.utc(2026, 5, 30, 10);
      final adapter = _FakeLocationPlatformAdapter();
      final service = ActivityRecordingService(
        now: () => startedAt,
        locationService: LocationService(platformAdapter: adapter),
      );
      addTearDown(service.dispose);

      await service.start(activityType: ActivityType.run);

      expect(service.state.status, ActivityRecordingStatus.recording);
      expect(service.state.activityType, ActivityType.run);
      expect(service.state.startedAt, startedAt);
      expect(service.state.points, isEmpty);
      expect(adapter.listenCount, 1);
    });

    test('does not start when location services are disabled', () async {
      final adapter = _FakeLocationPlatformAdapter(serviceEnabled: false);
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      addTearDown(service.dispose);

      await service.start(activityType: ActivityType.run);

      expect(service.state.status, ActivityRecordingStatus.failed);
      expect(
        service.state.lastErrorKey,
        ActivityRecordingErrorKeys.locationServiceDisabled,
      );
      expect(adapter.listenCount, 0);
    });

    test('does not start when permission is denied', () async {
      final adapter = _FakeLocationPlatformAdapter(
        permission: LocationPermission.denied,
        requestedPermission: LocationPermission.denied,
      );
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      addTearDown(service.dispose);

      await service.start(activityType: ActivityType.run);

      expect(service.state.status, ActivityRecordingStatus.failed);
      expect(
        service.state.lastErrorKey,
        ActivityRecordingErrorKeys.locationPermissionDenied,
      );
      expect(adapter.requestPermissionCalled, isTrue);
      expect(adapter.listenCount, 0);
    });

    test('does not start when permission is denied forever', () async {
      final adapter = _FakeLocationPlatformAdapter(
        permission: LocationPermission.deniedForever,
      );
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      addTearDown(service.dispose);

      await service.start(activityType: ActivityType.run);

      expect(service.state.status, ActivityRecordingStatus.failed);
      expect(
        service.state.lastErrorKey,
        ActivityRecordingErrorKeys.locationPermissionDeniedForever,
      );
      expect(adapter.listenCount, 0);
    });

    test('records position updates as track points', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      addTearDown(service.dispose);

      await service.start(activityType: ActivityType.run);
      adapter.addPosition(_position(latitude: 41.1, longitude: -8.6));
      await pumpEventQueue();

      expect(service.state.points, hasLength(1));
      expect(service.state.points.single.latitude, 41.1);
      expect(service.state.points.single.longitude, -8.6);
    });

    test('pause and resume update state', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      addTearDown(service.dispose);

      await service.start(activityType: ActivityType.ride);
      await service.pause();

      expect(service.state.status, ActivityRecordingStatus.paused);
      expect(adapter.cancelCount, 1);

      await service.resume();

      expect(service.state.status, ActivityRecordingStatus.recording);
      expect(adapter.listenCount, 2);
    });

    test('stop emits stopping then completed', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final completedAt = DateTime.utc(2026, 5, 30, 11);
      var calls = 0;
      final service = ActivityRecordingService(
        now: () => calls++ == 0 ? DateTime.utc(2026, 5, 30, 10) : completedAt,
        locationService: LocationService(platformAdapter: adapter),
      );
      addTearDown(service.dispose);
      final states = <ActivityRecordingState>[];
      final subscription = service.stateStream.listen(states.add);
      addTearDown(subscription.cancel);

      await service.start(activityType: ActivityType.walk);
      adapter.addPosition(_position(latitude: 41.1, longitude: -8.6));
      await pumpEventQueue();
      await service.stop();
      await pumpEventQueue();

      expect(
        states.map((state) => state.status),
        [
          ActivityRecordingStatus.recording,
          ActivityRecordingStatus.recording,
          ActivityRecordingStatus.stopping,
          ActivityRecordingStatus.completed,
        ],
      );
      expect(service.state.endedAt, completedAt);
      expect(adapter.cancelCount, 1);
    });

    test('empty stop fails safely without completing', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      addTearDown(service.dispose);

      await service.start(activityType: ActivityType.run);
      await service.stop();

      expect(service.state.status, ActivityRecordingStatus.failed);
      expect(service.state.lastErrorKey, ActivityRecordingErrorKeys.emptyRecording);
    });

    test('duplicate start keeps current recording', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      addTearDown(service.dispose);

      await service.start(activityType: ActivityType.run);
      final startedAt = service.state.startedAt;
      await service.start(activityType: ActivityType.ride);

      expect(service.state.status, ActivityRecordingStatus.recording);
      expect(service.state.activityType, ActivityType.run);
      expect(service.state.startedAt, startedAt);
      expect(adapter.listenCount, 1);
    });

    test('invalid pause moves to failed state without raw error details', () async {
      final service = ActivityRecordingService();
      addTearDown(service.dispose);

      await service.pause();

      expect(service.state.status, ActivityRecordingStatus.failed);
      expect(
        service.state.lastErrorKey,
        ActivityRecordingErrorKeys.invalidTransition,
      );
    });

    test('discard is idempotent and clears state', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      addTearDown(service.dispose);

      await service.start(activityType: ActivityType.hike);
      await service.discard();
      await service.discard();

      expect(service.state.status, ActivityRecordingStatus.idle);
      expect(service.state.activityType, isNull);
      expect(service.state.points, isEmpty);
      expect(adapter.cancelCount, 1);
    });

    test('stream errors fail recording and cancel subscription', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      addTearDown(service.dispose);

      await service.start(activityType: ActivityType.run);
      adapter.addError(StateError('stream failed'));
      await pumpEventQueue();

      expect(service.state.status, ActivityRecordingStatus.failed);
      expect(
        service.state.lastErrorKey,
        ActivityRecordingErrorKeys.locationStreamFailed,
      );
      expect(adapter.cancelCount, 1);
    });
  });
}

class _FakeLocationPlatformAdapter implements LocationPlatformAdapter {
  _FakeLocationPlatformAdapter({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
  });

  final List<StreamController<Position>> _controllers = [];
  final bool serviceEnabled;
  LocationPermission permission;
  final LocationPermission requestedPermission;
  int listenCount = 0;
  int cancelCount = 0;
  bool requestPermissionCalled = false;

  void addPosition(Position position) {
    _controllers.last.add(position);
  }

  void addError(Object error) {
    _controllers.last.addError(error);
  }

  @override
  Future<LocationPermission> checkPermission() async {
    return permission;
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
    final controller = StreamController<Position>(
      onListen: () => listenCount += 1,
      onCancel: () => cancelCount += 1,
    );
    _controllers.add(controller);
    return controller.stream;
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return serviceEnabled;
  }

  @override
  Future<bool> openAppSettings() async {
    return true;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalled = true;
    permission = requestedPermission;
    return permission;
  }
}

Position _position({double latitude = 41, double longitude = -8}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
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