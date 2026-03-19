import 'dart:async';
import 'dart:convert';

import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/services/api_request_executor.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSecureStorageService extends SecureStorageService {
  String? serverUrl;
  String? username;
  String? accessToken;
  String? refreshToken;
  String? sessionId;
  int clearAuthTokensCalls = 0;

  @override
  Future<String?> getServerUrl() async => serverUrl;

  @override
  Future<void> setServerUrl(String url) async {
    serverUrl = url;
  }

  @override
  Future<void> setUsername(String usernameValue) async {
    username = usernameValue;
  }

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> setRefreshToken(String token) async {
    refreshToken = token;
  }

  @override
  Future<void> setAccessToken(String token) async {
    accessToken = token;
  }

  @override
  Future<void> setSessionId(String sessionIdValue) async {
    sessionId = sessionIdValue;
  }

  @override
  Future<void> clearAuthTokens() async {
    clearAuthTokensCalls += 1;
    accessToken = null;
    refreshToken = null;
    sessionId = null;
  }
}

void main() {
  const baseUrl = 'https://endurain.example.com';

  group('AuthService', () {
    test('login success inkl. session exchange', () async {
      final storage = FakeSecureStorageService();
      final client = MockClient((request) async {
        if (request.url.path == ApiConstants.tokenEndpoint) {
          return http.Response(json.encode({'session_id': 'session-1'}), 200);
        }
        if (request.url.path ==
            '${ApiConstants.idpSessionTokenExchangeEndpoint}/session-1/tokens') {
          return http.Response(
            json.encode({
              'access_token': 'access-1',
              'refresh_token': 'refresh-1',
              'session_id': 'session-1',
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });
      final service = AuthService(
        storage: storage,
        requestExecutor: ApiRequestExecutor(client),
      );

      final result = await service.login('alice', 'secret', serverUrl: baseUrl);

      expect(result.success, isTrue);
      expect(result.mfaRequired, isFalse);
      expect(result.accessToken, equals('access-1'));
      expect(result.refreshToken, equals('refresh-1'));
      expect(storage.serverUrl, equals(baseUrl));
      expect(storage.username, equals('alice'));
      expect(storage.accessToken, equals('access-1'));
      expect(storage.refreshToken, equals('refresh-1'));
      expect(storage.sessionId, equals('session-1'));
    });

    test('login mit mfa_required=true', () async {
      final storage = FakeSecureStorageService();
      final client = MockClient((request) async {
        if (request.url.path == ApiConstants.tokenEndpoint) {
          return http.Response(
            json.encode({
              'mfa_required': true,
              'username': 'alice',
              'message': 'MFA required',
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });
      final service = AuthService(
        storage: storage,
        requestExecutor: ApiRequestExecutor(client),
      );

      final result = await service.login('alice', 'secret', serverUrl: baseUrl);

      expect(result.success, isTrue);
      expect(result.mfaRequired, isTrue);
      expect(result.username, equals('alice'));
      expect(storage.username, equals('alice'));
    });

    test('verifyMfa success', () async {
      final storage = FakeSecureStorageService()..serverUrl = baseUrl;
      final client = MockClient((request) async {
        if (request.url.path == ApiConstants.tokenEndpoint) {
          return http.Response(
            json.encode({'mfa_required': true, 'username': 'alice'}),
            200,
          );
        }
        if (request.url.path == ApiConstants.mfaVerifyEndpoint) {
          return http.Response(json.encode({'session_id': 'session-2'}), 200);
        }
        if (request.url.path ==
            '${ApiConstants.idpSessionTokenExchangeEndpoint}/session-2/tokens') {
          return http.Response(
            json.encode({
              'access_token': 'access-2',
              'refresh_token': 'refresh-2',
              'session_id': 'session-2',
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });
      final service = AuthService(
        storage: storage,
        requestExecutor: ApiRequestExecutor(client),
      );

      await service.login('alice', 'secret', serverUrl: baseUrl);
      final result = await service.verifyMfa('alice', '123456');

      expect(result.success, isTrue);
      expect(result.mfaRequired, isFalse);
      expect(storage.accessToken, equals('access-2'));
      expect(storage.refreshToken, equals('refresh-2'));
    });

    test('verifyMfa failure', () async {
      final storage = FakeSecureStorageService()..serverUrl = baseUrl;
      final client = MockClient((request) async {
        if (request.url.path == ApiConstants.tokenEndpoint) {
          return http.Response(
            json.encode({'mfa_required': true, 'username': 'alice'}),
            200,
          );
        }
        if (request.url.path == ApiConstants.mfaVerifyEndpoint) {
          return http.Response(
            json.encode({'detail': 'Invalid MFA code'}),
            401,
          );
        }
        return http.Response('not found', 404);
      });
      final service = AuthService(
        storage: storage,
        requestExecutor: ApiRequestExecutor(client),
      );
      await service.login('alice', 'secret', serverUrl: baseUrl);

      expect(
        () => service.verifyMfa('alice', '000000'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('MFA verification error'),
          ),
        ),
      );
    });

    test('refreshToken success', () async {
      final storage = FakeSecureStorageService()
        ..serverUrl = baseUrl
        ..refreshToken = 'refresh-old';
      final client = MockClient((request) async {
        if (request.url.path == ApiConstants.refreshEndpoint) {
          return http.Response(
            json.encode({
              'access_token': 'access-new',
              'refresh_token': 'refresh-new',
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });
      final service = AuthService(
        storage: storage,
        requestExecutor: ApiRequestExecutor(client),
      );

      final refreshed = await service.refreshToken();

      expect(refreshed, isTrue);
      expect(storage.accessToken, equals('access-new'));
      expect(storage.refreshToken, equals('refresh-new'));
    });

    test('refreshToken failure', () async {
      final storage = FakeSecureStorageService()
        ..serverUrl = baseUrl
        ..accessToken = 'access-old'
        ..refreshToken = 'refresh-old';
      final client = MockClient((request) async {
        if (request.url.path == ApiConstants.refreshEndpoint) {
          return http.Response(json.encode({'detail': 'expired'}), 401);
        }
        return http.Response('not found', 404);
      });
      final service = AuthService(
        storage: storage,
        requestExecutor: ApiRequestExecutor(client),
      );

      final refreshed = await service.refreshToken();

      expect(refreshed, isFalse);
      expect(storage.clearAuthTokensCalls, equals(1));
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
    });

    test('refreshToken dedupliziert parallele Aufrufe', () async {
      final storage = FakeSecureStorageService()
        ..serverUrl = baseUrl
        ..refreshToken = 'refresh-old';
      final responseCompleter = Completer<http.Response>();
      var refreshRequestCount = 0;
      final client = MockClient((request) async {
        if (request.url.path == ApiConstants.refreshEndpoint) {
          refreshRequestCount += 1;
          return responseCompleter.future;
        }
        return http.Response('not found', 404);
      });
      final service = AuthService(
        storage: storage,
        requestExecutor: ApiRequestExecutor(client),
      );

      final first = service.refreshToken();
      final second = service.refreshToken();
      await Future<void>.delayed(Duration.zero);

      expect(refreshRequestCount, equals(1));

      responseCompleter.complete(
        http.Response(
          json.encode({
            'access_token': 'access-new',
            'refresh_token': 'refresh-new',
          }),
          200,
        ),
      );

      final results = await Future.wait(<Future<bool>>[first, second]);
      expect(results, everyElement(isTrue));
      expect(storage.accessToken, equals('access-new'));
      expect(storage.refreshToken, equals('refresh-new'));
    });

    test('logout success + lokales Token-Clearing', () async {
      final storage = FakeSecureStorageService()
        ..serverUrl = baseUrl
        ..refreshToken = 'refresh-logout'
        ..accessToken = 'access-logout'
        ..sessionId = 'session-logout';
      final client = MockClient((request) async {
        if (request.url.path == ApiConstants.logoutEndpoint) {
          return http.Response('', 200);
        }
        return http.Response('not found', 404);
      });
      final service = AuthService(
        storage: storage,
        requestExecutor: ApiRequestExecutor(client),
      );

      final result = await service.logout();

      expect(result, isTrue);
      expect(storage.clearAuthTokensCalls, equals(1));
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
      expect(storage.sessionId, isNull);
    });

    test('logout failure + lokales Token-Clearing bleibt garantiert', () async {
      final storage = FakeSecureStorageService()
        ..serverUrl = baseUrl
        ..refreshToken = 'refresh-logout'
        ..accessToken = 'access-logout'
        ..sessionId = 'session-logout';
      final client = MockClient((request) async {
        if (request.url.path == ApiConstants.logoutEndpoint) {
          return http.Response('', 500);
        }
        return http.Response('not found', 404);
      });
      final service = AuthService(
        storage: storage,
        requestExecutor: ApiRequestExecutor(client),
      );

      final result = await service.logout();

      expect(result, isFalse);
      expect(storage.clearAuthTokensCalls, equals(1));
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
      expect(storage.sessionId, isNull);
    });
  });
}
