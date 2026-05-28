import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:endurain/core/models/identity_provider.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/utils/pkce_utils.dart';
import 'package:endurain/core/services/auth_service.dart';

/// Service for SSO/OAuth authentication
class SsoService {
  static const callbackUrl = 'endurain://auth/sso/callback';

  final SecureStorageService _storage = SecureStorageService();

  // Store PKCE temporarily during SSO flow
  Map<String, String>? _ssoPkce;

  /// Get list of enabled identity providers from server
  Future<List<IdentityProvider>> getEnabledProviders({
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

    final apiUrl = Uri.parse('$url${ApiConstants.idpListEndpoint}');

    try {
      final response = await http.get(
        apiUrl,
        headers: {ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle both array and object responses
        final List<dynamic> providers;
        if (data is List) {
          providers = data;
        } else if (data is Map && data.containsKey('providers')) {
          providers = data['providers'] as List<dynamic>;
        } else {
          throw Exception('Unexpected response format');
        }

        return providers
            .map(
              (provider) =>
                  IdentityProvider.fromJson(provider as Map<String, dynamic>),
            )
            .toList();
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to fetch providers');
      }
    } catch (e) {
      throw Exception('Failed to fetch identity providers: $e');
    }
  }

  /// Initiate OAuth flow with PKCE
  /// Returns the system browser URL to open
  Future<String> initiateOAuth(String idpSlug, {String? serverUrl}) async {
    // Use provided serverUrl or get from storage
    String? url = serverUrl;
    if (url == null || url.isEmpty) {
      url = await _storage.getServerUrl();
    }

    if (url == null || url.isEmpty) {
      throw Exception('Server URL not configured');
    }

    if (serverUrl != null && serverUrl.isNotEmpty) {
      await _storage.setServerUrl(serverUrl);
    }

    // Generate PKCE parameters
    _ssoPkce = PkceUtils.generatePkce();

    // Build OAuth URL with PKCE challenge
    final pkce = _ssoPkce!;
    final oauthUrl = Uri.parse('$url${ApiConstants.idpLoginEndpoint}/$idpSlug')
        .replace(
          queryParameters: {
            'code_challenge': pkce['challenge'],
            'code_challenge_method': 'S256',
            'redirect': callbackUrl,
          },
        );
    return oauthUrl.toString();
  }

  /// Exchange session ID for tokens using PKCE code verifier
  /// Called after the deep-link callback provides a session_id
  Future<AuthResult> exchangeSessionForTokens(String sessionId) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw Exception('Server URL not configured');
    }

    if (_ssoPkce == null || _ssoPkce!['verifier'] == null) {
      throw Exception('PKCE verifier not found. Please restart SSO login.');
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
        body: json.encode({'code_verifier': _ssoPkce!['verifier']}),
      );

      // Clear verifier after use (one-time exchange)
      _ssoPkce = null;

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
      _ssoPkce = null; // Clear verifier on error
      throw Exception('SSO token exchange error: $e');
    }
  }

  /// Clear PKCE verifier (e.g., when user cancels SSO)
  void clearPkce() {
    _ssoPkce = null;
  }
}
