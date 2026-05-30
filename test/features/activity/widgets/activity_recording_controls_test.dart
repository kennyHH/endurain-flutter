import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_upload_state.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/services/activity_recording_service.dart';
import 'package:endurain/features/activity/widgets/activity_recording_controls.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityRecordingControls', () {
    testWidgets('shows start action when idle', (tester) async {
      ActivityType? startedType;

      await tester.pumpWidget(
        _TestApp(
          child: ActivityRecordingControls(
            state: ActivityRecordingState(),
            selectedActivityType: ActivityType.run,
            onActivityTypeChanged: (_) {},
            onStart: (type) => startedType = type,
            onPause: null,
            onResume: null,
            onStop: null,
          ),
        ),
      );

      expect(find.text(AppLocalizationsEn().activityStart), findsOneWidget);

      await tester.tap(find.text(AppLocalizationsEn().activityStart));

      expect(startedType, ActivityType.run);
    });

    testWidgets('shows activity type picker before start', (tester) async {
      ActivityType? selectedType;

      await tester.pumpWidget(
        _TestApp(
          child: ActivityRecordingControls(
            state: ActivityRecordingState(),
            selectedActivityType: ActivityType.run,
            onActivityTypeChanged: (type) => selectedType = type,
            onStart: (_) {},
            onPause: null,
            onResume: null,
            onStop: null,
          ),
        ),
      );

      expect(find.text(AppLocalizationsEn().activityTypeLabel), findsOneWidget);
      expect(find.text(AppLocalizationsEn().activityTypeRun), findsOneWidget);

      await tester.tap(find.text(AppLocalizationsEn().activityTypeRun));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizationsEn().activityTypeRide).last);
      await tester.pumpAndSettle();

      expect(selectedType, ActivityType.ride);
    });

    testWidgets('shows pause and stop while recording', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: ActivityRecordingControls(
            state: ActivityRecordingState(
              status: ActivityRecordingStatus.recording,
            ),
            selectedActivityType: ActivityType.run,
            onActivityTypeChanged: null,
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
            selectedActivityType: ActivityType.run,
            onActivityTypeChanged: null,
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
            selectedActivityType: ActivityType.run,
            onActivityTypeChanged: null,
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

    testWidgets('shows localized empty recording errors', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: ActivityRecordingControls(
            state: ActivityRecordingState(
              status: ActivityRecordingStatus.failed,
              lastErrorKey: ActivityRecordingErrorKeys.emptyRecording,
            ),
            selectedActivityType: ActivityType.run,
            onActivityTypeChanged: null,
            onStart: (_) {},
            onPause: null,
            onResume: null,
            onStop: null,
          ),
        ),
      );

      expect(find.text(AppLocalizationsEn().activityRecordingEmpty), findsOneWidget);
    });

    testWidgets('shows settings action for denied forever', (tester) async {
      var openedSettings = false;

      await tester.pumpWidget(
        _TestApp(
          child: ActivityRecordingControls(
            state: ActivityRecordingState(
              status: ActivityRecordingStatus.failed,
              lastErrorKey:
                  ActivityRecordingErrorKeys.locationPermissionDeniedForever,
            ),
            selectedActivityType: ActivityType.run,
            onActivityTypeChanged: null,
            onStart: (_) {},
            onPause: null,
            onResume: null,
            onStop: null,
            onOpenLocationSettings: () => openedSettings = true,
          ),
        ),
      );

      expect(
        find.text(AppLocalizationsEn().activityLocationPermissionDeniedForever),
        findsOneWidget,
      );

      await tester.tap(find.text(AppLocalizationsEn().activityOpenSettings));

      expect(openedSettings, isTrue);
    });

    testWidgets('shows upload actions for completed recordings', (tester) async {
      var retried = false;
      var discarded = false;

      await tester.pumpWidget(
        _TestApp(
          child: ActivityRecordingControls(
            state: ActivityRecordingState(
              status: ActivityRecordingStatus.completed,
            ),
            selectedActivityType: ActivityType.run,
            onActivityTypeChanged: null,
            onStart: null,
            onPause: null,
            onResume: null,
            onStop: null,
            uploadStatus: ActivityUploadStatus.failed,
            onRetryUpload: () => retried = true,
            onDiscard: () => discarded = true,
          ),
        ),
      );

      expect(find.text(AppLocalizationsEn().activityUploadFailed), findsOneWidget);

      await tester.tap(find.text(AppLocalizationsEn().activityRetryUpload));
      await tester.tap(find.text(AppLocalizationsEn().activityDiscard));

      expect(retried, isTrue);
      expect(discarded, isTrue);
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