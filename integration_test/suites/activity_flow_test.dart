import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endurain/main.dart' as app;

void main() {
  testWidgets('Activity Flow: Start -> Countdown -> Record -> Stop', (WidgetTester tester) async {
    // 0. Ensure App is Running
    // Since previous tests might have finished or reset, let's bootstrap if needed.
    // However, calling main() twice might cause issues with singletons.
    // Let's assume the app is NOT running if we can't find the widget.
    
    if (find.byType(MaterialApp).evaluate().isEmpty) {
      debugPrint('🚀 Bootstrapping App for Activity Test...');
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
    } else {
      debugPrint('ℹ️ App already running, proceeding...');
    }

    // 1. Find START button
    final startButton = find.byKey(const Key('tracking-start-stop-button'));
    if (startButton.evaluate().isEmpty) {
      // Maybe app is still booting or logging in?
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }
    expect(startButton, findsOneWidget);

    // 2. Tap START
    debugPrint('🏃 Tapping START...');
    await tester.tap(startButton);
    await tester.pump(); // Trigger frame

    // 3. Verify Countdown
    // "Starting in..." logic.
    await tester.pump(const Duration(milliseconds: 500));
    // Verify start button is disabled or text changed?
    // The key is still 'tracking-start-stop-button' but text might be different?
    // Or it might be a different widget.
    // TrackingControls logic: if (isPreparingStart) returns a different button (FilledButton.tonal)
    // but without the Key!
    
    // So we search by text 'Starting in'
    expect(find.textContaining('Starting in'), findsOneWidget);
    
    // 4. Wait for countdown to finish (6 seconds total)
    // We pump frames to advance time
    for (int i = 0; i < 7; i++) {
       await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();

    // 5. Verify Recording State
    // "STOP" button should appear with key 'tracking-start-stop-button' again?
    // No, code says:
    // If recording: Row with Pause and Stop buttons.
    // Stop button has key 'tracking-start-stop-button'.
    // Pause button has key 'tracking-pause-resume-button'.
    
    expect(find.byKey(const Key('tracking-start-stop-button')), findsOneWidget);
    expect(find.byKey(const Key('tracking-pause-resume-button')), findsOneWidget);
    debugPrint('✅ Recording started.');

    // 6. Let it record for a bit
    await tester.pump(const Duration(seconds: 3));

    // 7. Stop Activity
    debugPrint('🛑 Tapping STOP...');
    await tester.tap(find.byKey(const Key('tracking-start-stop-button')));
    await tester.pumpAndSettle();

    // 8. Verify Reset
    // If it resets to IDLE, we should see Start button again (and no Pause button)
    expect(find.byKey(const Key('tracking-start-stop-button')), findsOneWidget);
    expect(find.byKey(const Key('tracking-pause-resume-button')), findsNothing);
    debugPrint('✅ Activity Stopped and Reset.');
  });
}
