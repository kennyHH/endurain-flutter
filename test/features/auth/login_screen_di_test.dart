import 'package:endurain/core/models/server_settings.dart';
import 'package:endurain/core/services/server_settings_service.dart';
import 'package:endurain/features/auth/login_screen.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class _FakeServerSettingsService extends ServerSettingsService {
  _FakeServerSettingsService({
    required this.settings,
    this.shouldThrow = false,
  });

  final ServerSettings settings;
  final bool shouldThrow;
  int calls = 0;

  @override
  Future<ServerSettings> getServerSettings({String? serverUrl}) async {
    calls += 1;
    if (shouldThrow) {
      throw Exception('network timeout');
    }
    return settings;
  }
}

void main() {
  const defaultSettings = ServerSettings(
    units: 'metric',
    publicShareableLinks: false,
    publicShareableLinksUserInfo: false,
    loginPhotoSet: false,
    currency: 'euro',
    numRecordsPerPage: 25,
    signupEnabled: false,
    ssoEnabled: false,
    localLoginEnabled: true,
    ssoAutoRedirect: false,
    passwordType: 'strict',
    passwordLengthRegularUsers: 8,
    passwordLengthAdminUsers: 12,
  );

  Widget wrapApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('pt')],
      home: child,
    );
  }

  group('LoginScreen DI', () {
    testWidgets(
      'nutzt injizierten ServerSettingsService fuer Step-1',
      (tester) async {
        final fakeServerSettings = _FakeServerSettingsService(
          settings: defaultSettings,
        );

        await tester.pumpWidget(
          wrapApp(
            LoginScreen(
              serverSettingsService: fakeServerSettings,
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'https://endurain.example.com',
        );
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        expect(fakeServerSettings.calls, equals(1));
        expect(find.byIcon(Icons.person), findsOneWidget);
      },
    );

    testWidgets(
      'bleibt bei Step-1 wenn injizierter Service Fehler wirft',
      (tester) async {
        final fakeServerSettings = _FakeServerSettingsService(
          settings: defaultSettings,
          shouldThrow: true,
        );

        await tester.pumpWidget(
          wrapApp(
            LoginScreen(
              serverSettingsService: fakeServerSettings,
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'https://endurain.example.com',
        );
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        expect(fakeServerSettings.calls, equals(1));
        expect(find.byIcon(Icons.person), findsNothing);
      },
    );
  });
}
