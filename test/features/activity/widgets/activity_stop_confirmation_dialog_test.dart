import 'package:endurain/features/activity/widgets/activity_stop_confirmation_dialog.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('showActivityStopConfirmationDialog', () {
    testWidgets('returns cancel without stopping', (tester) async {
      ActivityStopAction? selectedAction;

      await tester.pumpWidget(
        _TestApp(
          onAction: (action) => selectedAction = action,
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizationsEn().cancel));
      await tester.pumpAndSettle();

      expect(selectedAction, ActivityStopAction.cancel);
    });

    testWidgets('returns stop when stop is selected', (tester) async {
      ActivityStopAction? selectedAction;

      await tester.pumpWidget(
        _TestApp(
          onAction: (action) => selectedAction = action,
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizationsEn().activityStopAndSave));
      await tester.pumpAndSettle();

      expect(selectedAction, ActivityStopAction.stop);
    });

    testWidgets('requires a second choice before discard', (tester) async {
      ActivityStopAction? selectedAction;

      await tester.pumpWidget(
        _TestApp(
          onAction: (action) => selectedAction = action,
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizationsEn().activityDiscard).first);
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsEn().activityDiscardConfirmTitle),
        findsOneWidget,
      );

      await tester.tap(find.text(AppLocalizationsEn().activityDiscard).last);
      await tester.pumpAndSettle();

      expect(selectedAction, ActivityStopAction.discard);
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.onAction});

  final ValueChanged<ActivityStopAction> onAction;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          return TextButton(
            onPressed: () async {
              onAction(await showActivityStopConfirmationDialog(context));
            },
            child: const Text('open'),
          );
        },
      ),
    );
  }
}