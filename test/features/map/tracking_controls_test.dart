import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:endurain/features/map/widgets/tracking_controls.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithL10n(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('pt')],
    home: Scaffold(body: child),
  );
}

TrackingSessionSnapshot _snapshot(TrackingSessionState state) {
  final start = DateTime.utc(2026, 3, 9, 10, 0, 0);
  return TrackingSessionSnapshot(
    state: state,
    activityType: ActivityType.run,
    startTime: start,
    duration: const Duration(seconds: 42),
    distanceMeters: 1200,
    elevationGainMeters: 64,
    trackPoints: const [],
  );
}

class _TrackingControlsHarness extends StatefulWidget {
  const _TrackingControlsHarness({
    required this.onStart,
    this.suggestedActivityType,
  });

  final ValueChanged<ActivityType> onStart;
  final ActivityType? suggestedActivityType;

  @override
  State<_TrackingControlsHarness> createState() => _TrackingControlsHarnessState();
}

class _TrackingControlsHarnessState extends State<_TrackingControlsHarness> {
  TrackingSessionSnapshot snapshot = const TrackingSessionSnapshot.idle();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('pt')],
      home: Scaffold(
        body: TrackingControls(
          snapshot: snapshot,
          suggestedActivityType: widget.suggestedActivityType,
          onStart: (type) {
            widget.onStart(type);
            setState(() {
              snapshot = TrackingSessionSnapshot(
                state: TrackingSessionState.recording,
                activityType: type,
                startTime: DateTime.utc(2026, 3, 9, 10, 0, 0),
                duration: const Duration(seconds: 3),
                distanceMeters: 12,
                elevationGainMeters: 4,
                trackPoints: const [],
              );
            });
          },
          onPause: () {
            setState(() {
              snapshot = snapshot.copyWith(state: TrackingSessionState.paused);
            });
          },
          onResume: () {
            setState(() {
              snapshot = snapshot.copyWith(state: TrackingSessionState.recording);
            });
          },
          onStop: () {
            setState(() {
              snapshot = TrackingSessionSnapshot(
                state: TrackingSessionState.stopped,
                activityType: snapshot.activityType,
                startTime: snapshot.startTime,
                duration: const Duration(seconds: 10),
                distanceMeters: 150,
                elevationGainMeters: 12,
                trackPoints: const [],
              );
            });
          },
        ),
      ),
    );
  }
}

void main() {
  group('TrackingControls', () {
    testWidgets('idle state: Start sichtbar, Stop nicht aktiv', (tester) async {
      await tester.pumpWidget(
        _wrapWithL10n(
          const TrackingControls(
            snapshot: TrackingSessionSnapshot.idle(),
            onStart: _ignoreStart,
            onPause: _ignoreVoid,
            onResume: _ignoreVoid,
            onStop: _ignoreStop,
          ),
        ),
      );

      expect(find.byKey(const Key('tracking-start-stop-button')), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Start tracking'), findsOneWidget);
      expect(find.text('Stop tracking'), findsNothing);
      expect(find.text('Idle'), findsOneWidget);
    });

    testWidgets('recording state: Stop aktiv, Recording-Indikator sichtbar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithL10n(
          TrackingControls(
            snapshot: _snapshot(TrackingSessionState.recording),
            onStart: _ignoreStart,
            onPause: _ignoreVoid,
            onResume: _ignoreVoid,
            onStop: _ignoreStop,
          ),
        ),
      );

      expect(find.text('Recording'), findsOneWidget);
      expect(find.text('Stop tracking'), findsOneWidget);
      expect(find.text('Start tracking'), findsNothing);
      expect(find.byKey(const Key('tracking-pause-resume-button')), findsOneWidget);
      expect(find.text('Pace'), findsOneWidget);
      expect(find.text('Elevation gain'), findsOneWidget);

      final rideChip = tester.widget<ChoiceChip>(
        find.byKey(const Key('tracking-type-ride')),
      );
      expect(rideChip.onSelected, isNull);
    });

    testWidgets('stopped state: Session abgeschlossen, Statuswechsel korrekt', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithL10n(
          TrackingControls(
            snapshot: _snapshot(TrackingSessionState.stopped),
            onStart: _ignoreStart,
            onPause: _ignoreVoid,
            onResume: _ignoreVoid,
            onStop: _ignoreStop,
          ),
        ),
      );

      expect(find.text('Stopped'), findsOneWidget);
      expect(find.text('Start tracking'), findsOneWidget);
      expect(find.text('Stop tracking'), findsNothing);
      expect(find.byKey(const Key('tracking-pause-resume-button')), findsNothing);
    });

    testWidgets('idle -> recording -> stopped über Start/Stop Button', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _TrackingControlsHarness(onStart: _ignoreStart),
      );

      expect(find.byKey(const Key('tracking-status-label')), findsOneWidget);
      expect(find.text('Idle'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tracking-start-stop-button')));
      await tester.pump();
      expect(find.text('Recording'), findsOneWidget);
      expect(find.byKey(const Key('tracking-pause-resume-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tracking-pause-resume-button')));
      await tester.pump();
      expect(find.text('Paused'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tracking-pause-resume-button')));
      await tester.pump();
      expect(find.text('Recording'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tracking-start-stop-button')));
      await tester.pump();
      expect(find.text('Stopped'), findsOneWidget);
    });

    testWidgets(
      'aktivitaetstyp run/ride/walk waehlt korrekt und reagiert im UI',
      (tester) async {
      ActivityType? startedType;
      await tester.pumpWidget(
        _TrackingControlsHarness(
          onStart: (type) {
            startedType = type;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('tracking-type-walk')));
      await tester.pump();
      final walkChip = tester.widget<ChoiceChip>(
        find.byKey(const Key('tracking-type-walk')),
      );
      expect(walkChip.selected, isTrue);

      await tester.tap(find.byKey(const Key('tracking-type-ride')));
      await tester.pump();

      final rideChip = tester.widget<ChoiceChip>(
        find.byKey(const Key('tracking-type-ride')),
      );
      expect(rideChip.selected, isTrue);

      await tester.tap(find.byKey(const Key('tracking-type-run')));
      await tester.pump();

      final runChip = tester.widget<ChoiceChip>(
        find.byKey(const Key('tracking-type-run')),
      );
      expect(runChip.selected, isTrue);

      await tester.tap(find.byKey(const Key('tracking-type-ride')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tracking-start-stop-button')));
      await tester.pump();

      expect(startedType, ActivityType.ride);
    });

    testWidgets('zeigt Repeat-Shortcut und startet mit letztem Typ', (
      tester,
    ) async {
      ActivityType? startedType;
      await tester.pumpWidget(
        _TrackingControlsHarness(
          suggestedActivityType: ActivityType.walk,
          onStart: (type) => startedType = type,
        ),
      );

      expect(find.byKey(const Key('tracking-repeat-last-button')), findsOneWidget);
      expect(find.textContaining('Repeat last'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tracking-repeat-last-button')));
      await tester.pump();
      expect(startedType, ActivityType.walk);
      expect(find.text('Recording'), findsOneWidget);
    });
  });
}

void _ignoreStart(ActivityType _) {}

void _ignoreStop() {}

void _ignoreVoid() {}
