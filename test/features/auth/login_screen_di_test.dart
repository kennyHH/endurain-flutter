import 'package:endurain/features/auth/login_screen.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:endurain/features/auth/controllers/login_controller.dart';
import 'package:endurain/core/di/service_locator.dart';
import 'package:endurain/core/error_handling/error_handler_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'login_screen_di_test.mocks.dart';

@GenerateMocks([LoginController, ErrorHandlerService])
void main() {
  late MockLoginController mockLoginController;
  late MockErrorHandlerService mockErrorHandler;

  setUp(() async {
    mockLoginController = MockLoginController();
    mockErrorHandler = MockErrorHandlerService();

    // Default mocks
    when(mockLoginController.isLoading).thenReturn(false);
    when(mockLoginController.isStep2).thenReturn(false);
    when(mockLoginController.showMfaInput).thenReturn(false);
    when(mockLoginController.error).thenReturn(null);
    when(mockLoginController.loginSuccess).thenReturn(false);
    when(mockLoginController.localLoginEnabled).thenReturn(true);
    when(mockLoginController.availableIdPs).thenReturn([]);
    when(mockLoginController.serverSettings).thenReturn(null);
    when(mockLoginController.obscurePassword).thenReturn(true);

    await serviceLocator.reset();
    serviceLocator.registerSingleton<LoginController>(mockLoginController);
    serviceLocator.registerSingleton<ErrorHandlerService>(mockErrorHandler);
  });

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
    testWidgets('nutzt injizierten LoginController', (tester) async {
      when(mockLoginController.checkServerUrl(any)).thenAnswer((_) async {
        when(mockLoginController.isStep2).thenReturn(true);
        // notifyListeners() behavior
      });

      await tester.pumpWidget(wrapApp(const Scaffold(body: LoginScreen())));

      await tester.enterText(
        find.byType(TextFormField).first,
        'https://endurain.example.com',
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      verify(
        mockLoginController.checkServerUrl('https://endurain.example.com'),
      ).called(1);
    });
  });
}
