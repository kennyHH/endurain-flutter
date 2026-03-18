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
import 'login_golden_test.mocks.dart';

@GenerateMocks([LoginController, ErrorHandlerService])
void main() {
  late MockLoginController mockLoginController;
  late MockErrorHandlerService mockErrorHandler;

  setUp(() async {
    mockLoginController = MockLoginController();
    mockErrorHandler = MockErrorHandlerService();

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
      home: Scaffold(body: child),
      debugShowCheckedModeBanner: false,
    );
  }

  testWidgets('LoginScreen initial state matches golden', (tester) async {
    // Set surface size to a standard phone size
    await tester.binding.setSurfaceSize(const Size(400, 800));
    
    await tester.pumpWidget(wrapApp(const LoginScreen()));
    
    // Wait for assets/animations
    await tester.pumpAndSettle();

    // Verify visual appearance
    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/login_screen_initial.png'),
    );
  });
}
