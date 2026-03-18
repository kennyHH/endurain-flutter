import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/di/service_locator.dart';
import 'package:endurain/features/settings/controllers/settings_controller.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:endurain/features/map/widgets/tracking_controls.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'tracking_controls_test.mocks.dart';

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

  final void Function(ActivityType activityType, int activityTypeId) onStart;
  final ActivityType? suggestedActivityType;

  @override
  State<_TrackingControlsHarness> createState() =>
      _TrackingControlsHarnessState();
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
          hasGpsFix: true,
          onStart: (type, activityTypeId) {
            widget.onStart(type, activityTypeId);
            setState(() {
              snapshot = TrackingSessionSnapshot(
                state: TrackingSessionState.recording,
                activityType: type,
                activityTypeId: activityTypeId,
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
              snapshot = snapshot.copyWith(
                state: TrackingSessionState.recording,
              );
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

@GenerateMocks([
  TrackingSessionEngine,
  SettingsController,
  SecureStorageService,
])
void main() {
  late MockTrackingSessionEngine mockEngine;
  late MockSettingsController mockSettings;
  late MockSecureStorageService mockStorage;

  setUp(() async {
    mockEngine = MockTrackingSessionEngine();
    mockSettings = MockSettingsController();
    mockStorage = MockSecureStorageService();

    when(mockStorage.getMetricConfig()).thenAnswer((_) async => null);

    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorageService>(mockStorage);
    serviceLocator.registerSingleton<TrackingSessionEngine>(mockEngine);
    serviceLocator.registerSingleton<SettingsController>(mockSettings);
  });

  group('TrackingControls', () {
    testWidgets('idle state: Start sichtbar, Stop nicht aktiv', (tester) async {
      await tester.pumpWidget(
        _wrapWithL10n(
          const TrackingControls(
            snapshot: TrackingSessionSnapshot.idle(),
            hasGpsFix: true,
            onStart: _ignoreStart,
            onPause: _ignoreVoid,
            onResume: _ignoreVoid,
            onStop: _ignoreStop,
          ),
        ),
      );

      expect(
        find.byKey(const Key('tracking-start-stop-button')),
        findsOneWidget,
      );
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
            hasGpsFix: true,
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
      expect(
        find.byKey(const Key('tracking-pause-resume-button')),
        findsOneWidget,
      );
      expect(find.text('Pace'), findsOneWidget);
      expect(find.text('Elevation gain'), findsOneWidget);

      expect(
        find.byKey(const Key('tracking-activity-type-selector')),
        findsOneWidget,
      );
    });

    testWidgets('stopped state: Session abgeschlossen, Statuswechsel korrekt', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithL10n(
          TrackingControls(
            snapshot: _snapshot(TrackingSessionState.stopped),
            hasGpsFix: true,
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
      expect(
        find.byKey(const Key('tracking-pause-resume-button')),
        findsNothing,
      );
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
      expect(
        find.byKey(const Key('tracking-pause-resume-button')),
        findsOneWidget,
      );

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
      'aktivitaetstypauswahl oeffnet liste und aktualisiert starttyp',
      (tester) async {
        ActivityType? startedType;
        await tester.pumpWidget(
          _TrackingControlsHarness(
            onStart: (type, _) {
              startedType = type;
            },
          ),
        );

        await tester.tap(
          find.byKey(const Key('tracking-activity-type-selector')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('activity-type-option-4')), findsOneWidget);

        await tester.tap(find.byKey(const Key('activity-type-option-4')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tracking-start-stop-button')));
        await tester.pump();

        expect(startedType, ActivityType.ride);
        expect(find.text('Recording'), findsOneWidget);
      },
    );

    testWidgets('startet ohne Repeat-Shortcut mit vorgeschlagenem Typ', (
      tester,
    ) async {
      ActivityType? startedType;
      await tester.pumpWidget(
        _TrackingControlsHarness(
          suggestedActivityType: ActivityType.walk,
          onStart: (type, _) => startedType = type,
        ),
      );

      expect(
        find.byKey(const Key('tracking-repeat-last-button')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('tracking-start-stop-button')));
      await tester.pump();
      expect(startedType, ActivityType.walk);
      expect(find.text('Recording'), findsOneWidget);
    });

    testWidgets('ohne GPS Fix ist Start disabled mit Hinweistext', (
      tester,
    ) async {
      var startCalls = 0;
      await tester.pumpWidget(
        _wrapWithL10n(
          TrackingControls(
            snapshot: const TrackingSessionSnapshot.idle(),
            hasGpsFix: false,
            onStart: (_, activityTypeId) => startCalls++,
            onPause: _ignoreVoid,
            onResume: _ignoreVoid,
            onStop: _ignoreStop,
          ),
        ),
      );

      expect(
        find.byKey(const Key('tracking-start-disabled-reason')),
        findsOneWidget,
      );
      expect(find.text('Start tracking'), findsOneWidget);

      final buttonFinder = find.byKey(const Key('tracking-start-stop-button'));
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.onPressed, isNull);

      await tester.tap(buttonFinder);
      await tester.pump();
      expect(startCalls, equals(0));
    });
  });
}

void _ignoreStart(ActivityType activityType, int activityTypeId) {}

void _ignoreStop() {}

void _ignoreVoid() {}
