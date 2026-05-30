import 'package:flutter_test/flutter_test.dart';
import 'package:endurain/shared/adaptive/adaptive.dart';

void main() {
  testWidgets('AdaptiveButton renders label and handles taps', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      AdaptiveApp(
        title: 'Test',
        home: AdaptiveButton(
          label: 'Save',
          onPressed: () {
            tapped = true;
          },
        ),
      ),
    );

    expect(find.text('Save'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
