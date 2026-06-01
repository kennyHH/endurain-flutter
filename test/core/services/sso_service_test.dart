import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/sso_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('SsoService', () {
    test('rejects successful token exchange with missing token fields', () async {
      final storage = SecureStorageService();
      final service = SsoService(
        storage: storage,
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '${ApiConstants.idpSessionTokenExchangeEndpoint}/session-1/tokens',
          );
          return http.Response(
            '{"access_token":"access-1","session_id":"session-2","expires_in":3600}',
            200,
          );
        }),
      );

      await service.initiateOAuth('oidc', serverUrl: 'https://example.test');

      await expectLater(
        service.exchangeSessionForTokens('session-1'),
        throwsA(
          isA<AppException>().having(
            (exception) => exception.code,
            'code',
            AppErrorCode.unexpectedResponseFormat,
          ),
        ),
      );
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
      expect(await storage.getSessionId(), isNull);
    });
  });
}
