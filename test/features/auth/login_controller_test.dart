import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/core/models/identity_provider.dart' as core;
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/server_settings_service.dart';
import 'package:endurain/core/services/sso_service.dart';
import 'package:endurain/features/auth/auth_coordinator.dart';
import 'package:endurain/features/auth/login_controller.dart';

import '../../helpers/fake_app_links_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('LoginController', () {
    test('loads server settings and SSO providers', () async {
      final storage = SecureStorageService();
      final controller = LoginController(
        authCoordinator: _repository(
          storage: storage,
          client: MockClient((request) async {
            if (request.url.path == ApiConstants.serverSettingsEndpoint) {
              return http.Response(
                '{"sso_enabled":true,"local_login_enabled":true}',
                200,
              );
            }
            if (request.url.path == ApiConstants.idpListEndpoint) {
              return http.Response(
                '[{"id":1,"slug":"keycloak","name":"Keycloak","icon":"keycloak"}]',
                200,
              );
            }
            fail('Unexpected request to ${request.url}');
          }),
        ),
        appLinksService: const EmptyAppLinksService(),
      );
      controller.serverUrlController.text = 'https://example.test';

      final autoRedirectProvider = await controller.submitServerUrl();

      expect(autoRedirectProvider, isNull);
      expect(controller.isStep2, isTrue);
      expect(controller.availableIdPs.single.slug, 'keycloak');
      expect(controller.localLoginEnabled, isTrue);
      controller.dispose();
    });

    test('shows MFA input when local login requires MFA', () async {
      final storage = SecureStorageService();
      final controller = LoginController(
        authCoordinator: _repository(
          storage: storage,
          client: MockClient((request) async {
            expect(request.url.path, ApiConstants.tokenEndpoint);
            return http.Response(
              '{"mfa_required":true,"username":"joao","message":"MFA required"}',
              200,
            );
          }),
        ),
        appLinksService: const EmptyAppLinksService(),
      );
      controller.serverUrlController.text = 'https://example.test';
      controller.usernameController.text = 'joao';
      controller.passwordController.text = 'secret';

      await controller.submitLogin();

      expect(controller.showMfaInput, isTrue);
      expect(controller.isLoading, isFalse);
      expect(await storage.getUsername(), 'joao');
      controller.dispose();
    });

    test('handles successful SSO callback', () async {
      final storage = SecureStorageService();
      final appLinks = FakeAppLinksService();
      final controller = LoginController(
        authCoordinator: _repository(
          storage: storage,
          client: MockClient((request) async {
            expect(
              request.url.path,
              '${ApiConstants.idpSessionTokenExchangeEndpoint}/session-1/tokens',
            );
            return http.Response(
              '{"access_token":"access-1","refresh_token":"refresh-1","session_id":"session-2","expires_in":3600}',
              200,
            );
          }),
        ),
        appLinksService: appLinks,
      );
      final loginCompleted = Completer<void>();
      controller.serverUrlController.text = 'https://example.test';
      controller.startSsoCallbackListener(
        onLoginSuccess: loginCompleted.complete,
        onError: (error) => fail(error.toString()),
      );

      await controller.beginSsoLogin(const IdentityProviderFixture().provider);
      appLinks.add(
        Uri.parse('endurain://auth/sso/callback?session_id=session-1'),
      );
      await loginCompleted.future.timeout(const Duration(seconds: 1));

      expect(await storage.getAccessToken(), 'access-1');
      expect(await storage.getRefreshToken(), 'refresh-1');
      controller.dispose();
      await appLinks.close();
    });

    test('reports SSO callback errors without exchanging tokens', () async {
      final storage = SecureStorageService();
      final appLinks = FakeAppLinksService();
      final errors = <Object>[];
      final controller = LoginController(
        authCoordinator: _repository(
          storage: storage,
          client: MockClient((request) async {
            fail('No HTTP request expected for callback error.');
          }),
        ),
        appLinksService: appLinks,
      );
      controller.startSsoCallbackListener(
        onLoginSuccess: () => fail('Login should not complete.'),
        onError: errors.add,
      );

      appLinks.add(
        Uri.parse('endurain://auth/sso/callback?error=access_denied'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(errors.single, 'access_denied');
      expect(controller.isLoading, isFalse);
      expect(await storage.getAccessToken(), isNull);
      controller.dispose();
      await appLinks.close();
    });

    test('reports SSO callbacks missing a session id', () async {
      final appLinks = FakeAppLinksService();
      final errors = <Object>[];
      final controller = LoginController(
        authCoordinator: _repository(
          storage: SecureStorageService(),
          client: MockClient((request) async {
            fail('No HTTP request expected without a session id.');
          }),
        ),
        appLinksService: appLinks,
      );
      controller.startSsoCallbackListener(
        onLoginSuccess: () => fail('Login should not complete.'),
        onError: errors.add,
      );

      appLinks.add(Uri.parse('endurain://auth/sso/callback'));
      await Future<void>.delayed(Duration.zero);

      expect(
        errors.single,
        isA<AppException>().having(
          (exception) => exception.code,
          'code',
          AppErrorCode.noSessionIdReceived,
        ),
      );
      expect(controller.isLoading, isFalse);
      controller.dispose();
      await appLinks.close();
    });
  });
}

AuthCoordinator _repository({
  required SecureStorageService storage,
  required http.Client client,
}) {
  return AuthCoordinator(
    authService: AuthService(storage: storage, httpClient: client),
    ssoService: SsoService(storage: storage, httpClient: client),
    serverSettingsService: ServerSettingsService(
      storage: storage,
      httpClient: client,
    ),
  );
}

class IdentityProviderFixture {
  const IdentityProviderFixture();

  core.IdentityProvider get provider => const core.IdentityProvider(
    id: 1,
    slug: 'keycloak',
    name: 'Keycloak',
    icon: 'keycloak',
  );
}
