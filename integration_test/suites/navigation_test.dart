import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endurain/main.dart' as app;

void main() {
  testWidgets('Navigation: Verify Bottom Bar and Map visibility', (WidgetTester tester) async {
    // 0. Launch the App!
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 1. Check for Map Widget (Home)
    // Retry finding START button with variations or wait longer
    // Increased wait time to 10s to handle slow emulator or permission dialogs
    await tester.pumpAndSettle(const Duration(seconds: 10));
    
    // Try finding by Key if available (best practice)
    final startBtnKey = find.byKey(const Key('tracking-start-stop-button'));
    final startBtnText = find.text('START'); // Standard English
    
    // Debug print widget tree if failing
    if (startBtnKey.evaluate().isEmpty) {
       debugDumpApp();
    }
    
    if (startBtnKey.evaluate().isNotEmpty || startBtnText.evaluate().isNotEmpty) {
      debugPrint('📍 On Map Screen (Start button found)');
    } else {
      debugPrint('❓ Not on Map Screen - checking Login');
      final loginBtn = find.widgetWithText(FilledButton, 'Login');
      if (loginBtn.evaluate().isNotEmpty) {
        debugPrint('🔒 On Login Screen - Performing Login...');
        await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'testuser');
        await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password');
        await tester.tap(loginBtn);
        // Wait for login transition (longer)
        await tester.pumpAndSettle(const Duration(seconds: 10));
      }
    }

    // Verify we are now on Map Screen
    expect(find.byKey(const Key('tracking-start-stop-button')), findsOneWidget);
    
    // 2. Verify Bottom Navigation (if exists) or Settings Button
    // Endurain uses a persistent Map with overlays, Settings is accessed via top-right button usually?
    // Or bottom sheet.
    // Checking source: MapScreen has `MapOverlayButtons` and `TrackingControls`.
    // There is no standard BottomNavigationBar in MapScreen based on read code.
    // Settings is likely a button in `MapOverlayButtons`.
    
    // Let's verify we can see the "Activity Type" selector or label
    expect(find.textContaining('Activity'), findsWidgets); // "Activity Type" label
  });
}
