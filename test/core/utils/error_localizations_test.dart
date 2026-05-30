import 'package:flutter_test/flutter_test.dart';
import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/core/utils/error_localizations.dart';
import 'package:endurain/l10n/app_localizations_en.dart';

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
  });
}
