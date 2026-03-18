import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/api_request_executor.dart';
import 'package:endurain/core/error_handling/app_error.dart';
import 'package:endurain/core/constants/api_constants.dart';
import 'package:injectable/injectable.dart';

class UploadableFile {
  UploadableFile.fromPath({
    required this.field,
    required this.filePath,
    this.filename,
  }) : content = null,
       bytes = null;

  UploadableFile.fromString({
    required this.field,
    required this.content,
    this.filename,
  }) : filePath = null,
       bytes = null;

  UploadableFile.fromBytes({
    required this.field,
    required this.bytes,
    this.filename,
  }) : filePath = null,
       content = null;

  final String field;
  final String? filePath;
  final String? content;
  final List<int>? bytes;
  final String? filename;

  Future<http.MultipartFile> toMultipartFile() async {
    if (filePath != null) {
      return http.MultipartFile.fromPath(field, filePath!, filename: filename);
    }
    if (content != null) {
      return http.MultipartFile.fromBytes(
        field,
        utf8.encode(content!),
        filename: filename,
      );
    }
    if (bytes != null) {
      return http.MultipartFile.fromBytes(field, bytes!, filename: filename);
    }
    throw StateError('UploadableFile has no data source');
  }
}

@singleton
class ApiClient {
  ApiClient({
    required SecureStorageService storage,
    required AuthService authService,
    required ApiRequestExecutor requestExecutor,
  }) : _storage = storage,
       _authService = authService,
       _requestExecutor = requestExecutor;

  final SecureStorageService _storage;
  final AuthService _authService;
  final ApiRequestExecutor _requestExecutor;

  /// Make an authenticated request with automatic token refresh and retry logic
  Future<http.Response> request({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return _withAuthentication((token) async {
      final serverUrl = await _storage.getServerUrl();
      if (serverUrl == null || serverUrl.isEmpty) {
        throw Exception('Server URL not configured');
      }

      final mergedHeaders = {
        ApiConstants.authorizationHeader: 'Bearer $token',
        ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
        ApiConstants.contentTypeHeader: ApiConstants.contentTypeJson,
        ...?headers,
      };

      return _requestExecutor.request(
        method: method,
        serverUrl: serverUrl,
        endpoint: endpoint,
        headers: mergedHeaders,
        body: body,
        encodeBodyAsJson: true,
      );
    });
  }

  /// Upload a file with multipart/form-data with automatic token refresh
  Future<http.Response> requestMultipart({
    required String method,
    required String endpoint,
    required List<UploadableFile> files,
    Map<String, String>? fields,
    Map<String, String>? headers,
  }) async {
    return _withAuthentication((token) async {
      final serverUrl = await _storage.getServerUrl();
      if (serverUrl == null || serverUrl.isEmpty) {
        throw Exception('Server URL not configured');
      }

      final mergedHeaders = {
        ApiConstants.authorizationHeader: 'Bearer $token',
        ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
        ...?headers,
      };

      // Create MultipartFiles fresh for each attempt
      final multipartFiles = await Future.wait(
        files.map((f) => f.toMultipartFile()),
      );

      return _requestExecutor.requestMultipart(
        method: method,
        serverUrl: serverUrl,
        endpoint: endpoint,
        headers: mergedHeaders,
        fields: fields,
        files: multipartFiles,
      );
    });
  }

  /// Wrapper to handle authentication flow:
  /// 1. Get Token
  /// 2. Execute Request
  /// 3. If 401, Refresh Token and Retry
  Future<http.Response> _withAuthentication(
    Future<http.Response> Function(String token) requestBuilder,
  ) async {
    try {
      // 1. Get initial token
      String? accessToken = await _storage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        final refreshSuccess = await _authService.refreshToken();
        if (!refreshSuccess) {
          throw AuthenticationError(message: 'Session expired. Please login again.');
        }
        accessToken = await _storage.getAccessToken();
        if (accessToken == null || accessToken.isEmpty) {
          throw AuthenticationError(message: 'Session expired. Please login again.');
        }
      }

      // 2. Execute request
      http.Response response = await requestBuilder(accessToken);

      // 3. Check for 401 Unauthorized
      if (response.statusCode == 401) {
        // 4. Attempt Refresh
        final refreshSuccess = await _authService.refreshToken();
        if (refreshSuccess) {
          // 5. Get new token
          accessToken = await _storage.getAccessToken();
          if (accessToken != null && accessToken.isNotEmpty) {
            // 6. Retry Request
            response = await requestBuilder(accessToken);
          }
        } else {
          await _storage.clearAuthTokens();
          throw AuthenticationError(
            message: 'Session expired. Please login again.',
          );
        }
      }

      return response;
    } catch (e) {
      if (e is AppError) rethrow;
      throw NetworkError(message: 'Network request failed', originalError: e);
    }
  }

  /// Make an authenticated GET request
  Future<http.Response> get(String endpoint, {Map<String, String>? headers}) {
    return request(method: 'GET', endpoint: endpoint, headers: headers);
  }

  /// Make an authenticated POST request
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    return request(
      method: 'POST',
      endpoint: endpoint,
      body: body,
      headers: headers,
    );
  }

  /// Make an authenticated PUT request
  Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    return request(
      method: 'PUT',
      endpoint: endpoint,
      body: body,
      headers: headers,
    );
  }

  /// Make an authenticated DELETE request
  Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) {
    return request(method: 'DELETE', endpoint: endpoint, headers: headers);
  }

  /// Upload a file with multipart/form-data (Legacy wrapper)
  Future<http.StreamedResponse> uploadFile(
    String endpoint,
    String filePath,
    String fieldName,
  ) async {
    // This is a legacy method returning StreamedResponse.
    // We should migrate to requestMultipart returning Response.
    // For now, we wrap the new logic but we must convert Response back to StreamedResponse?
    // Or better, update callers.
    // ActivityUploadService uses requestMultipart now.
    // Let's keep this for backward compatibility but use the new flow if possible.
    // But StreamedResponse is different.
    // Let's deprecate this or reimplement using raw http if needed,
    // but better to encourage requestMultipart.

    // For the sake of "Refactor ApiClient", let's make this use the safe flow
    // by reading the file and using requestMultipart.
    final uploadable = UploadableFile.fromPath(
      field: fieldName,
      filePath: filePath,
    );
    final response = await requestMultipart(
      method: 'POST',
      endpoint: endpoint,
      files: [uploadable],
    );

    // Convert Response back to StreamedResponse to satisfy signature
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
