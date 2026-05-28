import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/utils/pkce_utils.dart';

class AuthService {
  final SecureStorageService _storage = SecureStorageService();

  // Store PKCE temporarily during auth flow
  Map<String, String>? _pkce;

  /// Login with username and password using PKCE flow
  /// Returns AuthResult with MFA status or session ID for token exchange
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

    // Generate PKCE parameters
    _pkce = PkceUtils.generatePkce();

    final apiUrl = Uri.parse(
      '$url${ApiConstants.tokenEndpoint}?code_challenge=${_pkce!['challenge']}&code_challenge_method=S256',
    );

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
          // Store username for MFA verification
          await _storage.setUsername(username);

          return AuthResult(
            success: true,
            mfaRequired: true,
            username: data['username'] as String?,
            message: data['message'] as String?,
          );
        }

        // PKCE flow returns session_id for token exchange
        final sessionId = data['session_id'] as String?;

        if (sessionId != null) {
          // Exchange session for tokens
          return await _exchangeSessionForTokens(url, sessionId, username);
        }

        throw Exception('No session ID received from server');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      _pkce = null; // Clear verifier on error
      throw Exception('Login error: $e');
    }
  }

  /// Verify MFA code after initial login using PKCE flow
  Future<AuthResult> verifyMfa(String username, String mfaCode) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw Exception('Server URL not configured');
    }

    if (_pkce == null || _pkce!['verifier'] == null) {
      throw Exception('PKCE verifier not found. Please login again.');
    }

    // MFA verification with PKCE uses query parameters
    final url = Uri.parse(
      '$serverUrl${ApiConstants.mfaVerifyEndpoint}?code_challenge=${_pkce!['challenge']}&code_challenge_method=S256',
    );

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

        // PKCE flow returns session_id for token exchange
        final sessionId = data['session_id'] as String?;

        if (sessionId != null) {
          // Exchange session for tokens
          return await _exchangeSessionForTokens(
            serverUrl,
            sessionId,
            username,
          );
        }

        throw Exception('No session ID received from server');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'MFA verification failed');
      }
    } catch (e) {
      _pkce = null; // Clear verifier on error
      throw Exception('MFA verification error: $e');
    }
  }

  /// Exchange session ID for tokens using PKCE code verifier
  Future<AuthResult> _exchangeSessionForTokens(
    String serverUrl,
    String sessionId,
    String username,
  ) async {
    if (_pkce == null || _pkce!['verifier'] == null) {
      throw Exception('PKCE verifier not found');
    }

    final url = Uri.parse(
      '$serverUrl${ApiConstants.idpSessionTokenExchangeEndpoint}/$sessionId/tokens',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          ApiConstants.contentTypeHeader: ApiConstants.contentTypeJson,
          ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
        },
        body: json.encode({'code_verifier': _pkce!['verifier']}),
      );

      // Clear verifier after use (one-time exchange)
      _pkce = null;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Store tokens
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final returnedSessionId = data['session_id'] as String?;
        final expiresIn = data['expires_in'] as int?;

        if (accessToken != null) {
          await _storage.setAccessToken(accessToken);
        }
        if (refreshToken != null) {
          await _storage.setRefreshToken(refreshToken);
        }
        if (expiresIn != null) {
          await _storage.setAccessTokenExpiresAt(
            DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
          );
        }
        await _storage.setUsername(username);
        if (returnedSessionId != null) {
          await _storage.setSessionId(returnedSessionId);
        }

        return AuthResult(
          success: true,
          mfaRequired: false,
          accessToken: accessToken,
          refreshToken: refreshToken,
          sessionId: returnedSessionId,
        );
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Token exchange failed');
      }
    } catch (e) {
      throw Exception('Token exchange error: $e');
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
          ApiConstants.authorizationHeader: 'Bearer $refreshToken',
          ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;
        final returnedSessionId = data['session_id'] as String?;
        final expiresIn = data['expires_in'] as int?;

        if (newAccessToken != null) {
          await _storage.setAccessToken(newAccessToken);
        }
        if (newRefreshToken != null) {
          await _storage.setRefreshToken(newRefreshToken);
        }
        if (returnedSessionId != null) {
          await _storage.setSessionId(returnedSessionId);
        }
        if (expiresIn != null) {
          await _storage.setAccessTokenExpiresAt(
            DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
          );
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
  Future<bool> isAuthenticated() async {
    final accessToken = await _storage.getAccessToken();
    final storedRefreshToken = await _storage.getRefreshToken();

    if (accessToken != null &&
        accessToken.isNotEmpty &&
        !await _storage.isAccessTokenExpiringSoon()) {
      return true;
    }

    if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
      await _storage.clearAuthTokens();
      return false;
    }

    final refreshed = await refreshToken();
    if (refreshed) {
      return true;
    }

    await _storage.clearAuthTokens();
    return false;
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
