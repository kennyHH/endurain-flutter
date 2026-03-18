import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:endurain/main.dart' as app;
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full App Launch Test', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // The app starts at LoginScreen which has a server URL input field
    // We check for the presence of a TextFormField, which indicates the login screen is loaded
    expect(find.byType(TextFormField), findsAtLeastNWidgets(1));

    // Also check for the "Next" button or similar initial UI element
    // Based on LoginScreen implementation, it should have a button to proceed
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
