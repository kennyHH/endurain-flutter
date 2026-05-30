import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/widgets/activity_recording_controls.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityRecordingControls', () {
    testWidgets('shows start action when idle', (tester) async {
      var started = false;

      await tester.pumpWidget(
        _TestApp(
          child: ActivityRecordingControls(
            state: ActivityRecordingState(),
            onStart: () => started = true,
            onPause: null,
            onResume: null,
            onStop: null,
          ),
        ),
      );

      expect(find.text(AppLocalizationsEn().activityStart), findsOneWidget);

      await tester.tap(find.text(AppLocalizationsEn().activityStart));

      expect(started, isTrue);
    });

    testWidgets('shows pause and stop while recording', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: ActivityRecordingControls(
            state: ActivityRecordingState(
              status: ActivityRecordingStatus.recording,
            ),
            onStart: null,
            onPause: () {},
            onResume: null,
            onStop: () {},
          ),
        ),
      );

      expect(find.text(AppLocalizationsEn().activityPause), findsOneWidget);
      expect(find.text(AppLocalizationsEn().activityStop), findsOneWidget);
    });

    testWidgets('shows resume and stop while paused', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: ActivityRecordingControls(
            state: ActivityRecordingState(status: ActivityRecordingStatus.paused),
            onStart: null,
            onPause: null,
            onResume: () {},
            onStop: () {},
          ),
        ),
      );

      expect(find.text(AppLocalizationsEn().activityResume), findsOneWidget);
      expect(find.text(AppLocalizationsEn().activityStop), findsOneWidget);
    });

    testWidgets('disables unsafe actions while stopping', (tester) async {
      var stopped = false;

      await tester.pumpWidget(
        _TestApp(
          child: ActivityRecordingControls(
            state: ActivityRecordingState(
              status: ActivityRecordingStatus.stopping,
            ),
            onStart: null,
            onPause: null,
            onResume: null,
            onStop: () => stopped = true,
          ),
        ),
      );

      expect(find.text(AppLocalizationsEn().activityStopping), findsOneWidget);

      await tester.tap(find.text(AppLocalizationsEn().activityStopping));

      expect(stopped, isFalse);
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }
}