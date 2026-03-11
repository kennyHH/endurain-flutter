import 'package:endurain/core/utils/validators.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('Validators ENDU-008', () {
    test('validateRequired: null -> Fehler', () {
      final result = Validators.validateRequired(null, l10n, 'field');
      expect(result, equals(l10n.requiredField));
    });

    test('validateRequired: leer -> Fehler', () {
      final result = Validators.validateRequired('', l10n, 'field');
      expect(result, equals(l10n.requiredField));
    });

    test('validateRequired: whitespace -> Fehler', () {
      final result = Validators.validateRequired('   ', l10n, 'field');
      expect(result, equals(l10n.requiredField));
    });

    test('validateRequired: gefuellter Wert -> null', () {
      final result = Validators.validateRequired('value', l10n, 'field');
      expect(result, isNull);
    });

    test('validateUrl: gueltige https URL -> null', () {
      final result = Validators.validateUrl('https://example.com', l10n);
      expect(result, isNull);
    });

    test('validateUrl: ungueltige URL -> Fehler', () {
      final result = Validators.validateUrl('not-a-url', l10n);
      expect(result, equals(l10n.invalidUrl));
    });

    test(
      'validateServerUrl: externes http wird abgelehnt, https bleibt erlaubt',
      () {
        final httpResult = Validators.validateServerUrl(
          'http://example.com',
          l10n,
        );
        final httpsResult = Validators.validateServerUrl(
          'https://example.com',
          l10n,
        );

        expect(httpResult, equals(l10n.httpsRequiredUrl));
        expect(httpsResult, isNull);
      },
    );

    test('validateServerUrl: lokales http bleibt fuer self-hosted erlaubt', () {
      final localIp = Validators.validateServerUrl('http://192.168.0.22', l10n);
      final localhost = Validators.validateServerUrl(
        'http://localhost:8080',
        l10n,
      );

      expect(localIp, isNull);
      expect(localhost, isNull);
    });
  });
}
