import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('ApiClient JSON helpers', () {
    test(
      'returns decoded object for successful authenticated requests',
      () async {
        final storage = SecureStorageService();
        await storage.setServerUrl('https://example.test');
        await storage.setAccessToken('access-1');

        final client = ApiClient(
          storage: storage,
          authService: AuthService(storage: storage),
          httpClient: MockClient((request) async {
            expect(request.url.toString(), 'https://example.test/api/profile');
            expect(request.headers['Authorization'], 'Bearer access-1');
            return http.Response('{"name":"Endurain"}', 200);
          }),
        );

        final data = await client.getJsonObject(
          '/api/profile',
          failureCode: AppErrorCode.loginFailed,
        );

        expect(data, {'name': 'Endurain'});
      },
    );

    test('maps non-success responses to typed failures', () async {
      final storage = SecureStorageService();
      await storage.setServerUrl('https://example.test');
      await storage.setAccessToken('access-1');

      final client = ApiClient(
        storage: storage,
        authService: AuthService(storage: storage),
        httpClient: MockClient((request) async {
          return http.Response('{"detail":"Profile unavailable"}', 503);
        }),
      );

      expect(
        () => client.getJsonObject(
          '/api/profile',
          failureCode: AppErrorCode.fetchServerSettingsFailed,
        ),
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
                'Profile unavailable',
              ),
        ),
      );
    });
  });
}
