import 'package:endurain/core/services/api_request_executor.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/server_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeStorage extends SecureStorageService {
  _FakeStorage({this.serverUrl});

  String? serverUrl;
  String? savedTileServerUrl;
  String? savedTileServerAttribution;
  String? savedMapBackgroundColor;

  @override
  Future<String?> getServerUrl() async => serverUrl;

  @override
  Future<void> setTileServerUrl(String url) async {
    savedTileServerUrl = url;
  }

  @override
  Future<void> setTileServerAttribution(String attribution) async {
    savedTileServerAttribution = attribution;
  }

  @override
  Future<void> setMapBackgroundColor(String color) async {
    savedMapBackgroundColor = color;
  }
}

void main() {
  group('ServerSettingsService', () {
    test('200 Response wird korrekt geparst und optionale Felder gespeichert', () async {
      final storage = _FakeStorage(serverUrl: 'https://endurain.example.com');
      final service = ServerSettingsService(
        storage: storage,
        requestExecutor: ApiRequestExecutor(
          httpClient: MockClient((request) async {
            expect(request.method, equals('GET'));
            expect(
              request.url.toString(),
              equals(
                'https://endurain.example.com/api/v1/public/server_settings',
              ),
            );
            return http.Response(
              '''
              {
                "units": "imperial",
                "currency": "usd",
                "sso_enabled": true,
                "local_login_enabled": false,
                "sso_auto_redirect": true,
                "tileserver_url": "https://tiles.example.com/{z}/{x}/{y}.png",
                "tileserver_attribution": "Map data",
                "map_background_color": "#112233"
              }
              ''',
              200,
            );
          }),
        ),
      );

      final result = await service.getServerSettings();

      expect(result.units, equals('imperial'));
      expect(result.currency, equals('usd'));
      expect(result.ssoEnabled, isTrue);
      expect(result.localLoginEnabled, isFalse);
      expect(result.ssoAutoRedirect, isTrue);
      expect(
        storage.savedTileServerUrl,
        equals('https://tiles.example.com/{z}/{x}/{y}.png'),
      );
      expect(storage.savedTileServerAttribution, equals('Map data'));
      expect(storage.savedMapBackgroundColor, equals('#112233'));
    });

    test('fehlende optionale Felder nutzen Defaults und erzeugen keine Storage-Side-Effects', () async {
      final storage = _FakeStorage(serverUrl: 'https://endurain.example.com');
      final service = ServerSettingsService(
        storage: storage,
        requestExecutor: ApiRequestExecutor(
          httpClient: MockClient(
            (_) async => http.Response('{"units":"metric"}', 200),
          ),
        ),
      );

      final result = await service.getServerSettings();

      expect(result.units, equals('metric'));
      expect(result.currency, equals('euro'));
      expect(result.numRecordsPerPage, equals(25));
      expect(result.ssoEnabled, isFalse);
      expect(result.localLoginEnabled, isTrue);
      expect(result.tileserverUrl, isNull);
      expect(storage.savedTileServerUrl, isNull);
      expect(storage.savedTileServerAttribution, isNull);
      expect(storage.savedMapBackgroundColor, isNull);
    });

    test('Nicht-200 Response fuehrt zu erwartetem Fehlerpfad', () async {
      final service = ServerSettingsService(
        storage: _FakeStorage(serverUrl: 'https://endurain.example.com'),
        requestExecutor: ApiRequestExecutor(
          httpClient: MockClient(
            (_) async => http.Response('{"detail":"Forbidden"}', 403),
          ),
        ),
      );

      expect(
        service.getServerSettings,
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to fetch server settings'),
          ),
        ),
      );
    });

    test('wirft Fehler wenn serverUrl fehlt', () async {
      final service = ServerSettingsService(
        storage: _FakeStorage(serverUrl: null),
        requestExecutor: ApiRequestExecutor(
          httpClient: MockClient((_) async => throw UnimplementedError()),
        ),
      );

      expect(
        () => service.getServerSettings(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Server URL not configured'),
          ),
        ),
      );
    });

    test('wirft Fehler wenn serverUrl leer ist', () async {
      final service = ServerSettingsService(
        storage: _FakeStorage(serverUrl: ''),
        requestExecutor: ApiRequestExecutor(
          httpClient: MockClient((_) async => throw UnimplementedError()),
        ),
      );

      expect(
        () => service.getServerSettings(serverUrl: ''),
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
