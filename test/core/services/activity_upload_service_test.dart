import 'dart:convert';

import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/activity_upload_service.dart';
import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/gpx_exporter.dart';
import 'package:endurain/core/services/api_request_executor.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/upload_queue/upload_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeUploadQueueService extends UploadQueueService {
  final List<Activity> _queue = <Activity>[];
  final List<String> removedIds = <String>[];

  @override
  Future<void> addToQueue(Activity activity) async {
    if (_queue.any((item) => item.id == activity.id)) {
      return;
    }
    _queue.add(activity);
  }

  @override
  Future<void> removeFromQueue(String activityId) async {
    removedIds.add(activityId);
    _queue.removeWhere((item) => item.id == activityId);
  }

  @override
  Future<List<Activity>> getQueue() async => List<Activity>.from(_queue);
}

class _FakeStorageService extends SecureStorageService {
  _FakeStorageService({required this.serverUrl, required this.accessToken});

  String? serverUrl;
  String? accessToken;

  @override
  Future<String?> getServerUrl() async => serverUrl;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<void> clearAuthTokens() async {
    accessToken = null;
  }
}

class _FakeAuthService extends AuthService {
  _FakeAuthService(this.onRefresh, {required super.storage})
    : super(requestExecutor: ApiRequestExecutor(http.Client()));

  final Future<bool> Function() onRefresh;

  @override
  Future<bool> refreshToken() => onRefresh();
}

class _FakeActivityRepository implements ActivityRepository {
  final Map<String, Activity> _items = <String, Activity>{};

  @override
  Future<void> create(Activity activity) async {
    _items[activity.id] = activity;
  }

  @override
  Future<void> update(Activity activity) async {
    _items[activity.id] = activity;
  }

  @override
  Future<void> insertTrackPoint(String activityId, TrackPoint point) async {}

  @override
  Future<Activity?> getById(String id) async => _items[id];

  @override
  Future<Activity?> getSummaryById(String id) async {
    final item = _items[id];
    if (item == null) return null;
    return item.copyWith(trackPoints: const <TrackPoint>[]);
  }

  @override
  Future<int> countTrackPoints(String activityId) async {
    return _items[activityId]?.trackPoints.length ?? 0;
  }

  @override
  Future<List<TrackPoint>> getTrackPointsPage(
    String activityId, {
    required int limit,
    int offset = 0,
  }) async {
    final points = _items[activityId]?.trackPoints ?? const <TrackPoint>[];
    if (offset >= points.length) return const <TrackPoint>[];
    final end = (offset + limit).clamp(0, points.length);
    return points.sublist(offset, end);
  }

  @override
  Future<List<Activity>> listAll() async => _items.values.toList();

  @override
  Stream<List<Activity>> watchAll() =>
      Stream<List<Activity>>.value(_items.values.toList());

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
  }
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
      final auth = _FakeAuthService(() async => false, storage: storage);
      final client = MockClient((request) async => http.Response('', 201));
      final executor = ApiRequestExecutor(client);
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: executor,
      );
      final gpxExporter = GpxExporter();
      final service = ActivityUploadService(
        apiClient: apiClient,
        storage: storage,
        authService: auth,
        gpxExporter: gpxExporter,
        queueService: _FakeUploadQueueService(),
      );

      final result = await service.uploadActivity(_activityFixture());

      expect(result.success, isTrue);
      expect(result.attempts, equals(1));
      expect(result.statusCode, equals(201));
    });

    test(
      'blockiert Upload bei ungueltiger Activity und queued nichts',
      () async {
        final storage = _FakeStorageService(
          serverUrl: 'https://example.com',
          accessToken: 'token-a',
        );
        final auth = _FakeAuthService(() async => false, storage: storage);
        var calls = 0;
        final client = MockClient((request) async {
          calls++;
          return http.Response('', 201);
        });
        final queue = _FakeUploadQueueService();
        final service = ActivityUploadService(
          apiClient: ApiClient(
            storage: storage,
            authService: auth,
            requestExecutor: ApiRequestExecutor(client),
          ),
          storage: storage,
          authService: auth,
          gpxExporter: GpxExporter(),
          queueService: queue,
        );
        final invalid = Activity(
          id: 'invalid-1',
          activityType: ActivityType.run,
          startedAt: DateTime.parse('2026-03-19T11:22:00Z'),
          endedAt: DateTime.parse('2026-03-19T11:22:09Z'),
          distanceMeters: 0,
          trackPoints: const <TrackPoint>[],
        );

        final result = await service.uploadActivity(invalid);
        final queued = await queue.getQueue();

        expect(result.success, isFalse);
        expect(
          result.failureType,
          equals(ActivityUploadFailureType.invalidActivity),
        );
        expect(calls, equals(0));
        expect(queued, isEmpty);
      },
    );

    test(
      'bereits als uploaded markierte Aktivität wird nicht erneut hochgeladen',
      () async {
        final storage = _FakeStorageService(
          serverUrl: 'https://example.com',
          accessToken: 'token-a',
        );
        final auth = _FakeAuthService(() async => false, storage: storage);
        final repository = _FakeActivityRepository();
        final activity = _activityFixture().copyWith(uploaded: true);
        await repository.create(activity);
        var calls = 0;
        final client = MockClient((request) async {
          calls++;
          return http.Response('', 201);
        });
        final service = ActivityUploadService(
          apiClient: ApiClient(
            storage: storage,
            authService: auth,
            requestExecutor: ApiRequestExecutor(client),
          ),
          storage: storage,
          authService: auth,
          gpxExporter: GpxExporter(),
          queueService: _FakeUploadQueueService(),
          activityRepository: repository,
        );

        final result = await service.uploadActivity(activity);

        expect(result.success, isTrue);
        expect(result.attempts, equals(0));
        expect(calls, equals(0));
      },
    );

    test(
      'persistiert Server-Metriken lokal nach erfolgreichem Upload',
      () async {
        final storage = _FakeStorageService(
          serverUrl: 'https://example.com',
          accessToken: 'token-a',
        );
        final auth = _FakeAuthService(() async => false, storage: storage);
        final repository = _FakeActivityRepository();
        final activity = _activityFixture();
        await repository.create(activity);
        final client = MockClient((request) async {
          return http.Response(
            json.encode({
              'id': 1234,
              'distance': 76,
              'total_timer_time': 59,
              'elevation_gain': 2,
              'elevation_loss': 2,
            }),
            201,
          );
        });
        final service = ActivityUploadService(
          apiClient: ApiClient(
            storage: storage,
            authService: auth,
            requestExecutor: ApiRequestExecutor(client),
          ),
          storage: storage,
          authService: auth,
          gpxExporter: GpxExporter(),
          queueService: _FakeUploadQueueService(),
          activityRepository: repository,
        );

        final result = await service.uploadActivity(activity);
        final stored = await repository.getById(activity.id);

        expect(result.success, isTrue);
        expect(stored, isNotNull);
        expect(stored!.uploaded, isTrue);
        expect(stored.distanceMeters, equals(76));
        expect(stored.durationSeconds, equals(59));
        expect(stored.elevationGainMeters, equals(2));
        expect(stored.elevationLossMeters, equals(2));
      },
    );

    test('multipart-gpx wird nicht als text/plain gesendet', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: 'token-a',
      );
      final auth = _FakeAuthService(() async => false, storage: storage);
      String? multipartBody;
      String? idempotencyHeader;
      String? activityIdHeader;
      final client = MockClient((request) async {
        multipartBody = request.body;
        idempotencyHeader = request.headers['idempotency-key'];
        activityIdHeader = request.headers['x-upload-activity-id'];
        return http.Response('', 201);
      });
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: ApiRequestExecutor(client),
      );
      final service = ActivityUploadService(
        apiClient: apiClient,
        storage: storage,
        authService: auth,
        gpxExporter: GpxExporter(),
        queueService: _FakeUploadQueueService(),
      );

      final result = await service.uploadActivity(_activityFixture());

      expect(result.success, isTrue);
      expect(multipartBody, isNotNull);
      expect(multipartBody, isNot(contains('Content-Type: text/plain')));
      expect(multipartBody, contains('name="hidden"'));
      expect(multipartBody, contains('name="visibility"'));
      expect(multipartBody, contains('name="is_public"'));
      expect(idempotencyHeader, equals('endurain-upload-upload-1'));
      expect(activityIdHeader, equals('upload-1'));
      expect(
        multipartBody,
        contains(RegExp(r'filename="2026-03-09_\d{2}-\d{2}_Run\.gpx"')),
      );
    });

    test(
      'gleichzeitige Uploads derselben Activity werden dedupliziert',
      () async {
        final storage = _FakeStorageService(
          serverUrl: 'https://example.com',
          accessToken: 'token-a',
        );
        final auth = _FakeAuthService(() async => false, storage: storage);
        var calls = 0;
        final client = MockClient((request) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return http.Response('', 201);
        });
        final apiClient = ApiClient(
          storage: storage,
          authService: auth,
          requestExecutor: ApiRequestExecutor(client),
        );
        final service = ActivityUploadService(
          apiClient: apiClient,
          storage: storage,
          authService: auth,
          gpxExporter: GpxExporter(),
          queueService: _FakeUploadQueueService(),
        );

        final activity = _activityFixture();
        final results = await Future.wait([
          service.uploadActivity(activity),
          service.uploadActivity(activity),
        ]);

        expect(results[0].success, isTrue);
        expect(results[1].success, isTrue);
        expect(calls, equals(1));
      },
    );

    test('5xx wird begrenzt retried und kann erfolgreich enden', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: 'token-a',
      );
      final auth = _FakeAuthService(() async => false, storage: storage);
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls < 3) return http.Response('', 500);
        return http.Response('', 200);
      });
      final executor = ApiRequestExecutor(client);
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: executor,
      );
      final gpxExporter = GpxExporter();
      final service = ActivityUploadService(
        apiClient: apiClient,
        storage: storage,
        authService: auth,
        gpxExporter: gpxExporter,
        queueService: _FakeUploadQueueService(),
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
        final auth = _FakeAuthService(() async => false, storage: storage);
        var calls = 0;
        final client = MockClient((request) async {
          calls++;
          throw http.ClientException('socket failed');
        });
        final executor = ApiRequestExecutor(client);
        final apiClient = ApiClient(
          storage: storage,
          authService: auth,
          requestExecutor: executor,
        );
        final gpxExporter = GpxExporter();
        final service = ActivityUploadService(
          apiClient: apiClient,
          storage: storage,
          authService: auth,
          gpxExporter: gpxExporter,
          queueService: _FakeUploadQueueService(),
        );

        final result = await service.uploadActivity(_activityFixture());

        expect(result.success, isFalse);
        expect(result.failureType, ActivityUploadFailureType.network);
        expect(result.attempts, equals(3));
        expect(result.serverDetail, isNotEmpty);
        expect(calls, equals(3));
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
      }, storage: storage);
      var calls = 0;
      final seenAuth = <String?>[];
      final client = MockClient((request) async {
        calls++;
        seenAuth.add(request.headers['authorization']);
        if (calls == 1) return http.Response('', 401);
        return http.Response('', 200);
      });
      final executor = ApiRequestExecutor(client);
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: executor,
      );
      final gpxExporter = GpxExporter();
      final service = ActivityUploadService(
        apiClient: apiClient,
        storage: storage,
        authService: auth,
        gpxExporter: gpxExporter,
        queueService: _FakeUploadQueueService(),
      );

      final result = await service.uploadActivity(_activityFixture());

      expect(result.success, isTrue);
      // ApiClient handles the retry internally. ActivityUploadService sees one successful call.
      // But MockClient sees 2 calls.
      expect(refreshCalls, equals(1));
      expect(seenAuth, equals(['Bearer token-old', 'Bearer token-new']));
    });

    test('fehlender access token nutzt refresh und upload gelingt', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: null,
      );
      var refreshCalls = 0;
      final auth = _FakeAuthService(() async {
        refreshCalls++;
        storage.accessToken = 'token-refreshed';
        return true;
      }, storage: storage);
      final seenAuth = <String?>[];
      final client = MockClient((request) async {
        seenAuth.add(request.headers['authorization']);
        return http.Response('', 200);
      });
      final executor = ApiRequestExecutor(client);
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: executor,
      );
      final service = ActivityUploadService(
        apiClient: apiClient,
        storage: storage,
        authService: auth,
        gpxExporter: GpxExporter(),
        queueService: _FakeUploadQueueService(),
      );

      final result = await service.uploadActivity(_activityFixture());

      expect(result.success, isTrue);
      expect(refreshCalls, equals(1));
      expect(seenAuth, equals(['Bearer token-refreshed']));
    });

    test(
      '401 ohne erfolgreichen refresh endet mit authentication failure',
      () async {
        final storage = _FakeStorageService(
          serverUrl: 'https://example.com',
          accessToken: 'token-old',
        );
        final auth = _FakeAuthService(() async => false, storage: storage);
        final client = MockClient((request) async => http.Response('', 401));
        final executor = ApiRequestExecutor(client);
        final apiClient = ApiClient(
          storage: storage,
          authService: auth,
          requestExecutor: executor,
        );
        final gpxExporter = GpxExporter();
        final service = ActivityUploadService(
          apiClient: apiClient,
          storage: storage,
          authService: auth,
          gpxExporter: gpxExporter,
          queueService: _FakeUploadQueueService(),
        );

        final result = await service.uploadActivity(_activityFixture());

        expect(result.success, isFalse);
        expect(result.failureType, ActivityUploadFailureType.authentication);
        expect(result.serverDetail, contains('Session expired'));
      },
    );

    test('405 auf POST wechselt auf PUT und endet erfolgreich', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: 'token-a',
      );
      final auth = _FakeAuthService(() async => false, storage: storage);
      final seenMethods = <String>[];
      final client = MockClient((request) async {
        seenMethods.add(request.method);
        if (request.method == 'POST') return http.Response('', 405);
        return http.Response('', 201);
      });
      final executor = ApiRequestExecutor(client);
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: executor,
      );
      final gpxExporter = GpxExporter();
      final service = ActivityUploadService(
        apiClient: apiClient,
        storage: storage,
        authService: auth,
        gpxExporter: gpxExporter,
        queueService: _FakeUploadQueueService(),
      );

      final result = await service.uploadActivity(_activityFixture());

      expect(result.success, isTrue);
      expect(seenMethods, containsAllInOrder(['POST', 'PUT']));
    });

    test(
      'upload funktioniert auch wenn serverUrl bereits /api/v1 enthaelt',
      () async {
        final storage = _FakeStorageService(
          serverUrl: 'https://example.com/api/v1',
          accessToken: 'token-a',
        );
        final auth = _FakeAuthService(() async => false, storage: storage);
        final seenPaths = <String>[];
        final client = MockClient((request) async {
          seenPaths.add(request.url.path);
          if (request.url.path == '/api/v1/activities/create/upload') {
            return http.Response('', 201);
          }
          return http.Response('', 405);
        });
        final executor = ApiRequestExecutor(client);
        final apiClient = ApiClient(
          storage: storage,
          authService: auth,
          requestExecutor: executor,
        );
        final gpxExporter = GpxExporter();
        final service = ActivityUploadService(
          apiClient: apiClient,
          storage: storage,
          authService: auth,
          gpxExporter: gpxExporter,
          queueService: _FakeUploadQueueService(),
        );

        final result = await service.uploadActivity(_activityFixture());

        expect(result.success, isTrue);
        expect(
          seenPaths,
          isNot(contains('/api/v1/api/v1/activities/create/upload')),
        );
        expect(seenPaths, contains('/api/v1/activities/create/upload'));
      },
    );

    test('liefert server-detail aus json-fehlerantwort', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: 'token-a',
      );
      final auth = _FakeAuthService(() async => false, storage: storage);
      final client = MockClient(
        (request) async =>
            http.Response('{"detail":"invalid GPX format"}', 422),
      );
      final executor = ApiRequestExecutor(client);
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: executor,
      );
      final gpxExporter = GpxExporter();
      final service = ActivityUploadService(
        apiClient: apiClient,
        storage: storage,
        authService: auth,
        gpxExporter: gpxExporter,
        queueService: _FakeUploadQueueService(),
      );

      final result = await service.uploadActivity(_activityFixture());

      expect(result.success, isFalse);
      expect(result.statusCode, equals(422));
      expect(result.serverDetail, equals('invalid GPX format'));
    });

    test('processQueue entfernt item nach erfolgreichem retry', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: 'token-a',
      );
      final auth = _FakeAuthService(() async => false, storage: storage);
      var calls = 0;
      var allowSuccess = false;
      final client = MockClient((request) async {
        calls++;
        if (!allowSuccess) {
          return http.Response('', 500);
        }
        return http.Response('', 201);
      });
      final executor = ApiRequestExecutor(client);
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: executor,
      );
      final queue = _FakeUploadQueueService();
      final repository = _FakeActivityRepository();
      final service = ActivityUploadService(
        apiClient: apiClient,
        storage: storage,
        authService: auth,
        gpxExporter: GpxExporter(),
        queueService: queue,
        activityRepository: repository,
      );

      final activity = _activityFixture();
      await repository.create(activity);
      final firstResult = await service.uploadActivity(activity);
      expect(firstResult.success, isFalse);

      final queued = await queue.getQueue();
      expect(queued, hasLength(1));

      allowSuccess = true;
      await service.processQueue();

      final afterProcess = await queue.getQueue();
      final storedAfter = await repository.getById(activity.id);
      expect(afterProcess, isEmpty);
      expect(queue.removedIds, contains(activity.id));
      expect(storedAfter?.uploaded, isTrue);
      expect(calls, greaterThanOrEqualTo(2));
    });

    test('delete nutzt activities/{id}/delete und endet erfolgreich', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: 'token-a',
      );
      final auth = _FakeAuthService(() async => false, storage: storage);
      final activity = _activityFixture().copyWith(id: '321');
      final seenPaths = <String>[];
      final client = MockClient((request) async {
        seenPaths.add(request.url.path);
        if (request.url.path == '/api/v1/activities/321/delete') {
          return http.Response('', 204);
        }
        return http.Response('', 404);
      });
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: ApiRequestExecutor(client),
      );
      final service = ActivityUploadService(
        apiClient: apiClient,
        storage: storage,
        authService: auth,
        gpxExporter: GpxExporter(),
        queueService: _FakeUploadQueueService(),
      );

      final result = await service.deleteActivity(activity);

      expect(result.success, isTrue);
      expect(result.statusCode, equals(204));
      expect(seenPaths, contains('/api/v1/activities/321/delete'));
    });

    test(
      'upload persistiert server_activity_id aus erfolgreicher Serverantwort',
      () async {
        final storage = _FakeStorageService(
          serverUrl: 'https://example.com',
          accessToken: 'token-a',
        );
        final auth = _FakeAuthService(() async => false, storage: storage);
        final repository = _FakeActivityRepository();
        final activity = _activityFixture();
        await repository.create(activity);
        final client = MockClient(
          (request) async => http.Response('[{"id": 321}]', 201),
        );
        final service = ActivityUploadService(
          apiClient: ApiClient(
            storage: storage,
            authService: auth,
            requestExecutor: ApiRequestExecutor(client),
          ),
          storage: storage,
          authService: auth,
          gpxExporter: GpxExporter(),
          queueService: _FakeUploadQueueService(),
          activityRepository: repository,
        );

        final result = await service.uploadActivity(activity);
        final stored = await repository.getById(activity.id);

        expect(result.success, isTrue);
        expect(result.serverActivityId, equals(321));
        expect(stored?.uploaded, isTrue);
        expect(stored?.qualityMetrics?['server_activity_id'], equals(321));
      },
    );

    test('delete nutzt zuerst gespeicherte server_activity_id', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: 'token-a',
      );
      final auth = _FakeAuthService(() async => false, storage: storage);
      final seenPaths = <String>[];
      final client = MockClient((request) async {
        seenPaths.add(request.url.path);
        if (request.url.path == '/api/v1/activities/321/delete') {
          return http.Response('', 204);
        }
        return http.Response('', 404);
      });
      final service = ActivityUploadService(
        apiClient: ApiClient(
          storage: storage,
          authService: auth,
          requestExecutor: ApiRequestExecutor(client),
        ),
        storage: storage,
        authService: auth,
        gpxExporter: GpxExporter(),
        queueService: _FakeUploadQueueService(),
      );
      final uploadedActivity = _activityFixture().copyWith(
        uploaded: true,
        qualityMetrics: <String, dynamic>{'server_activity_id': 321},
      );

      final result = await service.deleteActivity(uploadedActivity);

      expect(result.success, isTrue);
      expect(seenPaths.first, equals('/api/v1/activities/321/delete'));
    });

    test(
      'delete priorisiert nicht-405 Fehlerdetail gegenüber späterem 405',
      () async {
        final storage = _FakeStorageService(
          serverUrl: 'https://example.com',
          accessToken: 'token-a',
        );
        final auth = _FakeAuthService(() async => false, storage: storage);
        final activity = _activityFixture().copyWith(id: '123');
        final client = MockClient((request) async {
          if (request.url.path == '/api/v1/activities/123/delete') {
            return http.Response('{"detail":"Activity ID invalid"}', 404);
          }
          return http.Response('Method Not Allowed', 405);
        });
        final service = ActivityUploadService(
          apiClient: ApiClient(
            storage: storage,
            authService: auth,
            requestExecutor: ApiRequestExecutor(client),
          ),
          storage: storage,
          authService: auth,
          gpxExporter: GpxExporter(),
          queueService: _FakeUploadQueueService(),
        );

        final result = await service.deleteActivity(activity);

        expect(result.success, isFalse);
        expect(result.statusCode, equals(404));
        expect(result.serverDetail, contains('Activity ID invalid'));
      },
    );

    test(
      'delete überspringt inkompatible lokale IDs und liefert klare Fehlermeldung',
      () async {
        final storage = _FakeStorageService(
          serverUrl: 'https://example.com',
          accessToken: 'token-a',
        );
        final auth = _FakeAuthService(() async => false, storage: storage);
        var calls = 0;
        final client = MockClient((request) async {
          calls++;
          return http.Response('', 500);
        });
        final service = ActivityUploadService(
          apiClient: ApiClient(
            storage: storage,
            authService: auth,
            requestExecutor: ApiRequestExecutor(client),
          ),
          storage: storage,
          authService: auth,
          gpxExporter: GpxExporter(),
          queueService: _FakeUploadQueueService(),
        );
        final activity = _activityFixture().copyWith(
          id: '1742338800000000',
          uploaded: true,
        );

        final result = await service.deleteActivity(activity);

        expect(result.success, isFalse);
        expect(calls, equals(0));
        expect(result.serverDetail, contains('no compatible server id'));
      },
    );

    test('delete 401 ohne refresh liefert authentication failure', () async {
      final storage = _FakeStorageService(
        serverUrl: 'https://example.com',
        accessToken: 'token-old',
      );
      final auth = _FakeAuthService(() async => false, storage: storage);
      final client = MockClient((request) async => http.Response('', 401));
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: ApiRequestExecutor(client),
      );
      final service = ActivityUploadService(
        apiClient: apiClient,
        storage: storage,
        authService: auth,
        gpxExporter: GpxExporter(),
        queueService: _FakeUploadQueueService(),
      );

      final result = await service.deleteActivity(
        _activityFixture().copyWith(id: '123'),
      );

      expect(result.success, isFalse);
      expect(result.failureType, ActivityUploadFailureType.authentication);
    });

    test(
      'processQueue stoppt bei authentication failure und laesst rest in queue',
      () async {
        final storage = _FakeStorageService(
          serverUrl: 'https://example.com',
          accessToken: 'token-old',
        );
        final auth = _FakeAuthService(() async => false, storage: storage);
        final client = MockClient((request) async => http.Response('', 401));
        final executor = ApiRequestExecutor(client);
        final apiClient = ApiClient(
          storage: storage,
          authService: auth,
          requestExecutor: executor,
        );
        final queue = _FakeUploadQueueService();
        final service = ActivityUploadService(
          apiClient: apiClient,
          storage: storage,
          authService: auth,
          gpxExporter: GpxExporter(),
          queueService: queue,
        );

        final first = _activityFixture();
        final second = _activityFixture().copyWith(id: 'upload-2');
        await queue.addToQueue(first);
        await queue.addToQueue(second);

        await service.processQueue();

        final remaining = await queue.getQueue();
        expect(
          remaining.map((a) => a.id).toList(),
          equals(['upload-1', 'upload-2']),
        );
      },
    );
  });
}
