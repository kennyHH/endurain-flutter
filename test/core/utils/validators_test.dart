import 'package:endurain/core/utils/validators.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('Validators.validateServerUrl', () {
    test('null -> requiredField', () {
      final result = Validators.validateServerUrl(null, l10n);

      expect(result, equals(l10n.requiredField));
    });

    test("leerer Input ('') -> requiredField", () {
      final result = Validators.validateServerUrl('', l10n);

      expect(result, equals(l10n.requiredField));
    });

    test('http://example.com -> Fehler', () {
      final result = Validators.validateServerUrl('http://example.com', l10n);

      expect(result, equals(l10n.httpsRequiredUrl));
    });

    test('http://192.168.1.10 -> OK (lokales Netzwerk)', () {
      final result = Validators.validateServerUrl('http://192.168.1.10', l10n);

      expect(result, isNull);
    });

    test('http://localhost -> OK', () {
      final result = Validators.validateServerUrl(
        'http://localhost:8080',
        l10n,
      );

      expect(result, isNull);
    });

    test('https://example.com -> OK', () {
      final result = Validators.validateServerUrl('https://example.com', l10n);

      expect(result, isNull);
    });

    test('invalid URL -> Fehler wie bisher', () {
      final result = Validators.validateServerUrl('not-a-url', l10n);

      expect(result, equals(l10n.invalidUrl));
    });
  });
}
