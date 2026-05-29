import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:endurain/core/models/app_exception.dart';

class ApiResponse {
  const ApiResponse._();

  static Object? decodeJson(http.Response response) {
    try {
      return json.decode(response.body);
    } catch (error) {
      throw AppException(AppErrorCode.unexpectedResponseFormat, cause: error);
    }
  }

  static Map<String, dynamic> decodeJsonObject(http.Response response) {
    final data = decodeJson(response);
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const AppException(AppErrorCode.unexpectedResponseFormat);
  }

  static AppException failure(http.Response response, AppErrorCode code) {
    return AppException(code, details: errorDetail(response));
  }

  static String? errorDetail(http.Response response) {
    if (response.body.trim().isEmpty) {
      return null;
    }

    try {
      final data = json.decode(response.body);
      if (data is Map) {
        return data['detail']?.toString() ??
            data['message']?.toString() ??
            data['error']?.toString();
      }
    } catch (_) {
      return response.body;
    }

    return response.body;
  }
}
