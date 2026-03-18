import 'package:endurain/core/services/api_request_executor.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/features/settings/server_settings_screen.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeStorage extends SecureStorageService {
  _FakeStorage({required this.connected});

  final bool connected;

  @override
  Future<String?> getServerUrl() async => connected ? 'https://example.com' : '';

  @override
  Future<String?> getUsername() async =>
      connected ? 'runner@endurain.test' : 'Not logged in';

  @override
  Future<String?> getTileServerUrl() async =>
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  Future<bool> isAuthenticated() async => connected;
}

class _FakeAuth extends AuthService {
  _FakeAuth({required super.storage})
    : super(
        requestExecutor: ApiRequestExecutor(
          MockClient((_) async => http.Response('', 200)),
        ),
      );

  @override
  Future<bool> logout() async => true;
}

Widget _wrap(Widget child) {
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

void main() {
  testWidgets('zeigt Login statt Logout wenn nicht verbunden', (tester) async {
    final storage = _FakeStorage(connected: false);
    final auth = _FakeAuth(storage: storage);

    await tester.pumpWidget(
      _wrap(
        ServerSettingsScreen(
          storage: storage,
          authService: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Logout'), findsNothing);
  });

  testWidgets('zeigt Logout wenn verbunden', (tester) async {
    final storage = _FakeStorage(connected: true);
    final auth = _FakeAuth(storage: storage);

    await tester.pumpWidget(
      _wrap(
        ServerSettingsScreen(
          storage: storage,
          authService: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Logout'), findsOneWidget);
  });
}
