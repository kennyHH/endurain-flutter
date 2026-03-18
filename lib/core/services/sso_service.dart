import 'dart:convert';
import 'package:endurain/core/models/identity_provider.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/services/api_request_executor.dart';
import 'package:endurain/core/utils/pkce_utils.dart';
import 'package:endurain/core/models/auth_result.dart';
import 'package:injectable/injectable.dart';

@singleton
class SsoService {
  SsoService({
    required SecureStorageService storage,
    required ApiRequestExecutor requestExecutor,
  }) : _storage = storage,
       _requestExecutor = requestExecutor;

  final SecureStorageService _storage;
  final ApiRequestExecutor _requestExecutor;

  // Store PKCE temporarily during SSO flow
  Map<String, String>? _ssoPicke;

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

    try {
      final response = await _requestExecutor.request(
        method: 'GET',
        serverUrl: url,
        endpoint: ApiConstants.idpListEndpoint,
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
    } on ApiRequestException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to fetch identity providers: $e');
    }
  }

  /// Initiate OAuth flow with PKCE
  /// Returns the WebView URL to load
  Future<String> initiateOAuth(String idpSlug, {String? serverUrl}) async {
    // Use provided serverUrl or get from storage
    String? url = serverUrl;
    if (url == null || url.isEmpty) {
      url = await _storage.getServerUrl();
    }

    if (url == null || url.isEmpty) {
      throw Exception('Server URL not configured');
    }

    // Generate PKCE parameters
    final pkce = PkceUtils.generatePkce();
    _ssoPicke = pkce;
    final codeChallenge = pkce['challenge'];
    if (codeChallenge == null) {
      throw Exception('Failed to generate PKCE challenge');
    }

    // Build OAuth URL with PKCE challenge
    final oauthUrl = Uri.parse('$url${ApiConstants.idpLoginEndpoint}/$idpSlug')
        .replace(
          queryParameters: {
            'code_challenge': codeChallenge,
            'code_challenge_method': 'S256',
            'redirect': '/dashboard', // Frontend path after successful login
          },
        );

    return oauthUrl.toString();
  }

  /// Exchange session ID for tokens using PKCE code verifier
  /// Called after WebView detects successful OAuth callback with session_id
  Future<AuthResult> exchangeSessionForTokens(String sessionId) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw Exception('Server URL not configured');
    }

    if (_ssoPicke == null || _ssoPicke!['verifier'] == null) {
      throw Exception('PKCE verifier not found. Please restart SSO login.');
    }

    try {
      final response = await _requestExecutor.request(
        method: 'POST',
        serverUrl: serverUrl,
        endpoint:
            '${ApiConstants.idpSessionTokenExchangeEndpoint}/$sessionId/tokens',
        headers: {
          ApiConstants.contentTypeHeader: ApiConstants.contentTypeJson,
          ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
        },
        body: {'code_verifier': _ssoPicke!['verifier']},
        encodeBodyAsJson: true,
      );

      // Clear verifier after use (one-time exchange)
      _ssoPicke = null;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Store tokens
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final returnedSessionId = data['session_id'] as String?;

        if (accessToken != null) {
          await _storage.setAccessToken(accessToken);
        }
        if (refreshToken != null) {
          await _storage.setRefreshToken(refreshToken);
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
    } on ApiRequestException {
      _ssoPicke = null; // Clear verifier on error
      rethrow;
    } catch (e) {
      _ssoPicke = null; // Clear verifier on error
      throw Exception('SSO token exchange error: $e');
    }
  }

  /// Clear PKCE verifier (e.g., when user cancels SSO)
  void clearPkce() {
    _ssoPicke = null;
  }
}
