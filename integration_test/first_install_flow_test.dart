import 'package:endurain/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('First install flow gates map behind lock/login', (
    WidgetTester tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 8));

    final mapStart = find.byKey(const Key('tracking-start-stop-button'));
    final loginTitle = find.text('Login');
    final unlockLabel = find.text('Unlock');

    expect(
      mapStart,
      findsNothing,
      reason: 'Map must not be directly accessible before auth on first launch',
    );

    final onLogin = loginTitle.evaluate().isNotEmpty;
    final onLock = unlockLabel.evaluate().isNotEmpty;

    expect(
      onLogin || onLock,
      isTrue,
      reason: 'Expected either lock screen or login screen on first launch',
    );
  });
}
