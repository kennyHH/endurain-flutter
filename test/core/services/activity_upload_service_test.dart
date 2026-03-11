import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/activity_upload_service.dart';
import 'package:endurain/core/services/api_request_executor.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeStorageService extends SecureStorageService {
  _FakeStorageService({required this.serverUrl, required this.accessToken});

  String? serverUrl;
  String? accessToken;

  @override
  Future<String?> getServerUrl() async => serverUrl;

  @override
  Future<String?> getAccessToken() async => accessToken;
}

class _FakeAuthService extends AuthService {
  _FakeAuthService(this.onRefresh);

  final Future<bool> Function() onRefresh;

  @override
  Future<bool> refreshToken() => onRefresh();
}

Activity _activityFixture() {
  return Activity(
    id: 'upload-1',
    activityType: ActivityType.run,
    startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
    endedAt: DateTime.parse('2026-03-09T10:10:00Z'),
    distanceMeters: 1000,
    trackPoints: [
      TrackPoint(
        latitude: 38.7223,
        longitude: -9.1393,
        timestamp: DateTime.parse('2026-03-09T10:00:00Z'),
      ),
      TrackPoint(
        latitude: 38.7233,
        longitude: -9.1383,
        timestamp: DateTime.parse('2026-03-09T10:01:00Z'),
      ),
    ],
  );
}

void main() {
  group('ActivityUploadService', () {
    test('success ohne retry', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: 'token-a',
      );
      final auth = _FakeAuthService(() async => false);
      final client = MockClient((request) async => http.Response('', 201));
      final service = ActivityUploadService(
        storage: storage,
        authService: auth,
        requestExecutor: ApiRequestExecutor(httpClient: client),
      );

      final result = await service.uploadActivity(_activityFixture());

      expect(result.success, isTrue);
      expect(result.attempts, equals(1));
      expect(result.statusCode, equals(201));
    });

    test('5xx wird begrenzt retried und kann erfolgreich enden', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: 'token-a',
      );
      final auth = _FakeAuthService(() async => false);
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls < 3) return http.Response('', 500);
        return http.Response('', 200);
      });
      final service = ActivityUploadService(
        storage: storage,
        authService: auth,
        requestExecutor: ApiRequestExecutor(httpClient: client),
        maxRetries: 2,
      );

      final result = await service.uploadActivity(_activityFixture());

      expect(result.success, isTrue);
      expect(result.attempts, equals(3));
      expect(calls, equals(3));
    });

    test(
      'netzwerkfehler wird begrenzt retried und endet mit network failure',
      () async {
        final storage = _FakeStorageService(
          serverUrl: 'https://example.com',
          accessToken: 'token-a',
        );
        final auth = _FakeAuthService(() async => false);
        var calls = 0;
        final client = MockClient((request) async {
          calls++;
          throw Exception('socket failed');
        });
        final service = ActivityUploadService(
          storage: storage,
          authService: auth,
          requestExecutor: ApiRequestExecutor(httpClient: client),
          maxRetries: 1,
        );

        final result = await service.uploadActivity(_activityFixture());

        expect(result.success, isFalse);
        expect(result.failureType, ActivityUploadFailureType.network);
        expect(result.attempts, equals(2));
        expect(calls, equals(2));
      },
    );

    test('401 -> refresh -> retry mit neuem token', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: 'token-old',
      );
      var refreshCalls = 0;
      final auth = _FakeAuthService(() async {
        refreshCalls++;
        storage.accessToken = 'token-new';
        return true;
      });
      var calls = 0;
      final seenAuth = <String?>[];
      final client = MockClient((request) async {
        calls++;
        seenAuth.add(request.headers['authorization']);
        if (calls == 1) return http.Response('', 401);
        return http.Response('', 200);
      });
      final service = ActivityUploadService(
        storage: storage,
        authService: auth,
        requestExecutor: ApiRequestExecutor(httpClient: client),
      );

      final result = await service.uploadActivity(_activityFixture());

      expect(result.success, isTrue);
      expect(result.attempts, equals(2));
      expect(refreshCalls, equals(1));
      expect(seenAuth, equals(['Bearer token-old', 'Bearer token-new']));
    });

    test(
      '401 ohne erfolgreichen refresh endet mit authentication failure',
      () async {
        final storage = _FakeStorageService(
          serverUrl: 'https://example.com',
          accessToken: 'token-old',
        );
        final auth = _FakeAuthService(() async => false);
        final client = MockClient((request) async => http.Response('', 401));
        final service = ActivityUploadService(
          storage: storage,
          authService: auth,
          requestExecutor: ApiRequestExecutor(httpClient: client),
        );

        final result = await service.uploadActivity(_activityFixture());

        expect(result.success, isFalse);
        expect(result.failureType, ActivityUploadFailureType.authentication);
        expect(result.attempts, equals(1));
      },
    );

    test('405 auf POST wechselt auf PUT und endet erfolgreich', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: 'token-a',
      );
      final auth = _FakeAuthService(() async => false);
      final seenMethods = <String>[];
      final client = MockClient((request) async {
        seenMethods.add(request.method);
        if (request.method == 'POST') return http.Response('', 405);
        return http.Response('', 201);
      });
      final service = ActivityUploadService(
        storage: storage,
        authService: auth,
        requestExecutor: ApiRequestExecutor(httpClient: client),
      );

      final result = await service.uploadActivity(_activityFixture());

      expect(result.success, isTrue);
      expect(seenMethods, containsAllInOrder(['POST', 'PUT']));
    });

    test('liefert server-detail aus json-fehlerantwort', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: 'token-a',
      );
      final auth = _FakeAuthService(() async => false);
      final client = MockClient(
        (request) async =>
            http.Response('{"detail":"invalid GPX format"}', 422),
      );
      final service = ActivityUploadService(
        storage: storage,
        authService: auth,
        requestExecutor: ApiRequestExecutor(httpClient: client),
      );

      final result = await service.uploadActivity(_activityFixture());

      expect(result.success, isFalse);
      expect(result.statusCode, equals(422));
      expect(result.serverDetail, equals('invalid GPX format'));
    });
  });
}
