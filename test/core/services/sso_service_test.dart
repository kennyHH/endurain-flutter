import 'package:endurain/core/services/api_request_executor.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/sso_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeStorage extends SecureStorageService {
  _FakeStorage({this.serverUrl});

  String? serverUrl;
  String? accessToken;
  String? refreshToken;
  String? sessionId;

  @override
  Future<String?> getServerUrl() async => serverUrl;

  @override
  Future<void> setAccessToken(String token) async {
    accessToken = token;
  }

  @override
  Future<void> setRefreshToken(String token) async {
    refreshToken = token;
  }

  @override
  Future<void> setSessionId(String id) async {
    sessionId = id;
  }
}

void main() {
  group('SsoService', () {
    test('getEnabledProviders verarbeitet Listen-Response', () async {
      final service = SsoService(
        storage: _FakeStorage(serverUrl: 'https://endurain.example.com'),
        requestExecutor: ApiRequestExecutor(
          MockClient(
            (_) async => http.Response(
              '[{"id":1,"name":"Keycloak","slug":"keycloak"}]',
              200,
            ),
          ),
        ),
      );

      final providers = await service.getEnabledProviders();

      expect(providers, hasLength(1));
      expect(providers.first.slug, equals('keycloak'));
      expect(providers.first.name, equals('Keycloak'));
    });

    test(
      'getEnabledProviders verarbeitet Objekt-Response mit providers-Feld',
      () async {
        final service = SsoService(
          storage: _FakeStorage(serverUrl: 'https://endurain.example.com'),
          requestExecutor: ApiRequestExecutor(
            MockClient(
              (_) async => http.Response(
                '{"providers":[{"id":2,"name":"Authentik","slug":"authentik"}]}',
                200,
              ),
            ),
          ),
        );

        final providers = await service.getEnabledProviders();

        expect(providers, hasLength(1));
        expect(providers.first.slug, equals('authentik'));
      },
    );

    test(
      'getEnabledProviders liefert Fehler bei unerwartetem Format',
      () async {
        final service = SsoService(
          storage: _FakeStorage(serverUrl: 'https://endurain.example.com'),
          requestExecutor: ApiRequestExecutor(
            MockClient((_) async => http.Response('{"foo":"bar"}', 200)),
          ),
        );

        expect(
          () => service.getEnabledProviders(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Unexpected response format'),
            ),
          ),
        );
      },
    );

    test(
      'initiateOAuth erzeugt URL mit PKCE challenge und expected params',
      () async {
        final service = SsoService(
          storage: _FakeStorage(serverUrl: 'https://endurain.example.com'),
          requestExecutor: ApiRequestExecutor(
            MockClient((_) async => throw UnimplementedError()),
          ),
        );

        final oauthUrl = await service.initiateOAuth('keycloak');
        final uri = Uri.parse(oauthUrl);

        expect(
          uri.toString().startsWith(
            'https://endurain.example.com/api/v1/public/idp/login/keycloak',
          ),
          isTrue,
        );
        expect(uri.queryParameters['code_challenge'], isNotEmpty);
        expect(uri.queryParameters['code_challenge_method'], equals('S256'));
        expect(uri.queryParameters['redirect'], equals('/dashboard'));
      },
    );

    test(
      'exchangeSessionForTokens success speichert Tokens und Session',
      () async {
        final storage = _FakeStorage(serverUrl: 'https://endurain.example.com');
        final service = SsoService(
          storage: storage,
          requestExecutor: ApiRequestExecutor(
            MockClient((request) async {
              if (request.method == 'POST') {
                return http.Response('''
              {
                "access_token":"access-123",
                "refresh_token":"refresh-456",
                "session_id":"session-789"
              }
              ''', 200);
              }
              return http.Response('[]', 200);
            }),
          ),
        );

        await service.initiateOAuth('keycloak');
        final result = await service.exchangeSessionForTokens(
          'session-from-webview',
        );

        expect(result.success, isTrue);
        expect(result.mfaRequired, isFalse);
        expect(storage.accessToken, equals('access-123'));
        expect(storage.refreshToken, equals('refresh-456'));
        expect(storage.sessionId, equals('session-789'));
      },
    );

    test(
      'exchangeSessionForTokens failure liefert erwarteten Fehler',
      () async {
        final service = SsoService(
          storage: _FakeStorage(serverUrl: 'https://endurain.example.com'),
          requestExecutor: ApiRequestExecutor(
            MockClient(
              (_) async => http.Response('{"detail":"Invalid session"}', 400),
            ),
          ),
        );

        await service.initiateOAuth('keycloak');

        expect(
          () => service.exchangeSessionForTokens('invalid'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('SSO token exchange error'),
            ),
          ),
        );
      },
    );

    test(
      'exchangeSessionForTokens ohne PKCE verifier liefert Fehler',
      () async {
        final service = SsoService(
          storage: _FakeStorage(serverUrl: 'https://endurain.example.com'),
          requestExecutor: ApiRequestExecutor(
            MockClient((_) async => throw UnimplementedError()),
          ),
        );

        expect(
          () => service.exchangeSessionForTokens('session'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('PKCE verifier not found'),
            ),
          ),
        );
      },
    );

    test('wirft Fehler wenn keine Server-URL konfiguriert ist', () async {
      final service = SsoService(
        storage: _FakeStorage(serverUrl: null),
        requestExecutor: ApiRequestExecutor(
          MockClient((_) async => throw UnimplementedError()),
        ),
      );

      expect(
        () => service.getEnabledProviders(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Server URL not configured'),
          ),
        ),
      );
    });
  });
}
