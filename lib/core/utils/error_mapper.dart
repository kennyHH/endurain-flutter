import 'package:endurain/l10n/app_localizations.dart';

class AppErrorMapper {
  static String toUserMessage(Object error, AppLocalizations l10n) {
    final raw = error.toString().toLowerCase();

    // --- NEW: Authentication Error Mapping ---
    // Handle specific auth failure messages to be user-friendly
    if (_containsAny(raw, <String>[
      'token is expired',
      'token expired',
      'token invalid',
      'invalid token',
      'authentication failed',
      'http 401',
    ])) {
      return 'Session expired. Please log in again to continue.';
    }
    // -----------------------------------------

    if (_containsAny(raw, <String>[
      'apirequestexception(apirequestexceptiontype.tls)',
      'tls handshake',
      'cert_verify_failed',
      'certificate verify failed',
      'bad certificate',
      'hostname',
      'handshakeexception',
    ])) {
      // Return a user-friendly message directly if localization is missing or generic
      return 'Secure connection failed. Please check the server URL and ensure it supports HTTPS with a valid certificate.';
    }

    if (_containsAny(raw, <String>[
      'socketexception',
      'failed host lookup',
      'timed out',
      'timeout',
      'connection refused',
      'network',
      'os error: no address associated with hostname',
      'clientexception', // Added to catch "cause: ClientException with SocketException"
    ])) {
      return 'Connection failed. Please check the server URL in the settings and your internet connection.';
    }

    if (_containsAny(raw, <String>[
      'login failed',
      'unauthorized',
      '401',
      'invalid credentials',
      'mfa verification failed',
      'forbidden',
      '403',
    ])) {
      return l10n.errorAuthentication;
    }

    if (_containsAny(raw, <String>[
      'server url not configured',
      'not configured',
      'invalid url',
    ])) {
      return l10n.errorConfiguration;
    }

    if (_containsAny(raw, <String>[
      'sso',
      'pkce',
      'token exchange',
      'session id',
      'identity providers',
    ])) {
      return l10n.errorSso;
    }

    if (_containsAny(raw, <String>[
      '500',
      'internal server error',
      'failed to fetch server settings',
      'server error',
    ])) {
      return l10n.errorServer;
    }

    return l10n.errorGeneric;
  }

  static bool _containsAny(String value, List<String> patterns) {
    for (final pattern in patterns) {
      if (value.contains(pattern)) {
        return true;
      }
    }
    return false;
  }
}
