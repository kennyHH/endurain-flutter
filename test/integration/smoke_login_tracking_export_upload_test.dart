import 'dart:async';
import 'dart:convert';

import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/constants/upload_constants.dart';
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/services/activity_upload_service.dart';
import 'package:endurain/core/services/api_request_executor.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/core/services/upload_queue/upload_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endurain/core/services/gpx_exporter.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/bluetooth_sensor_service.dart';
import 'package:endurain/core/services/audio_feedback_service.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;

class MockAudioFeedbackService implements AudioFeedbackService {
  @override
  bool get isEnabled => false;

  @override
  Stream<bool> get enabledStream => const Stream<bool>.empty();

  @override
  Future<void> announceCountdown(int seconds) async {}

  @override
  Future<void> announceGpsStatus({required bool isLost}) async {}

  @override
  Future<void> announceSplit({
    required int km,
    required double paceSecondsPerKm,
  }) async {}

  @override
  Future<void> announceStart() async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setEnabledWithAnnouncement(bool enabled) async {}

  @override
  void toggleEnabled(bool enabled) {}

  @override
  Future<void> updateSettings({
    required bool enabled,
    required bool announceSplits,
    required bool announceStart,
    bool announceGps = true,
  }) async {}

  @override
  Future<void> setVolume(double volume) async {}
}

class _FakeStorageService extends SecureStorageService {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> getServerUrl() async => _store['serverUrl'];

  @override
  Future<void> setServerUrl(String url) async {
    _store['serverUrl'] = url;
  }

  @override
  Future<String?> getAccessToken() async => _store['accessToken'];

  @override
  Future<void> setAccessToken(String token) async {
    _store['accessToken'] = token;
  }

  @override
  Future<String?> getRefreshToken() async => _store['refreshToken'];

  @override
  Future<void> setRefreshToken(String token) async {
    _store['refreshToken'] = token;
  }

  @override
  Future<void> setSessionId(String sessionId) async {
    _store['sessionId'] = sessionId;
  }

  @override
  Future<void> setUsername(String username) async {
    _store['username'] = username;
  }
}

class _FakeLocationService extends LocationService {
  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();

  @override
  Stream<Position> getPositionStream() => _controller.stream;

  @override
  Future<Position?> getLastKnownPosition() async => null;

  @override
  Future<Position> getCurrentPosition() async {
    return Position(
      latitude: 0,
      longitude: 0,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  void emit(Position sample) {
    _controller.add(sample);
  }

  Future<void> close() async {
    await _controller.close();
  }
}

class _FakeBluetoothService extends BluetoothSensorService {
  @override
  Stream<int> get heartRate => const Stream.empty();

  @override
  Stream<int> get cadence => const Stream.empty();
}

void main() {
  test('ENDU-017 Smoke: Login -> Tracking -> Stop -> Export -> Upload', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeStorageService();
    final requestedPaths = <String>[];
    String? uploadedBody;

    final mockClient = MockClient((request) async {
      requestedPaths.add(request.url.path);

      if (request.url.path == ApiConstants.tokenEndpoint) {
        return http.Response(
          jsonEncode(<String, dynamic>{'session_id': 'session-1'}),
          200,
          headers: {'content-type': ApiConstants.contentTypeJson},
        );
      }

      if (request.url.path ==
          '${ApiConstants.idpSessionTokenExchangeEndpoint}/session-1/tokens') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'access_token': 'access-token-1',
            'refresh_token': 'refresh-token-1',
            'session_id': 'session-1',
          }),
          200,
          headers: {'content-type': ApiConstants.contentTypeJson},
        );
      }

      if (request.url.path == UploadConstants.activityUploadEndpoint) {
        uploadedBody = request.body;
        expect(
          request.headers[ApiConstants.authorizationHeader],
          equals('Bearer access-token-1'),
          reason: 'Upload muss den Access-Token aus dem Login nutzen.',
        );
        return http.Response('', 201);
      }

      return http.Response('Not Found', 404);
    });

    final executor = ApiRequestExecutor(mockClient);
    final authService = AuthService(
      storage: storage,
      requestExecutor: executor,
    );
    final locationService = _FakeLocationService();
    final repository = InMemoryActivityRepository();
    final engine = TrackingSessionEngine(
      audioService: MockAudioFeedbackService(),
      activityRepository: repository,
      locationService: locationService,
      bluetoothService: _FakeBluetoothService(),
    );
    addTearDown(engine.dispose);
    addTearDown(locationService.close);

    final loginResult = await authService.login(
      'runner@endurain.test',
      'strong-pass',
      serverUrl: 'https://api.endurain.test',
    );
    expect(
      loginResult.success,
      isTrue,
      reason: 'Login ist der Einstiegspunkt fuer den kompletten Smoke-Flow.',
    );
    expect(
      loginResult.mfaRequired,
      isFalse,
      reason: 'Smoketest nutzt den direkten Happy Path ohne MFA.',
    );

    final startedAt = DateTime.parse('2026-03-09T10:00:00Z');
    final startOk = await engine.start(ActivityType.run, startedAt: startedAt);
    expect(startOk, isTrue, reason: 'Tracking muss erfolgreich starten.');

    locationService.emit(
      Position(
        latitude: 38.7223,
        longitude: -9.1393,
        timestamp: startedAt.add(const Duration(seconds: 5)),
        accuracy: 5.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      ),
    );
    locationService.emit(
      Position(
        latitude: 38.7230,
        longitude: -9.1380,
        timestamp: startedAt.add(const Duration(seconds: 35)),
        accuracy: 5.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final stoppedActivity = await engine.stop(
      endedAt: startedAt.add(const Duration(minutes: 10)),
    );
    expect(
      stoppedActivity,
      isNotNull,
      reason: 'Stop muss eine persistierbare Activity liefern.',
    );

    final activities = await repository.listAll();
    expect(
      activities,
      hasLength(1),
      reason: 'Gestoppte Session muss gespeichert sein.',
    );
    final activity = activities.single;
    expect(
      activity.distanceMeters,
      greaterThan(0),
      reason: 'Mit zwei unterschiedlichen Punkten muss Distanz > 0 sein.',
    );
    expect(
      activity.durationSeconds,
      equals(600),
      reason: 'Dauer muss aus fixen Start/Stop-Zeiten exakt berechnet sein.',
    );

    final gpx = GpxExporter().export(activity);
    expect(
      gpx,
      contains('<trkseg>'),
      reason: 'Export muss ein Track-Segment enthalten.',
    );
    expect(
      gpx,
      contains('<trkpt'),
      reason: 'Export muss Track-Punkte enthalten.',
    );

    final uploadService = ActivityUploadService(
      storage: storage,
      authService: authService,
      apiClient: ApiClient(
        storage: storage,
        authService: authService,
        requestExecutor: executor,
      ),
      queueService: UploadQueueService(),
      gpxExporter: GpxExporter(),
    );
    final uploadResult = await uploadService.uploadActivity(activity);

    expect(
      uploadResult.success,
      isTrue,
      reason: 'Upload-Trigger muss im Happy Path erfolgreich sein.',
    );
    expect(uploadResult.statusCode, equals(201));
    expect(
      uploadResult.attempts,
      equals(1),
      reason: 'Happy Path darf keine Retries benoetigen.',
    );
    expect(
      uploadedBody,
      contains('<gpx'),
      reason: 'Upload-Payload muss GPX XML enthalten.',
    );
    expect(
      requestedPaths,
      containsAll(<String>[
        ApiConstants.tokenEndpoint,
        '${ApiConstants.idpSessionTokenExchangeEndpoint}/session-1/tokens',
        UploadConstants.activityUploadEndpoint,
      ]),
      reason:
          'Der komplette Smoke-Flow muss Login, Token-Exchange und Upload durchlaufen.',
    );
  });
}
