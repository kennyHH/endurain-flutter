import 'package:flutter_test/flutter_test.dart';
import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/core/utils/error_localizations.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:endurain/l10n/app_localizations_pt.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('localizedErrorMessage', () {
    test('localizes app exceptions without details', () {
      expect(
        localizedErrorMessage(
          const AppException(AppErrorCode.sessionExpired),
          l10n,
        ),
        l10n.errorSessionExpired,
      );
    });

    test('localizes app exceptions with server details', () {
      expect(
        localizedErrorMessage(
          const AppException(
            AppErrorCode.loginFailed,
            details: 'Bad credentials',
          ),
          l10n,
        ),
        l10n.errorLoginFailedWithDetails('Bad credentials'),
      );
    });

    test('strips plain Exception prefix from fallback errors', () {
      expect(
        localizedErrorMessage(Exception('Network failed'), l10n),
        'Network failed',
      );
    });

    test('returns the raw string for non-Exception errors', () {
      expect(localizedErrorMessage('plain error', l10n), 'plain error');
    });

    for (final AppLocalizations locale in <AppLocalizations>[
      AppLocalizationsEn(),
      AppLocalizationsPt(),
    ]) {
      test(
        'maps every error code to a non-empty message (${locale.localeName})',
        () {
          for (final code in AppErrorCode.values) {
            final withoutDetails = localizedErrorMessage(
              AppException(code),
              locale,
            );
            expect(
              withoutDetails,
              isNotEmpty,
              reason: '$code without details (${locale.localeName})',
            );

            final withDetails = localizedErrorMessage(
              AppException(code, details: 'boundary-detail'),
              locale,
            );
            expect(
              withDetails,
              isNotEmpty,
              reason: '$code with details (${locale.localeName})',
            );
          }
        },
      );
    }
  });
}
