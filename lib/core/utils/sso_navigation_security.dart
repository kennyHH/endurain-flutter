enum SsoCallbackType { none, success, error, blockedHost }

class SsoCallbackEvaluation {
  const SsoCallbackEvaluation({required this.type, this.sessionId});

  final SsoCallbackType type;
  final String? sessionId;
}

class SsoNavigationSecurity {
  static const String callbackPath = '/login';
  static const String callbackQueryKey = 'sso';
  static const String successValue = 'success';
  static const String errorValue = 'error';
  static const String sessionIdKey = 'session_id';

  static Set<String> allowedHostsForOauthUrl(String oauthUrl) {
    final uri = Uri.tryParse(oauthUrl);
    if (uri == null || uri.host.isEmpty) {
      return <String>{};
    }
    return <String>{uri.host.toLowerCase()};
  }

  static bool shouldBlockNavigation({
    required String url,
    required Set<String> allowedHosts,
  }) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return true;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'about' || scheme == 'data') {
      return false;
    }

    if (scheme != 'http' && scheme != 'https') {
      return true;
    }

    return !_isAllowedHost(uri, allowedHosts);
  }

  static SsoCallbackEvaluation evaluateCallback({
    required String url,
    required Set<String> allowedHosts,
  }) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return const SsoCallbackEvaluation(type: SsoCallbackType.none);
    }

    if (!_isAllowedHost(uri, allowedHosts)) {
      return const SsoCallbackEvaluation(type: SsoCallbackType.blockedHost);
    }

    if (!_isExpectedCallbackPath(uri.path)) {
      return const SsoCallbackEvaluation(type: SsoCallbackType.none);
    }

    final callbackValue = uri.queryParameters[callbackQueryKey];
    if (callbackValue == successValue) {
      final sessionId = uri.queryParameters[sessionIdKey];
      if (sessionId != null && sessionId.isNotEmpty) {
        return SsoCallbackEvaluation(
          type: SsoCallbackType.success,
          sessionId: sessionId,
        );
      }
      return const SsoCallbackEvaluation(type: SsoCallbackType.none);
    }

    if (callbackValue == errorValue) {
      return const SsoCallbackEvaluation(type: SsoCallbackType.error);
    }

    return const SsoCallbackEvaluation(type: SsoCallbackType.none);
  }

  static bool _isAllowedHost(Uri uri, Set<String> allowedHosts) {
    if (uri.host.isEmpty || allowedHosts.isEmpty) {
      return false;
    }
    return allowedHosts.contains(uri.host.toLowerCase());
  }

  static bool _isExpectedCallbackPath(String path) {
    final normalized = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    return normalized == callbackPath;
  }
}
