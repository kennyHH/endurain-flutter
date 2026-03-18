import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/error_handling/app_error.dart';
import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/core/services/api_request_executor.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeSecureStorageService extends SecureStorageService {
  FakeSecureStorageService({
    this.serverUrl = 'https://api.example.com',
    this.accessToken = 'access-token',
  });

  String? serverUrl;
  String? accessToken;
  String? refreshToken;

  @override
  Future<String?> getServerUrl() async => serverUrl;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<void> setAccessToken(String token) async {
    accessToken = token;
  }

  @override
  Future<void> clearAuthTokens() async {
    accessToken = null;
    refreshToken = null;
  }
}

class FakeAuthService extends AuthService {
  FakeAuthService({
    required this.fakeStorage,
    required super.requestExecutor,
    this.refreshSuccess = true,
  }) : super(storage: fakeStorage);

  final FakeSecureStorageService fakeStorage;
  bool refreshSuccess;
  int refreshCalls = 0;

  @override
  Future<bool> refreshToken() async {
    refreshCalls++;
    if (refreshSuccess) {
      await fakeStorage.setAccessToken('new-access-token');
      return true;
    }
    return false;
  }
}

void main() {
  group('ApiClient', () {
    test('request adds auth header and succeeds', () async {
      final storage = FakeSecureStorageService();
      final client = MockClient((request) async {
        expect(
          request.headers[ApiConstants.authorizationHeader],
          equals('Bearer access-token'),
        );
        return http.Response('ok', 200);
      });
      final executor = ApiRequestExecutor(client);
      final auth = FakeAuthService(
        fakeStorage: storage,
        requestExecutor: executor,
      );
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: executor,
      );

      final response = await apiClient.get('/test');
      expect(response.statusCode, equals(200));
      expect(response.body, equals('ok'));
    });

    test('request retries on 401 with refreshed token', () async {
      final storage = FakeSecureStorageService();
      var attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          expect(
            request.headers[ApiConstants.authorizationHeader],
            equals('Bearer access-token'),
          );
          return http.Response('unauthorized', 401);
        }
        expect(
          request.headers[ApiConstants.authorizationHeader],
          equals('Bearer new-access-token'),
        );
        return http.Response('ok', 200);
      });
      final executor = ApiRequestExecutor(client);
      final auth = FakeAuthService(
        fakeStorage: storage,
        requestExecutor: executor,
      );
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: executor,
      );

      final response = await apiClient.get('/test');
      expect(response.statusCode, equals(200));
      expect(response.body, equals('ok'));
      expect(auth.refreshCalls, equals(1));
    });

    test('request throws if refresh fails', () async {
      final storage = FakeSecureStorageService();
      final client = MockClient((request) async {
        return http.Response('unauthorized', 401);
      });
      final executor = ApiRequestExecutor(client);
      final auth = FakeAuthService(
        fakeStorage: storage,
        requestExecutor: executor,
        refreshSuccess: false,
      );
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: executor,
      );

      await expectLater(
        apiClient.get('/test'),
        throwsA(isA<AuthenticationError>()),
      );
      expect(auth.refreshCalls, equals(1));
      expect(storage.accessToken, isNull);
    });

    test('request tries refresh when access token missing', () async {
      final storage = FakeSecureStorageService()..accessToken = null;
      final client = MockClient((request) async {
        expect(
          request.headers[ApiConstants.authorizationHeader],
          equals('Bearer new-access-token'),
        );
        return http.Response('ok', 200);
      });
      final executor = ApiRequestExecutor(client);
      final auth = FakeAuthService(
        fakeStorage: storage,
        requestExecutor: executor,
        refreshSuccess: true,
      );
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: executor,
      );

      final response = await apiClient.get('/test');
      expect(response.statusCode, equals(200));
      expect(auth.refreshCalls, equals(1));
    });

    test('requestMultipart retries on 401', () async {
      final storage = FakeSecureStorageService();
      var attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          return http.Response('unauthorized', 401);
        }
        return http.Response('ok', 200);
      });
      final executor = ApiRequestExecutor(client);
      final auth = FakeAuthService(
        fakeStorage: storage,
        requestExecutor: executor,
      );
      final apiClient = ApiClient(
        storage: storage,
        authService: auth,
        requestExecutor: executor,
      );

      final file = UploadableFile.fromString(
        field: 'file',
        content: 'content',
        filename: 'test.txt',
      );
      final response = await apiClient.requestMultipart(
        method: 'POST',
        endpoint: '/upload',
        files: [file],
      );

      expect(response.statusCode, equals(200));
      expect(auth.refreshCalls, equals(1));
    });
  });
}
