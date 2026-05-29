import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/core/services/api_response.dart';

void main() {
  group('ApiResponse', () {
    test('decodes JSON objects', () {
      final response = http.Response('{"name":"endurain"}', 200);

      final data = ApiResponse.decodeJsonObject(response);

      expect(data, {'name': 'endurain'});
    });

    test('throws typed exception for unexpected JSON shape', () {
      final response = http.Response('["endurain"]', 200);

      expect(
        () => ApiResponse.decodeJsonObject(response),
        throwsA(
          isA<AppException>().having(
            (exception) => exception.code,
            'code',
            AppErrorCode.unexpectedResponseFormat,
          ),
        ),
      );
    });

    test('extracts server error details from supported keys', () {
      final response = http.Response('{"detail":"Invalid login"}', 400);

      final error = ApiResponse.failure(response, AppErrorCode.loginFailed);

      expect(error.code, AppErrorCode.loginFailed);
      expect(error.details, 'Invalid login');
    });

    test('uses plain body as error detail when response is not JSON', () {
      final response = http.Response('Server unavailable', 503);

      final error = ApiResponse.failure(
        response,
        AppErrorCode.fetchServerSettingsFailed,
      );

      expect(error.details, 'Server unavailable');
    });
  });
}
