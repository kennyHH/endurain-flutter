import 'dart:async';
import 'dart:io';

import 'package:endurain/core/services/location_platform_adapter.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/features/activity/controllers/activity_recording_controller.dart';
import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_upload_state.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/services/activity_gpx_file_writer.dart';
import 'package:endurain/features/activity/services/activity_recording_service.dart';
import 'package:endurain/features/activity/services/activity_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:http/http.dart' as http;

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

    test('generates GPX when a valid recording completes', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(recordingService: service);
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      adapter.addPosition(_position(latitude: 41.1, longitude: -8.6));
      await pumpEventQueue();
      await controller.stop();
      await pumpEventQueue();

      expect(controller.state.status, ActivityRecordingStatus.completed);
      expect(controller.completedGpx, contains('<gpx'));
      expect(
        controller.completedGpx,
        contains('<trkpt lat="41.1" lon="-8.6">'),
      );
    });

    test('does not generate GPX for discarded recordings', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(recordingService: service);
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      adapter.addPosition(_position(latitude: 41.1, longitude: -8.6));
      await pumpEventQueue();
      await controller.discard();

      expect(controller.state.status, ActivityRecordingStatus.idle);
      expect(controller.completedGpx, isNull);
    });

    test('leaves empty recordings without GPX content', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(recordingService: service);
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      await controller.stop();
      await pumpEventQueue();

      expect(controller.state.status, ActivityRecordingStatus.failed);
      expect(controller.completedGpx, isNull);
    });

    test('fails upload without a temp file when config is missing', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final tempDirectory = await Directory.systemTemp.createTemp(
        'endurain_upload_missing_',
      );
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(
        recordingService: service,
        gpxFileWriter: ActivityGpxFileWriter(
          temporaryDirectoryProvider: () async => tempDirectory,
          uniqueSuffixProvider: () => 'missing',
        ),
      );
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      adapter.addPosition(_position());
      await pumpEventQueue();
      await controller.stop();
      await controller.uploadCompletedGpx();

      expect(controller.uploadStatus, ActivityUploadStatus.failed);
      expect(tempDirectory.listSync(), isEmpty);
    });

    test('deletes temporary GPX after successful upload', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final tempDirectory = await Directory.systemTemp.createTemp(
        'endurain_upload_success_',
      );
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(
        recordingService: service,
        gpxFileWriter: ActivityGpxFileWriter(
          temporaryDirectoryProvider: () async => tempDirectory,
          uniqueSuffixProvider: () => 'success',
        ),
        uploadService: _uploadServiceReturning(201),
      );
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      adapter.addPosition(_position());
      await pumpEventQueue();
      await controller.stop();
      await controller.uploadCompletedGpx();

      expect(controller.uploadStatus, ActivityUploadStatus.uploaded);
      expect(tempDirectory.listSync(), isEmpty);
    });

    test('keeps failed upload file until discard', () async {
      final adapter = _FakeLocationPlatformAdapter();
      final tempDirectory = await Directory.systemTemp.createTemp(
        'endurain_upload_failed_',
      );
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(
        recordingService: service,
        gpxFileWriter: ActivityGpxFileWriter(
          temporaryDirectoryProvider: () async => tempDirectory,
          uniqueSuffixProvider: () => 'failed',
        ),
        uploadService: _uploadServiceReturning(500),
      );
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      adapter.addPosition(_position());
      await pumpEventQueue();
      await controller.stop();
      await controller.uploadCompletedGpx();

      expect(controller.uploadStatus, ActivityUploadStatus.failed);
      expect(tempDirectory.listSync(), isNotEmpty);

      await controller.discard();

      expect(tempDirectory.listSync(), isEmpty);
    });
  });
}

ActivityUploadService _uploadServiceReturning(int statusCode) {
  return ActivityUploadService(
    config: const ActivityUploadConfig(endpoint: '/upload', fieldName: 'file'),
    uploadFile: (_, _, _) async {
      return http.StreamedResponse(const Stream<List<int>>.empty(), statusCode);
    },
  );
}

class _FakeLocationPlatformAdapter implements LocationPlatformAdapter {
  final List<StreamController<Position>> _controllers = [];

  void addPosition(Position position) {
    _controllers.last.add(position);
  }

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
    final controller = StreamController<Position>();
    _controllers.add(controller);
    return controller.stream;
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
