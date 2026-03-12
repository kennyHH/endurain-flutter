import 'dart:async';

import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/features/history/activity_history_screen.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeActivityRepository implements ActivityRepository {
  _FakeActivityRepository({
    this.activities = const <Activity>[],
    this.throwOnWatch = false,
  });

  List<Activity> activities;
  bool throwOnWatch;
  int watchCalls = 0;
  final StreamController<List<Activity>> controller =
      StreamController<List<Activity>>.broadcast();

  @override
  Future<void> create(Activity activity) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<Activity?> getById(String id) async => null;

  @override
  Future<List<Activity>> listAll() async {
    return activities;
  }

  @override
  Stream<List<Activity>> watchAll() async* {
    watchCalls++;
    if (throwOnWatch) {
      throw Exception('boom');
    }
    yield activities;
    yield* controller.stream;
  }

  void emit(List<Activity> next) {
    activities = next;
    controller.add(next);
  }

  Future<void> dispose() async {
    await controller.close();
  }

  @override
  Future<void> update(Activity activity) async {}
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('pt')],
    home: child,
  );
}

Activity _activity(String id, ActivityType type, {DateTime? startedAt}) {
  final start = startedAt ?? DateTime.parse('2026-03-09T10:00:00Z');
  return Activity(
    id: id,
    activityType: type,
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 10)),
    distanceMeters: 4200,
    trackPoints: [
      TrackPoint(latitude: 38.72, longitude: -9.13, timestamp: start),
    ],
  );
}

void main() {
  group('ActivityHistoryScreen', () {
    testWidgets('zeigt loading und danach empty state', (tester) async {
      final repo = _FakeActivityRepository(activities: const <Activity>[]);
      addTearDown(repo.dispose);
      await tester.pumpWidget(_wrap(ActivityHistoryScreen(repository: repo)));

      expect(find.byKey(const Key('history-loading')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-empty-title')), findsOneWidget);
      expect(find.text('No activities yet'), findsOneWidget);
    });

    testWidgets('zeigt list und navigiert in detailansicht', (tester) async {
      final repo = _FakeActivityRepository(
        activities: <Activity>[_activity('a-run', ActivityType.run)],
      );
      addTearDown(repo.dispose);
      await tester.pumpWidget(_wrap(ActivityHistoryScreen(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-list')), findsOneWidget);
      expect(find.byKey(const Key('history-item-a-run')), findsOneWidget);

      await tester.tap(find.byKey(const Key('history-item-a-run')));
      await tester.pumpAndSettle();

      expect(find.text('Activity details'), findsOneWidget);
      expect(find.text('Pace'), findsOneWidget);
      expect(find.text('Elevation gain'), findsOneWidget);
    });

    testWidgets('zeigt error state und retry funktioniert', (tester) async {
      final repo = _FakeActivityRepository(throwOnWatch: true);
      addTearDown(repo.dispose);
      await tester.pumpWidget(_wrap(ActivityHistoryScreen(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-error')), findsOneWidget);
      expect(repo.watchCalls, equals(1));

      repo.throwOnWatch = false;
      repo.activities = <Activity>[_activity('a-ride', ActivityType.ride)];

      await tester.tap(find.byKey(const Key('history-retry-button')));
      await tester.pumpAndSettle();

      expect(repo.watchCalls, equals(2));
      expect(find.byKey(const Key('history-item-a-ride')), findsOneWidget);
    });

    testWidgets('aktualisiert liste live bei repository stream', (
      tester,
    ) async {
      final repo = _FakeActivityRepository(activities: const <Activity>[]);
      addTearDown(repo.dispose);
      await tester.pumpWidget(_wrap(ActivityHistoryScreen(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-empty-title')), findsOneWidget);

      repo.emit(<Activity>[_activity('a-walk', ActivityType.walk)]);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-item-a-walk')), findsOneWidget);
    });

    testWidgets('retry upload button im detail wird ausgelöst', (tester) async {
      var retryCalls = 0;
      final activity = _activity('a-ride', ActivityType.ride);

      await tester.pumpWidget(
        _wrap(
          ActivityDetailScreen(
            activity: activity,
            onRetryUpload: () async {
              retryCalls++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('history-retry-upload-button')),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.byKey(const Key('history-retry-upload-button')));
      await tester.pump();

      expect(retryCalls, equals(1));
    });

    testWidgets('zeigt Gruppenheader und kompakten Statistik-Text', (
      tester,
    ) async {
      final now = DateTime.now();
      final thisWeekStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      final thisWeekDate = thisWeekStart.add(const Duration(days: 2));
      final repo = _FakeActivityRepository(
        activities: <Activity>[
          _activity(
            'a-older',
            ActivityType.run,
            startedAt: now.subtract(const Duration(days: 20)),
          ),
          _activity('a-week', ActivityType.walk, startedAt: thisWeekDate),
          _activity(
            'a-yesterday',
            ActivityType.ride,
            startedAt: now.subtract(const Duration(days: 1)),
          ),
          _activity('a-today', ActivityType.run, startedAt: now),
        ],
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(_wrap(ActivityHistoryScreen(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.byKey(const Key('history-item-a-today')), findsOneWidget);
      expect(find.textContaining('4.20 km'), findsAtLeastNWidgets(1));
    });
  });
}
