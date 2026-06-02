import 'dart:async';
import 'dart:io';

import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/features/activity/controllers/activity_recording_controller.dart';
import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_upload_state.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/services/activity_gpx_builder.dart';
import 'package:endurain/features/activity/services/activity_gpx_file_writer.dart';
import 'package:endurain/features/activity/services/activity_recording_service.dart';
import 'package:endurain/features/activity/services/activity_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/recording_location_platform_adapter.dart';
import 'package:http/http.dart' as http;

void main() {
  group('ActivityRecordingController', () {
    test('starts recording with selected type', () async {
      final adapter = RecordingLocationPlatformAdapter();
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
      final adapter = RecordingLocationPlatformAdapter();
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
      final adapter = RecordingLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(recordingService: service);
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      adapter.addPosition(recordingPosition(latitude: 41.1, longitude: -8.6));
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
      final adapter = RecordingLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(recordingService: service);
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      adapter.addPosition(recordingPosition(latitude: 41.1, longitude: -8.6));
      await pumpEventQueue();
      await controller.discard();

      expect(controller.state.status, ActivityRecordingStatus.idle);
      expect(controller.completedGpx, isNull);
    });

    test('leaves empty recordings without GPX content', () async {
      final adapter = RecordingLocationPlatformAdapter();
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

    test('surfaces GPX generation failures as recording failures', () async {
      final adapter = RecordingLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(
        recordingService: service,
        gpxBuilder: const _ThrowingGpxBuilder(),
      );
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      adapter.addPosition(recordingPosition());
      await pumpEventQueue();
      await controller.stop();

      expect(controller.state.status, ActivityRecordingStatus.failed);
      expect(
        controller.state.lastErrorKey,
        ActivityRecordingErrorKeys.gpxGenerationFailed,
      );
      expect(controller.completedGpx, isNull);
      expect(controller.uploadStatus, ActivityUploadStatus.idle);
    });

    test('fails upload without a temp file when config is missing', () async {
      final adapter = RecordingLocationPlatformAdapter();
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
      adapter.addPosition(recordingPosition());
      await pumpEventQueue();
      await controller.stop();
      await controller.uploadCompletedGpx();

      expect(controller.uploadStatus, ActivityUploadStatus.failed);
      expect(tempDirectory.listSync(), isEmpty);
    });

    test(
      'maps temporary GPX write failures without exposing file paths',
      () async {
        final adapter = RecordingLocationPlatformAdapter();
        final tempDirectory = await Directory.systemTemp.createTemp(
          'endurain_upload_write_failed_',
        );
        addTearDown(() => tempDirectory.deleteSync(recursive: true));
        final service = ActivityRecordingService(
          locationService: LocationService(platformAdapter: adapter),
        );
        final controller = ActivityRecordingController(
          recordingService: service,
          gpxFileWriter: _ThrowingGpxFileWriter(
            temporaryDirectory: tempDirectory,
            failWrite: true,
          ),
          uploadService: _uploadServiceReturning(201),
        );
        addTearDown(controller.dispose);

        await controller.start(ActivityType.run);
        adapter.addPosition(recordingPosition());
        await pumpEventQueue();
        await controller.stop();
        await controller.uploadCompletedGpx();

        expect(controller.uploadStatus, ActivityUploadStatus.failed);
        expect(
          controller.uploadError,
          isA<AppException>().having(
            (exception) => exception.code,
            'code',
            AppErrorCode.activityGpxFileWriteFailed,
          ),
        );
        expect(tempDirectory.listSync(), isEmpty);
      },
    );

    test('deletes temporary GPX after successful upload', () async {
      final adapter = RecordingLocationPlatformAdapter();
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
      adapter.addPosition(recordingPosition());
      await pumpEventQueue();
      await controller.stop();
      await controller.uploadCompletedGpx();

      expect(controller.uploadStatus, ActivityUploadStatus.uploaded);
      expect(tempDirectory.listSync(), isEmpty);
    });

    test('keeps uploaded GPX explicit when cleanup fails', () async {
      final adapter = RecordingLocationPlatformAdapter();
      final tempDirectory = await Directory.systemTemp.createTemp(
        'endurain_upload_cleanup_failed_',
      );
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(
        recordingService: service,
        gpxFileWriter: _ThrowingGpxFileWriter(
          temporaryDirectory: tempDirectory,
          failDelete: true,
        ),
        uploadService: _uploadServiceReturning(201),
      );
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      adapter.addPosition(recordingPosition());
      await pumpEventQueue();
      await controller.stop();
      await controller.uploadCompletedGpx();

      expect(controller.uploadStatus, ActivityUploadStatus.cleanupFailed);
      expect(
        controller.uploadError,
        isA<AppException>().having(
          (exception) => exception.code,
          'code',
          AppErrorCode.activityGpxCleanupFailed,
        ),
      );
      expect(tempDirectory.listSync(), isNotEmpty);

      await controller.discard();

      expect(controller.uploadStatus, ActivityUploadStatus.cleanupFailed);
      expect(controller.state.status, ActivityRecordingStatus.completed);
    });

    test('keeps failed upload file until discard', () async {
      final adapter = RecordingLocationPlatformAdapter();
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
      adapter.addPosition(recordingPosition());
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

class _ThrowingGpxBuilder extends ActivityGpxBuilder {
  const _ThrowingGpxBuilder();

  @override
  String build(ActivityRecordingState state, {String? trackName}) {
    throw StateError('GPX generation failed');
  }
}

class _ThrowingGpxFileWriter extends ActivityGpxFileWriter {
  _ThrowingGpxFileWriter({
    required Directory temporaryDirectory,
    this.failWrite = false,
    this.failDelete = false,
  }) : super(
         temporaryDirectoryProvider: () async => temporaryDirectory,
         uniqueSuffixProvider: () => 'throwing',
       );

  final bool failWrite;
  final bool failDelete;

  @override
  Future<File> writeGpx(String gpx) {
    if (failWrite) {
      throw const FileSystemException('write failed', '/tmp/private.gpx');
    }
    return super.writeGpx(gpx);
  }

  @override
  Future<void> delete(String filePath) {
    if (failDelete) {
      throw const FileSystemException('delete failed', '/tmp/private.gpx');
    }
    return super.delete(filePath);
  }
}

ActivityUploadService _uploadServiceReturning(int statusCode) {
  return ActivityUploadService(
    config: const ActivityUploadConfig(endpoint: '/upload', fieldName: 'file'),
    uploadFile: (_, _, _) async {
      return http.StreamedResponse(const Stream<List<int>>.empty(), statusCode);
    },
  );
}
