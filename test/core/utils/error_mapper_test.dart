import 'package:endurain/core/utils/error_mapper.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('AppErrorMapper.toUserMessage', () {
    test('mappt Netzwerkfehler auf lokalisierte Netzwerkmeldung', () {
      final message = AppErrorMapper.toUserMessage(
        Exception('SocketException: Failed host lookup'),
        l10n,
      );

      expect(
        message,
        'Connection failed. Please check the server URL in the settings and your internet connection.',
      );
    });

    test('mappt TLS-Fehler auf lokalisierte TLS-Meldung', () {
      final message = AppErrorMapper.toUserMessage(
        Exception(
          'ApiRequestException(ApiRequestExceptionType.tls): TLS handshake or certificate validation failed',
        ),
        l10n,
      );

      expect(
        message,
        'Secure connection failed. Please check the server URL and ensure it supports HTTPS with a valid certificate.',
      );
    });

    test('mappt Login-Fehler auf lokalisierte Auth-Meldung', () {
      final message = AppErrorMapper.toUserMessage(
        Exception('Login failed'),
        l10n,
      );

      expect(message, equals(l10n.errorAuthentication));
    });

    test('mappt unbekannten Fehler auf generische Meldung', () {
      final message = AppErrorMapper.toUserMessage(
        Exception('Very internal stacktrace detail'),
        l10n,
      );

      expect(message, equals(l10n.errorGeneric));
    });
  });
}
