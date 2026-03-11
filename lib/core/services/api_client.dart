import 'package:http/http.dart' as http;
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/api_request_executor.dart';
import 'package:endurain/core/constants/api_constants.dart';

class ApiClient {
  ApiClient({
    SecureStorageService? storage,
    AuthService? authService,
    ApiRequestExecutor? requestExecutor,
  }) : _storage = storage ?? SecureStorageService(),
       _authService = authService ?? AuthService(),
       _requestExecutor = requestExecutor ?? ApiRequestExecutor();

  final SecureStorageService _storage;
  final AuthService _authService;
  final ApiRequestExecutor _requestExecutor;

  /// Make an authenticated GET request
  Future<http.Response> get(String endpoint) {
    return _makeRequest('GET', endpoint);
  }

  /// Make an authenticated POST request
  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) {
    return _makeRequest('POST', endpoint, body: body);
  }

  /// Make an authenticated PUT request
  Future<http.Response> put(String endpoint, {Map<String, dynamic>? body}) {
    return _makeRequest('PUT', endpoint, body: body);
  }

  /// Make an authenticated DELETE request
  Future<http.Response> delete(String endpoint) {
    return _makeRequest('DELETE', endpoint);
  }

  /// Upload a file with multipart/form-data
  Future<http.StreamedResponse> uploadFile(
    String endpoint,
    String filePath,
    String fieldName,
  ) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw Exception('Server URL not configured');
    }

    final accessToken = await _storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Not authenticated');
    }

    final url = Uri.parse('$serverUrl$endpoint');
    final request = http.MultipartRequest('POST', url);

    request.headers[ApiConstants.authorizationHeader] = 'Bearer $accessToken';
    request.headers[ApiConstants.clientTypeHeader] =
        ApiConstants.clientTypeValue;

    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));

    return request.send();
  }

  /// Make an HTTP request with automatic token refresh
  Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw Exception('Server URL not configured');
    }

    final accessToken = await _storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Not authenticated');
    }

    final headers = {
      ApiConstants.authorizationHeader: 'Bearer $accessToken',
      ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
      ApiConstants.contentTypeHeader: ApiConstants.contentTypeJson,
    };

    http.Response response = await _requestExecutor.request(
      method: method,
      serverUrl: serverUrl,
      endpoint: endpoint,
      headers: headers,
      body: body,
      encodeBodyAsJson: true,
    );

    // If token expired (401), try to refresh and retry once
    if (response.statusCode == 401) {
      final refreshed = await _authService.refreshToken();
      if (refreshed) {
        // Retry the request with new token
        final newAccessToken = await _storage.getAccessToken();
        headers[ApiConstants.authorizationHeader] = 'Bearer $newAccessToken';
        response = await _requestExecutor.request(
          method: method,
          serverUrl: serverUrl,
          endpoint: endpoint,
          headers: headers,
          body: body,
          encodeBodyAsJson: true,
        );
      } else {
        throw Exception('Session expired. Please login again.');
      }
    }

    return response;
  }
}
