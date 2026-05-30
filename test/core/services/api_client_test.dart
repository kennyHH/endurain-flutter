import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/multipart_upload_adapter.dart';
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

  group('ApiClient uploads', () {
    test('uses injected multipart adapter with auth headers', () async {
      final storage = SecureStorageService();
      await storage.setServerUrl('https://example.test');
      await storage.setAccessToken('access-1');
      final uploadAdapter = _FakeMultipartUploadAdapter();
      final client = ApiClient(
        storage: storage,
        authService: AuthService(storage: storage),
        uploadAdapter: uploadAdapter,
      );

      await client.uploadFile('/api/files', '/tmp/activity.fit', 'file');

      expect(uploadAdapter.url.toString(), 'https://example.test/api/files');
      expect(uploadAdapter.filePath, '/tmp/activity.fit');
      expect(uploadAdapter.fieldName, 'file');
      expect(uploadAdapter.headers['Authorization'], 'Bearer access-1');
      expect(uploadAdapter.headers['X-Client-Type'], 'mobile');
    });
  });
}

class _FakeMultipartUploadAdapter implements MultipartUploadAdapter {
  late Uri url;
  late Map<String, String> headers;
  late String filePath;
  late String fieldName;

  @override
  Future<http.StreamedResponse> uploadFile({
    required Uri url,
    required Map<String, String> headers,
    required String filePath,
    required String fieldName,
  }) async {
    this.url = url;
    this.headers = headers;
    this.filePath = filePath;
    this.fieldName = fieldName;
    return http.StreamedResponse(Stream<List<int>>.empty(), 200);
  }
}
