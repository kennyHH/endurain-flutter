import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/services/activity_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('ActivityUploadService', () {
    test('uploads GPX with configured endpoint and field', () async {
      String? endpoint;
      String? filePath;
      String? fieldName;
      final service = ActivityUploadService(
        config: const ActivityUploadConfig(
          endpoint: '/api/v1/activities/import/gpx',
          fieldName: 'file',
        ),
        uploadFile: (uploadEndpoint, uploadPath, uploadFieldName) async {
          endpoint = uploadEndpoint;
          filePath = uploadPath;
          fieldName = uploadFieldName;
          return http.StreamedResponse(const Stream<List<int>>.empty(), 201);
        },
      );

      await service.uploadGpx(
        const ActivityUploadRequest(
          filePath: '/tmp/activity.gpx',
          activityType: ActivityType.run,
        ),
      );

      expect(endpoint, '/api/v1/activities/import/gpx');
      expect(filePath, '/tmp/activity.gpx');
      expect(fieldName, 'file');
    });

    test('blocks upload when the server contract is missing', () async {
      final service = ActivityUploadService();

      await expectLater(
        service.uploadGpx(
          const ActivityUploadRequest(
            filePath: '/tmp/activity.gpx',
            activityType: ActivityType.ride,
          ),
        ),
        throwsA(
          isA<AppException>().having(
            (exception) => exception.code,
            'code',
            AppErrorCode.activityUploadNotConfigured,
          ),
        ),
      );
    });

    test('maps auth failures to session expired', () async {
      final service = _serviceReturningStatus(401);

      await expectLater(
        service.uploadGpx(_request()),
        throwsA(
          isA<AppException>().having(
            (exception) => exception.code,
            'code',
            AppErrorCode.sessionExpired,
          ),
        ),
      );
    });

    test(
      'maps validation failures without raw server response details',
      () async {
        final service = _serviceReturningStatus(422);

        await expectLater(
          service.uploadGpx(_request()),
          throwsA(
            isA<AppException>()
                .having(
                  (exception) => exception.code,
                  'code',
                  AppErrorCode.activityUploadFailed,
                )
                .having(
                  (exception) => exception.details,
                  'details',
                  'HTTP 422',
                ),
          ),
        );
      },
    );

    test('maps network failures to upload failed', () async {
      final service = ActivityUploadService(
        config: const ActivityUploadConfig(
          endpoint: '/upload',
          fieldName: 'file',
        ),
        uploadFile: (_, _, _) async => throw const FormatException('offline'),
      );

      await expectLater(
        service.uploadGpx(_request()),
        throwsA(
          isA<AppException>().having(
            (exception) => exception.code,
            'code',
            AppErrorCode.activityUploadFailed,
          ),
        ),
      );
    });
  });
}

ActivityUploadService _serviceReturningStatus(int statusCode) {
  return ActivityUploadService(
    config: const ActivityUploadConfig(endpoint: '/upload', fieldName: 'file'),
    uploadFile: (_, _, _) async {
      return http.StreamedResponse(const Stream<List<int>>.empty(), statusCode);
    },
  );
}

ActivityUploadRequest _request() {
  return const ActivityUploadRequest(
    filePath: '/tmp/activity.gpx',
    activityType: ActivityType.run,
  );
}
