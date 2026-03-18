import 'dart:convert';

import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/services/api_request_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiRequestExecutor', () {
    test('baut URL korrekt aus baseUrl + endpoint', () {
      final executor = ApiRequestExecutor(http.Client());

      final uri = executor.buildUri(
        serverUrl: 'https://endurain.example.com',
        endpoint: ApiConstants.serverSettingsEndpoint,
      );

      expect(
        uri.toString(),
        equals(
          'https://endurain.example.com${ApiConstants.serverSettingsEndpoint}',
        ),
      );
    });

    test('normalisiert base URL und endpoint zuverlässig', () {
      final executor = ApiRequestExecutor(http.Client());

      final uri = executor.buildUri(
        serverUrl: 'https://endurain.example.com/',
        endpoint: 'api/v1/public/server_settings',
      );

      expect(
        uri.toString(),
        equals('https://endurain.example.com/api/v1/public/server_settings'),
      );
    });

    test('behält Query-Parameter aus endpoint bei', () {
      final executor = ApiRequestExecutor(http.Client());

      final uri = executor.buildUri(
        serverUrl: 'https://endurain.example.com',
        endpoint:
            '/api/v1/auth/login?code_challenge=abc&code_challenge_method=S256',
      );

      expect(
        uri.toString(),
        equals(
          'https://endurain.example.com/api/v1/auth/login?code_challenge=abc&code_challenge_method=S256',
        ),
      );
    });

    test('vermeidet doppelte Pfadsegmente bei überlappender baseUrl und endpoint', () {
      final executor = ApiRequestExecutor(http.Client());

      final uri = executor.buildUri(
        serverUrl: 'https://endurain.example.com/api/v1',
        endpoint: '/api/v1/activities/create/upload',
      );

      expect(
        uri.toString(),
        equals('https://endurain.example.com/api/v1/activities/create/upload'),
      );
    });

    test('wirft invalidRequest bei nicht-http(s) URL', () {
      final executor = ApiRequestExecutor(http.Client());

      expect(
        () => executor.buildUri(
          serverUrl: 'ftp://endurain.example.com',
          endpoint: ApiConstants.serverSettingsEndpoint,
        ),
        throwsA(
          isA<ApiRequestException>().having(
            (e) => e.type,
            'type',
            ApiRequestExceptionType.invalidRequest,
          ),
        ),
      );
    });

    test('setzt Standardheader X-Client-Type', () async {
      late http.BaseRequest capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 200);
      });
      final executor = ApiRequestExecutor(client);

      await executor.request(
        method: 'GET',
        serverUrl: 'https://endurain.example.com',
        endpoint: ApiConstants.serverSettingsEndpoint,
      );

      expect(
        capturedRequest.headers[ApiConstants.clientTypeHeader],
        equals(ApiConstants.clientTypeValue),
      );
    });

    test('liefert strukturierten Timeout-Fehler', () async {
      final client = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(json.encode(<String, dynamic>{}), 200);
      });
      final executor = ApiRequestExecutor(
        client,
        defaultTimeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        () => executor.request(
          method: 'GET',
          serverUrl: 'https://endurain.example.com',
          endpoint: ApiConstants.serverSettingsEndpoint,
        ),
        throwsA(
          isA<ApiRequestException>().having(
            (e) => e.type,
            'type',
            ApiRequestExceptionType.timeout,
          ),
        ),
      );
    });
  });
}
