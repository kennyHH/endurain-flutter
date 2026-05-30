import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/api_response.dart';
import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/models/app_exception.dart';

class ApiClient {
  ApiClient({
    SecureStorageService? storage,
    AuthService? authService,
    http.Client? httpClient,
  }) : _storage = storage ?? SecureStorageService(),
       _httpClient = httpClient ?? http.Client(),
       _authService =
           authService ??
           AuthService(storage: storage ?? SecureStorageService());

  final SecureStorageService _storage;
  final AuthService _authService;
  final http.Client _httpClient;

  /// Make an authenticated GET request
  Future<http.Response> get(String endpoint) {
    return _makeRequest('GET', endpoint);
  }

  Future<Map<String, dynamic>> getJsonObject(
    String endpoint, {
    required AppErrorCode failureCode,
  }) {
    return _makeJsonObjectRequest('GET', endpoint, failureCode: failureCode);
  }

  /// Make an authenticated POST request
  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) {
    return _makeRequest('POST', endpoint, body: body);
  }

  Future<Map<String, dynamic>> postJsonObject(
    String endpoint, {
    Map<String, dynamic>? body,
    required AppErrorCode failureCode,
  }) {
    return _makeJsonObjectRequest(
      'POST',
      endpoint,
      body: body,
      failureCode: failureCode,
    );
  }

  /// Make an authenticated PUT request
  Future<http.Response> put(String endpoint, {Map<String, dynamic>? body}) {
    return _makeRequest('PUT', endpoint, body: body);
  }

  Future<Map<String, dynamic>> putJsonObject(
    String endpoint, {
    Map<String, dynamic>? body,
    required AppErrorCode failureCode,
  }) {
    return _makeJsonObjectRequest(
      'PUT',
      endpoint,
      body: body,
      failureCode: failureCode,
    );
  }

  /// Make an authenticated DELETE request
  Future<http.Response> delete(String endpoint) {
    return _makeRequest('DELETE', endpoint);
  }

  Future<Map<String, dynamic>> deleteJsonObject(
    String endpoint, {
    required AppErrorCode failureCode,
  }) {
    return _makeJsonObjectRequest('DELETE', endpoint, failureCode: failureCode);
  }

  Future<Map<String, dynamic>> _makeJsonObjectRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    required AppErrorCode failureCode,
  }) async {
    final response = await _makeRequest(method, endpoint, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiResponse.failure(response, failureCode);
    }
    return ApiResponse.decodeJsonObject(response);
  }

  /// Upload a file with multipart/form-data
  Future<http.StreamedResponse> uploadFile(
    String endpoint,
    String filePath,
    String fieldName,
  ) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw const AppException(AppErrorCode.serverUrlNotConfigured);
    }

    final accessToken = await _getValidAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const AppException(AppErrorCode.notAuthenticated);
    }

    final url = Uri.parse('$serverUrl$endpoint');
    final request = http.MultipartRequest('POST', url);

    request.headers[ApiConstants.authorizationHeader] = 'Bearer $accessToken';
    request.headers[ApiConstants.clientTypeHeader] =
        ApiConstants.clientTypeValue;

    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));

    return request.send();
  }

  /// Execute an HTTP request with the given method, URL, headers, and optional body
  Future<http.Response> _executeRequest(
    String method,
    Uri url,
    Map<String, String> headers, {
    Map<String, dynamic>? body,
  }) async {
    switch (method) {
      case 'GET':
        return _httpClient.get(url, headers: headers);
      case 'POST':
        return _httpClient.post(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
      case 'PUT':
        return _httpClient.put(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
      case 'DELETE':
        return _httpClient.delete(url, headers: headers);
      default:
        throw AppException(AppErrorCode.unsupportedHttpMethod, details: method);
    }
  }

  /// Make an HTTP request with automatic token refresh
  Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw const AppException(AppErrorCode.serverUrlNotConfigured);
    }

    final accessToken = await _getValidAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const AppException(AppErrorCode.notAuthenticated);
    }

    final url = Uri.parse('$serverUrl$endpoint');
    final headers = {
      ApiConstants.authorizationHeader: 'Bearer $accessToken',
      ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
      ApiConstants.contentTypeHeader: ApiConstants.contentTypeJson,
    };

    http.Response response = await _executeRequest(
      method,
      url,
      headers,
      body: body,
    );

    // If token expired (401), try to refresh and retry once
    if (response.statusCode == 401) {
      final refreshed = await _authService.refreshToken();
      if (refreshed) {
        // Retry the request with new token
        final newAccessToken = await _storage.getAccessToken();
        headers[ApiConstants.authorizationHeader] = 'Bearer $newAccessToken';
        response = await _executeRequest(method, url, headers, body: body);
      } else {
        throw const AppException(AppErrorCode.sessionExpired);
      }
    }

    return response;
  }

  Future<String?> _getValidAccessToken() async {
    final accessToken = await _storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return accessToken;
    }

    if (await _storage.isAccessTokenExpiringSoon()) {
      await _authService.refreshToken();
      return _storage.getAccessToken();
    }

    return accessToken;
  }
}
