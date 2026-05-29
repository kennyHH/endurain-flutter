import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('AuthService', () {
    test('stores tokens after login session exchange succeeds', () async {
      final storage = SecureStorageService();
      final requests = <http.Request>[];
      final service = AuthService(
        storage: storage,
        httpClient: MockClient((request) async {
          requests.add(request);

          if (request.url.path == ApiConstants.tokenEndpoint) {
            expect(request.bodyFields['username'], 'joao');
            expect(request.bodyFields['password'], 'secret');
            return http.Response('{"session_id":"session-1"}', 200);
          }

          if (request.url.path ==
              '${ApiConstants.idpSessionTokenExchangeEndpoint}/session-1/tokens') {
            return http.Response(
              '{"access_token":"access-1","refresh_token":"refresh-1","session_id":"session-2","expires_in":3600}',
              200,
            );
          }

          fail('Unexpected request to ${request.url}');
        }),
      );

      final result = await service.login(
        'joao',
        'secret',
        serverUrl: 'https://example.test',
      );

      expect(result.success, isTrue);
      expect(result.mfaRequired, isFalse);
      expect(result.accessToken, 'access-1');
      expect(await storage.getAccessToken(), 'access-1');
      expect(await storage.getRefreshToken(), 'refresh-1');
      expect(await storage.getSessionId(), 'session-2');
      expect(await storage.getUsername(), 'joao');
      expect(requests, hasLength(2));
    });

    test('returns MFA state without exchanging tokens', () async {
      final storage = SecureStorageService();
      final service = AuthService(
        storage: storage,
        httpClient: MockClient((request) async {
          return http.Response(
            '{"mfa_required":true,"username":"joao","message":"MFA required"}',
            200,
          );
        }),
      );

      final result = await service.login(
        'joao',
        'secret',
        serverUrl: 'https://example.test',
      );

      expect(result.mfaRequired, isTrue);
      expect(result.username, 'joao');
      expect(result.message, 'MFA required');
      expect(await storage.getUsername(), 'joao');
      expect(await storage.getAccessToken(), isNull);
    });

    test('throws typed login failure with server detail', () async {
      final service = AuthService(
        storage: SecureStorageService(),
        httpClient: MockClient((request) async {
          return http.Response('{"detail":"Bad credentials"}', 401);
        }),
      );

      expect(
        () => service.login('joao', 'wrong', serverUrl: 'https://example.test'),
        throwsA(
          isA<AppException>()
              .having(
                (exception) => exception.code,
                'code',
                AppErrorCode.loginFailed,
              )
              .having(
                (exception) => exception.details,
                'details',
                'Bad credentials',
              ),
        ),
      );
    });
  });
}
