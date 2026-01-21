import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/constants/api_constants.dart';

class AuthService {
  final SecureStorageService _storage = SecureStorageService();

  /// Login with username and password
  /// Returns AuthResult with MFA status or tokens
  Future<AuthResult> login(
    String username,
    String password, {
    String? serverUrl,
  }) async {
    // Use provided serverUrl or get from storage
    String? url = serverUrl;
    if (url == null || url.isEmpty) {
      url = await _storage.getServerUrl();
    }

    if (url == null || url.isEmpty) {
      throw Exception('Server URL not configured');
    }

    // Save server URL if provided
    if (serverUrl != null && serverUrl.isNotEmpty) {
      await _storage.setServerUrl(serverUrl);
    }

    final apiUrl = Uri.parse('$url${ApiConstants.tokenEndpoint}');

    try {
      final response = await http.post(
        apiUrl,
        headers: {
          ApiConstants.contentTypeHeader:
              ApiConstants.contentTypeFormUrlEncoded,
          ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
        },
        body: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check if MFA is required
        if (data['mfa_required'] == true) {
          return AuthResult(
            success: true,
            mfaRequired: true,
            username: data['username'] as String?,
            message: data['message'] as String?,
          );
        }

        // Direct login success (no MFA)
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final sessionId = data['session_id'] as String?;

        if (accessToken != null) {
          await _storage.setAccessToken(accessToken);
        }
        if (refreshToken != null) {
          await _storage.setRefreshToken(refreshToken);
        }
        await _storage.setUsername(username);
        if (sessionId != null) {
          await _storage.setSessionId(sessionId);
        }

        return AuthResult(
          success: true,
          mfaRequired: false,
          accessToken: accessToken,
          refreshToken: refreshToken,
          sessionId: sessionId,
        );
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  /// Verify MFA code after initial login
  Future<AuthResult> verifyMfa(String username, String mfaCode) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw Exception('Server URL not configured');
    }

    final url = Uri.parse('$serverUrl${ApiConstants.mfaVerifyEndpoint}');

    try {
      final response = await http.post(
        url,
        headers: {
          ApiConstants.contentTypeHeader: ApiConstants.contentTypeJson,
          ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
        },
        body: json.encode({'username': username, 'mfa_code': mfaCode}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Store tokens
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final sessionId = data['session_id'] as String?;

        if (accessToken != null) {
          await _storage.setAccessToken(accessToken);
        }
        if (refreshToken != null) {
          await _storage.setRefreshToken(refreshToken);
        }
        await _storage.setUsername(username);
        if (sessionId != null) {
          await _storage.setSessionId(sessionId);
        }

        return AuthResult(
          success: true,
          mfaRequired: false,
          accessToken: accessToken,
          refreshToken: refreshToken,
          sessionId: sessionId,
        );
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'MFA verification failed');
      }
    } catch (e) {
      throw Exception('MFA verification error: $e');
    }
  }

  /// Refresh access token using refresh token
  Future<bool> refreshToken() async {
    final serverUrl = await _storage.getServerUrl();
    final refreshToken = await _storage.getRefreshToken();

    if (serverUrl == null || serverUrl.isEmpty || refreshToken == null) {
      return false;
    }

    final url = Uri.parse('$serverUrl${ApiConstants.refreshEndpoint}');

    try {
      final response = await http.post(
        url,
        headers: {
          ApiConstants.contentTypeHeader: ApiConstants.contentTypeJson,
          ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
        },
        body: json.encode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newAccessToken != null) {
          await _storage.setAccessToken(newAccessToken);
        }
        if (newRefreshToken != null) {
          await _storage.setRefreshToken(newRefreshToken);
        }
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Logout and clear all tokens
  /// Returns true if server logout succeeded, false if it failed
  /// Local tokens are always cleared regardless of server response
  Future<bool> logout() async {
    final serverUrl = await _storage.getServerUrl();
    final refreshToken = await _storage.getRefreshToken();

    bool serverLogoutSuccess = true;

    // Call server-side logout if we have credentials
    if (serverUrl != null && refreshToken != null && refreshToken.isNotEmpty) {
      try {
        final url = Uri.parse('$serverUrl${ApiConstants.logoutEndpoint}');
        final headers = {
          ApiConstants.authorizationHeader: 'Bearer $refreshToken',
          ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
        };
        final response = await http.post(url, headers: headers);

        serverLogoutSuccess = response.statusCode == 200;
      } catch (e) {
        // Server logout failed (network error, server down, token expired)
        serverLogoutSuccess = false;
      }
    }

    // Always clear local tokens
    await _storage.clearAuthTokens();

    return serverLogoutSuccess;
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() {
    return _storage.isAuthenticated();
  }
}

/// Authentication result model
class AuthResult {
  final bool success;
  final bool mfaRequired;
  final String? username;
  final String? message;
  final String? accessToken;
  final String? refreshToken;
  final String? sessionId;

  AuthResult({
    required this.success,
    this.mfaRequired = false,
    this.username,
    this.message,
    this.accessToken,
    this.refreshToken,
    this.sessionId,
  });
}
