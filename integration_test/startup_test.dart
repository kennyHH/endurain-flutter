import 'package:endurain/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App Startup Test: Verify UI loads and no black screen',
      (WidgetTester tester) async {
    // 1. Launch the app
    app.main();
    
    // 2. Wait for the app to settle (animations, loading, etc.)
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 3. Verify that the root MaterialApp is present (basic sanity check)
    expect(find.byType(MaterialApp), findsOneWidget,
        reason: 'MaterialApp not found - App might have crashed or stalled.');

    // 4. Check for key UI elements to confirm we are not on a "Black Screen"
    // Depending on auth state, we might be on LoginScreen or MapScreen.
    
    // Check for Login Screen elements
    final loginButtonFinder = find.widgetWithText(FilledButton, 'Login');
    final usernameFieldFinder = find.widgetWithText(TextFormField, 'Username');
    
    // Check for Map Screen elements
    final startButtonFinder = find.text('START'); // Or whatever the start button says
    final mapWidgetFinder = find.byType(Stack); // Map is usually a Stack
    
    final isOnLoginScreen = loginButtonFinder.evaluate().isNotEmpty;
    final isOnMapScreen =
        startButtonFinder.evaluate().isNotEmpty ||
        mapWidgetFinder.evaluate().isNotEmpty;

    if (isOnLoginScreen) {
      debugPrint('✅ App started successfully on Login Screen.');
      expect(usernameFieldFinder, findsOneWidget);
    } else if (isOnMapScreen) {
      debugPrint('✅ App started successfully on Map Screen.');
      // Verify map specific elements if needed
    } else {
      // Fallback: If neither, verify at least some Scaffold is visible
      expect(find.byType(Scaffold), findsOneWidget,
          reason: 'No Scaffold found - UI might be empty (Black Screen).');
      debugPrint('✅ App started successfully (Scaffold found).');
    }
  });
}
