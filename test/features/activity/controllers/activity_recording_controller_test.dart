import 'dart:async';
import 'dart:io';

import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/features/activity/controllers/activity_recording_controller.dart';
import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_upload_state.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/models/local_activity_record.dart';
import 'package:endurain/features/activity/repositories/activity_retention_settings_repository.dart';
import 'package:endurain/features/activity/repositories/local_activity_repository.dart';
import 'package:endurain/features/activity/services/activity_gpx_builder.dart';
import 'package:endurain/features/activity/services/activity_recording_service.dart';
import 'package:endurain/features/activity/services/activity_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/recording_location_platform_adapter.dart';

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

    test(
      'generates GPX and retained local record when recording completes',
      () async {
        final adapter = RecordingLocationPlatformAdapter();
        final tempDirectory = await Directory.systemTemp.createTemp(
          'endurain_local_complete_',
        );
        addTearDown(() => tempDirectory.deleteSync(recursive: true));
        final repository = _repositoryFor(tempDirectory);
        final service = ActivityRecordingService(
          locationService: LocationService(platformAdapter: adapter),
        );
        final controller = ActivityRecordingController(
          recordingService: service,
          localActivityRepository: repository,
          localActivityIdProvider: () => 'local_complete',
        );
        addTearDown(controller.dispose);

        await controller.start(ActivityType.run);
        adapter.addPosition(recordingPosition(latitude: 41.1, longitude: -8.6));
        await pumpEventQueue();
        await controller.stop();
        await controller.uploadCompletedGpx();

        final records = await repository.list();
        expect(controller.state.status, ActivityRecordingStatus.completed);
        expect(controller.completedGpx, contains('<gpx'));
        expect(
          controller.completedGpx,
          contains('<trkpt lat="41.1" lon="-8.6">'),
        );
        expect(controller.state.localActivityId, 'local_complete');
        expect(records, hasLength(1));
        expect(records.single.id, 'local_complete');
        expect(await repository.hasGpx(records.single), isTrue);
      },
    );

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

    test('surfaces local save failures before upload starts', () async {
      final adapter = RecordingLocationPlatformAdapter();
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(
        recordingService: service,
        localActivityRepository: _ThrowingLocalActivityRepository(),
        uploadService: _uploadServiceReturning(201),
      );
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      adapter.addPosition(recordingPosition());
      await pumpEventQueue();
      await controller.stop();

      expect(controller.state.status, ActivityRecordingStatus.failed);
      expect(
        controller.state.lastErrorKey,
        ActivityRecordingErrorKeys.localSaveFailed,
      );
      expect(controller.uploadStatus, ActivityUploadStatus.failed);
      expect(
        controller.uploadError,
        isA<AppException>().having(
          (exception) => exception.code,
          'code',
          AppErrorCode.activityLocalSaveFailed,
        ),
      );
    });

    test(
      'marks retained record uploaded and keeps GPX after successful upload',
      () async {
        final adapter = RecordingLocationPlatformAdapter();
        final tempDirectory = await Directory.systemTemp.createTemp(
          'endurain_upload_success_',
        );
        addTearDown(() => tempDirectory.deleteSync(recursive: true));
        final repository = _repositoryFor(tempDirectory);
        final service = ActivityRecordingService(
          locationService: LocationService(platformAdapter: adapter),
        );
        final controller = ActivityRecordingController(
          recordingService: service,
          localActivityRepository: repository,
          localActivityIdProvider: () => 'upload_success',
          uploadService: _uploadServiceReturning(201),
        );
        addTearDown(controller.dispose);

        await controller.start(ActivityType.run);
        adapter.addPosition(recordingPosition());
        await pumpEventQueue();
        await controller.stop();
        await controller.uploadCompletedGpx();

        final record = (await repository.list()).single;
        expect(controller.uploadStatus, ActivityUploadStatus.uploaded);
        expect(record.uploadStatus, LocalActivityUploadStatus.uploaded);
        expect(record.uploadedAt, isNotNull);
        expect(record.lastUploadErrorCode, isNull);
        expect(await repository.hasGpx(record), isTrue);
      },
    );

    test('marks auth failures with safe local upload error code', () async {
      final adapter = RecordingLocationPlatformAdapter();
      final tempDirectory = await Directory.systemTemp.createTemp(
        'endurain_upload_auth_failed_',
      );
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      final repository = _repositoryFor(tempDirectory);
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(
        recordingService: service,
        localActivityRepository: repository,
        localActivityIdProvider: () => 'upload_auth_failed',
        uploadService: _uploadServiceReturning(401),
      );
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      adapter.addPosition(recordingPosition());
      await pumpEventQueue();
      await controller.stop();
      await controller.uploadCompletedGpx();

      final record = (await repository.list()).single;
      expect(controller.uploadStatus, ActivityUploadStatus.failed);
      expect(record.uploadStatus, LocalActivityUploadStatus.failed);
      expect(record.lastUploadErrorCode, AppErrorCode.sessionExpired);
      expect(await repository.hasGpx(record), isTrue);
    });

    test(
      'clearCompleted resets active state and preserves local record',
      () async {
        final adapter = RecordingLocationPlatformAdapter();
        final tempDirectory = await Directory.systemTemp.createTemp(
          'endurain_clear_completed_',
        );
        addTearDown(() => tempDirectory.deleteSync(recursive: true));
        final repository = _repositoryFor(tempDirectory);
        final service = ActivityRecordingService(
          locationService: LocationService(platformAdapter: adapter),
        );
        final controller = ActivityRecordingController(
          recordingService: service,
          localActivityRepository: repository,
          localActivityIdProvider: () => 'clear_completed',
          uploadService: _uploadServiceReturning(201),
        );
        addTearDown(controller.dispose);

        await controller.start(ActivityType.run);
        adapter.addPosition(recordingPosition());
        await pumpEventQueue();
        await controller.stop();
        await controller.uploadCompletedGpx();
        await controller.clearCompleted();

        final records = await repository.list();
        expect(controller.state.status, ActivityRecordingStatus.idle);
        expect(controller.completedGpx, isNull);
        expect(records, hasLength(1));
        expect(await repository.hasGpx(records.single), isTrue);
      },
    );

    test('discard deletes retained local record and GPX', () async {
      final adapter = RecordingLocationPlatformAdapter();
      final tempDirectory = await Directory.systemTemp.createTemp(
        'endurain_discard_retained_',
      );
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      final repository = _repositoryFor(tempDirectory);
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(
        recordingService: service,
        localActivityRepository: repository,
        localActivityIdProvider: () => 'discard_retained',
        uploadService: _uploadServiceReturning(500),
      );
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      adapter.addPosition(recordingPosition());
      await pumpEventQueue();
      await controller.stop();
      await controller.uploadCompletedGpx();
      expect(await repository.list(), hasLength(1));

      await controller.discard();

      expect(controller.state.status, ActivityRecordingStatus.idle);
      expect(await repository.list(), isEmpty);
    });

    test('retention setting removes uploaded GPX but keeps metadata', () async {
      final adapter = RecordingLocationPlatformAdapter();
      final tempDirectory = await Directory.systemTemp.createTemp(
        'endurain_retention_disabled_',
      );
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      final repository = _repositoryFor(tempDirectory);
      final service = ActivityRecordingService(
        locationService: LocationService(platformAdapter: adapter),
      );
      final controller = ActivityRecordingController(
        recordingService: service,
        localActivityRepository: repository,
        localActivityIdProvider: () => 'retention_disabled',
        uploadService: _uploadServiceReturning(201),
        retentionSettingsRepository: _FakeRetentionSettings(enabled: false),
      );
      addTearDown(controller.dispose);

      await controller.start(ActivityType.run);
      adapter.addPosition(recordingPosition());
      await pumpEventQueue();
      await controller.stop();
      await controller.uploadCompletedGpx();

      final record = (await repository.list()).single;
      expect(record.uploadStatus, LocalActivityUploadStatus.uploaded);
      expect(await repository.hasGpx(record), isFalse);
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

class _ThrowingLocalActivityRepository extends LocalActivityRepository {
  _ThrowingLocalActivityRepository()
    : super(supportDirectoryProvider: () async => Directory.systemTemp);

  @override
  Future<String> writeGpx({required String id, required String gpx}) {
    throw const AppException(AppErrorCode.activityLocalSaveFailed);
  }
}

class _FakeRetentionSettings extends ActivityRetentionSettingsRepository {
  _FakeRetentionSettings({required this.enabled})
    : super(storage: SecureStorageService());

  final bool enabled;

  @override
  Future<bool> isRetainUploadedGpxEnabled() async => enabled;

  @override
  Future<void> setRetainUploadedGpxEnabled(bool enabled) async {}
}

LocalActivityRepository _repositoryFor(Directory directory) {
  return LocalActivityRepository(
    supportDirectoryProvider: () async => directory,
  );
}

ActivityUploadService _uploadServiceReturning(int statusCode) {
  return ActivityUploadService(
    config: const ActivityUploadConfig(endpoint: '/upload', fieldName: 'file'),
    uploadFile: (_, _, _) async {
      return http.StreamedResponse(const Stream<List<int>>.empty(), statusCode);
    },
  );
}
