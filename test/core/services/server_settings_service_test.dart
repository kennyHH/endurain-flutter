import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/server_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('ServerSettingsService', () {
    test('parses settings and persists tile configuration', () async {
      final storage = SecureStorageService();
      final service = ServerSettingsService(
        storage: storage,
        httpClient: MockClient((request) async {
          expect(request.url.path, ApiConstants.serverSettingsEndpoint);
          return http.Response(
            '{"sso_enabled":true,"local_login_enabled":false,'
            '"tileserver_url":"https://tiles.test/{z}/{x}/{y}.png",'
            '"tileserver_attribution":"OpenStreetMap",'
            '"map_background_color":"#102030"}',
            200,
          );
        }),
      );

      final settings = await service.getServerSettings(
        serverUrl: 'https://example.test',
      );

      expect(settings.ssoEnabled, isTrue);
      expect(settings.localLoginEnabled, isFalse);
      expect(
        await storage.getTileServerUrl(),
        'https://tiles.test/{z}/{x}/{y}.png',
      );
      expect(await storage.getTileServerAttribution(), 'OpenStreetMap');
      expect(await storage.getMapBackgroundColor(), '#102030');
    });

    test('falls back to the stored server URL', () async {
      final storage = SecureStorageService();
      await storage.setServerUrl('https://stored.test');
      final service = ServerSettingsService(
        storage: storage,
        httpClient: MockClient((request) async {
          expect(request.url.origin, 'https://stored.test');
          return http.Response('{"sso_enabled":false}', 200);
        }),
      );

      final settings = await service.getServerSettings();

      expect(settings.ssoEnabled, isFalse);
    });

    test('throws when no server URL is configured', () async {
      final service = ServerSettingsService(
        storage: SecureStorageService(),
        httpClient: MockClient((request) async {
          fail('No request should be made without a server URL.');
        }),
      );

      await expectLater(
        service.getServerSettings(),
        throwsA(
          isA<AppException>().having(
            (exception) => exception.code,
            'code',
            AppErrorCode.serverUrlNotConfigured,
          ),
        ),
      );
    });

    test('maps non-success responses to typed failures', () async {
      final service = ServerSettingsService(
        storage: SecureStorageService(),
        httpClient: MockClient((request) async {
          return http.Response('{"detail":"unavailable"}', 503);
        }),
      );

      await expectLater(
        service.getServerSettings(serverUrl: 'https://example.test'),
        throwsA(
          isA<AppException>()
              .having(
                (exception) => exception.code,
                'code',
                AppErrorCode.fetchServerSettingsFailed,
              )
              .having(
                (exception) => exception.details,
                'details',
                'unavailable',
              ),
        ),
      );
    });

    test('wraps transport errors as typed failures', () async {
      final service = ServerSettingsService(
        storage: SecureStorageService(),
        httpClient: MockClient((request) async {
          throw http.ClientException('network down');
        }),
      );

      await expectLater(
        service.getServerSettings(serverUrl: 'https://example.test'),
        throwsA(
          isA<AppException>().having(
            (exception) => exception.code,
            'code',
            AppErrorCode.fetchServerSettingsFailed,
          ),
        ),
      );
    });
  });
}
