import 'package:endurain/core/utils/sso_navigation_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SsoNavigationSecurity', () {
    final allowedHosts = SsoNavigationSecurity.allowedHostsForOauthUrl(
      'https://endurain.example.com/api/auth/idp/login/keycloak',
    );

    test('erlaubter Host mit success callback liefert session_id', () {
      final result = SsoNavigationSecurity.evaluateCallback(
        url:
            'https://endurain.example.com/login?sso=success&session_id=abc-123',
        allowedHosts: allowedHosts,
      );

      expect(result.type, equals(SsoCallbackType.success));
      expect(result.sessionId, equals('abc-123'));
    });

    test('fremder Host wird als blockiert erkannt', () {
      final shouldBlock = SsoNavigationSecurity.shouldBlockNavigation(
        url: 'https://evil.example.org/login?sso=success&session_id=abc-123',
        allowedHosts: allowedHosts,
      );

      expect(shouldBlock, isTrue);
    });

    test('manipulierter success callback ohne session_id ist kein Erfolg', () {
      final result = SsoNavigationSecurity.evaluateCallback(
        url: 'https://endurain.example.com/login?sso=success',
        allowedHosts: allowedHosts,
      );

      expect(result.type, equals(SsoCallbackType.none));
      expect(result.sessionId, isNull);
    });

    test('sso error callback auf erlaubtem Host liefert error event', () {
      final result = SsoNavigationSecurity.evaluateCallback(
        url: 'https://endurain.example.com/login?sso=error&message=bad',
        allowedHosts: allowedHosts,
      );

      expect(result.type, equals(SsoCallbackType.error));
    });
  });
}
