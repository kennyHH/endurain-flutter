import 'package:endurain/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _serverUrl = String.fromEnvironment(
  'ENDURAIN_TEST_SERVER_URL',
  defaultValue: '',
);
const _username = String.fromEnvironment(
  'ENDURAIN_TEST_USERNAME',
  defaultValue: '',
);
const _password = String.fromEnvironment(
  'ENDURAIN_TEST_PASSWORD',
  defaultValue: '',
);
const _bypassLock = bool.fromEnvironment(
  'ENDURAIN_E2E_BYPASS_LOCK',
  defaultValue: false,
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Unlock -> Login -> Map flow', (WidgetTester tester) async {
    expect(_serverUrl.isNotEmpty, isTrue);
    expect(_username.isNotEmpty, isTrue);
    expect(_password.isNotEmpty, isTrue);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 8));

    final mapStart = find.byKey(const Key('tracking-start-stop-button'));
    expect(mapStart, findsNothing);

    final unlockLabel = find.text('Unlock');
    if (unlockLabel.evaluate().isNotEmpty && !_bypassLock) {
      expect(unlockLabel, findsWidgets);
      return;
    }

    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(mapStart, findsNothing);

    final serverField = find.byType(TextFormField).first;
    await tester.enterText(serverField, _serverUrl);

    final nextButton = find.text('Next');
    if (nextButton.evaluate().isNotEmpty) {
      await tester.tap(nextButton.first);
    } else {
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final textFields = find.byType(TextFormField);
    expect(textFields, findsAtLeastNWidgets(2));

    await tester.enterText(textFields.at(0), _username);
    await tester.enterText(textFields.at(1), _password);

    final loginButton = find.text('Login');
    expect(loginButton, findsWidgets);
    await tester.tap(loginButton.first);

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (mapStart.evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(
      mapStart,
      findsOneWidget,
      reason: 'Map must become available only after successful login',
    );
  });
}
