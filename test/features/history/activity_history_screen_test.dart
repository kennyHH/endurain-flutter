import 'dart:async';

import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/services/activity_upload_service.dart';
import 'package:endurain/features/history/activity_history_screen.dart';
import 'package:endurain/features/history/activity_detail_screen.dart';
import 'package:endurain/features/history/widgets/activity_route_map.dart';
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
  int getByIdCalls = 0;
  int getTrackPointsPageCalls = 0;
  final Map<String, Activity> byId = <String, Activity>{};
  final StreamController<List<Activity>> controller =
      StreamController<List<Activity>>.broadcast();

  @override
  Future<void> create(Activity activity) async {}

  @override
  Future<void> delete(String id) async {
    activities = activities.where((item) => item.id != id).toList();
    byId.remove(id);
    controller.add(activities);
  }

  @override
  Future<void> insertTrackPoint(String activityId, TrackPoint point) async {}

  @override
  Future<Activity?> getById(String id) async {
    getByIdCalls++;
    return byId[id];
  }

  @override
  Future<Activity?> getSummaryById(String id) async {
    final activity = byId[id];
    if (activity == null) return null;
    return activity.copyWith(trackPoints: const <TrackPoint>[]);
  }

  @override
  Future<int> countTrackPoints(String activityId) async {
    return byId[activityId]?.trackPoints.length ?? 0;
  }

  @override
  Future<List<TrackPoint>> getTrackPointsPage(
    String activityId, {
    required int limit,
    int offset = 0,
  }) async {
    getTrackPointsPageCalls++;
    final points = byId[activityId]?.trackPoints ?? const <TrackPoint>[];
    if (offset >= points.length) return const <TrackPoint>[];
    final end = (offset + limit).clamp(0, points.length);
    return points.sublist(offset, end);
  }

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

Activity _activity(
  String id,
  ActivityType type, {
  DateTime? startedAt,
  int? activityTypeId,
}) {
  final start = startedAt ?? DateTime.parse('2026-03-09T10:00:00Z');
  return Activity(
    id: id,
    activityType: type,
    activityTypeId: activityTypeId,
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 10)),
    distanceMeters: 4200,
    trackPoints: [
      TrackPoint(latitude: 38.72, longitude: -9.13, timestamp: start),
      TrackPoint(
        latitude: 38.721,
        longitude: -9.129,
        timestamp: start.add(const Duration(minutes: 1)),
      ),
    ],
  );
}

void main() {
  group('ActivityHistoryScreen', () {
    testWidgets('zeigt loading und danach empty state', (tester) async {
      final repo = _FakeActivityRepository(activities: const <Activity>[]);
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
      );

      expect(find.byKey(const Key('history-loading')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-empty-title')), findsOneWidget);
      expect(find.text('No activities yet'), findsOneWidget);
    });

    testWidgets('zeigt list und navigiert in detailansicht', (tester) async {
      final full = _activity('a-run', ActivityType.run);
      final repo = _FakeActivityRepository(
        activities: <Activity>[full.copyWith(trackPoints: const [])],
      );
      repo.byId[full.id] = full;
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-list')), findsOneWidget);
      expect(find.byType(Card), findsWidgets);

      await tester.tap(find.byType(Card).first);
      await tester.pumpAndSettle();

      expect(find.text('Activity details'), findsOneWidget);
      expect(find.text('Pace'), findsWidgets);
      expect(find.text('Elevation gain'), findsOneWidget);
      expect(repo.getByIdCalls, greaterThan(0));
    });

    testWidgets('tap auf Kartenvorschau oeffnet detailansicht', (tester) async {
      final full = Activity(
        id: 'a-map-tap',
        activityType: ActivityType.run,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:10:00Z'),
        distanceMeters: 4200,
        trackPoints: [
          TrackPoint(
            latitude: 38.7200,
            longitude: -9.1300,
            timestamp: DateTime.parse('2026-03-09T10:00:00Z'),
          ),
          TrackPoint(
            latitude: 38.7210,
            longitude: -9.1310,
            timestamp: DateTime.parse('2026-03-09T10:01:00Z'),
          ),
        ],
      );
      final repo = _FakeActivityRepository(
        activities: <Activity>[full.copyWith(trackPoints: const [])],
      );
      repo.byId[full.id] = full;
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byType(ActivityRouteMap).first,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Activity details'), findsOneWidget);
    });

    testWidgets('zeigt Elevation-Fallback aus vollstaendigen Trackpunkten', (
      tester,
    ) async {
      final summary = Activity(
        id: 'a-elev',
        activityType: ActivityType.run,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:10:00Z'),
        distanceMeters: 1200,
        trackPoints: const <TrackPoint>[],
      );
      final full = summary.copyWith(
        trackPoints: [
          TrackPoint(
            latitude: 38.7200,
            longitude: -9.1300,
            altitudeMeters: 10,
            timestamp: DateTime.parse('2026-03-09T10:00:00Z'),
          ),
          TrackPoint(
            latitude: 38.7210,
            longitude: -9.1310,
            altitudeMeters: 26,
            timestamp: DateTime.parse('2026-03-09T10:01:00Z'),
          ),
        ],
      );
      final repo = _FakeActivityRepository(activities: <Activity>[summary]);
      repo.byId[summary.id] = full;
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('16 m'), findsAtLeastNWidgets(1));
    });

    testWidgets('zeigt Pace aus hydratisierter Vollaktivitaet', (tester) async {
      final start = DateTime.parse('2026-03-19T11:42:08Z');
      final summary = Activity(
        id: 'a-pace-hydrated',
        activityType: ActivityType.run,
        startedAt: start,
        endedAt: start.add(const Duration(seconds: 60)),
        distanceMeters: 120,
        trackPoints: const <TrackPoint>[],
      );
      final full = summary.copyWith(distanceMeters: 80);
      final repo = _FakeActivityRepository(activities: <Activity>[summary]);
      repo.byId[summary.id] = full;
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
      );
      await tester.pumpAndSettle();

      expect(find.text('12:30 min/km'), findsAtLeastNWidgets(1));
      expect(find.text('08:20 min/km'), findsNothing);
    });

    testWidgets(
      'hydriert auch bei vorhandenen Trackpunkten wenn Summary-Metriken unplausibel sind',
      (tester) async {
        final start = DateTime.parse('2026-03-19T13:26:00Z');
        final summary = Activity(
          id: 'a-unplausible-summary',
          activityType: ActivityType.run,
          startedAt: start,
          endedAt: start,
          distanceMeters: 0,
          trackPoints: [
            TrackPoint(latitude: 51.0, longitude: 12.0, timestamp: start),
            TrackPoint(
              latitude: 51.0002,
              longitude: 12.0001,
              timestamp: start.add(const Duration(seconds: 8)),
            ),
          ],
        );
        final full = summary.copyWith(
          endedAt: start.add(const Duration(seconds: 61)),
          distanceMeters: 70,
        );
        final repo = _FakeActivityRepository(activities: <Activity>[summary]);
        repo.byId[summary.id] = full;
        addTearDown(repo.dispose);

        await tester.pumpWidget(
          _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
        );
        await tester.pumpAndSettle();

        expect(find.text('1m 01s'), findsAtLeastNWidgets(1));
        expect(find.text('0.07 km'), findsAtLeastNWidgets(1));
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data != null &&
                RegExp(r'^\d{2}:\d{2} min/km$').hasMatch(widget.data!),
          ),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets(
      'erneuert stale Snapshot wenn Summary später plausible Werte liefert',
      (tester) async {
        final start = DateTime.parse('2026-03-19T13:46:00Z');
        final summaryInvalid = Activity(
          id: 'a-stale-snapshot',
          activityType: ActivityType.run,
          startedAt: start,
          endedAt: start,
          distanceMeters: 0,
          trackPoints: [
            TrackPoint(latitude: 51.0, longitude: 12.0, timestamp: start),
            TrackPoint(
              latitude: 51.0002,
              longitude: 12.0001,
              timestamp: start.add(const Duration(seconds: 8)),
            ),
          ],
        );
        final fullInvalid = summaryInvalid;
        final summaryValid = summaryInvalid.copyWith(
          endedAt: start.add(const Duration(seconds: 61)),
          distanceMeters: 70,
        );
        final fullValid = summaryValid.copyWith(
          trackPoints: [
            TrackPoint(latitude: 51.0, longitude: 12.0, timestamp: start),
            TrackPoint(
              latitude: 51.0006,
              longitude: 12.0004,
              timestamp: start.add(const Duration(seconds: 61)),
            ),
          ],
        );
        final repo = _FakeActivityRepository(
          activities: <Activity>[summaryInvalid],
        );
        repo.byId[summaryInvalid.id] = fullInvalid;
        addTearDown(repo.dispose);

        await tester.pumpWidget(
          _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
        );
        await tester.pumpAndSettle();
        expect(find.text('0m 00s'), findsAtLeastNWidgets(1));

        repo.byId[summaryInvalid.id] = fullValid;
        repo.emit(<Activity>[summaryValid]);
        await tester.pumpAndSettle();

        expect(find.text('1m 01s'), findsAtLeastNWidgets(1));
        expect(find.text('0.07 km'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'erneuert stale Snapshot auch wenn Summary implausibel bleibt',
      (tester) async {
        final start = DateTime.parse('2026-03-19T13:46:00Z');
        final summary = Activity(
          id: 'a-stale-snapshot-implausible-summary',
          activityType: ActivityType.run,
          startedAt: start,
          endedAt: start,
          distanceMeters: 0,
          trackPoints: const <TrackPoint>[],
        );
        final fullInvalid = summary;
        final fullValid = summary.copyWith(
          endedAt: start.add(const Duration(seconds: 61)),
          distanceMeters: 70,
          trackPoints: [
            TrackPoint(latitude: 51.0, longitude: 12.0, timestamp: start),
            TrackPoint(
              latitude: 51.0006,
              longitude: 12.0004,
              timestamp: start.add(const Duration(seconds: 61)),
            ),
          ],
        );
        final repo = _FakeActivityRepository(activities: <Activity>[summary]);
        repo.byId[summary.id] = fullInvalid;
        addTearDown(repo.dispose);

        await tester.pumpWidget(
          _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('0m 00s'), findsAtLeastNWidgets(1));

        repo.byId[summary.id] = fullValid;
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        expect(find.text('1m 01s'), findsAtLeastNWidgets(1));
        expect(find.text('0.07 km'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'nach Loeschen aus Detailansicht landet Nutzer wieder in History',
      (tester) async {
        final full = _activity('a-delete', ActivityType.run);
        final repo = _FakeActivityRepository(
          activities: <Activity>[full.copyWith(trackPoints: const [])],
        );
        repo.byId[full.id] = full;
        addTearDown(repo.dispose);

        await tester.pumpWidget(
          _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Card).first);
        await tester.pumpAndSettle();

        final detailContext = tester.element(find.byType(ActivityDetailScreen));
        final l10n = AppLocalizations.of(detailContext)!;

        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, l10n.historyDeleteAction),
        );
        await tester.pumpAndSettle();

        expect(find.text('Activity details'), findsNothing);
        expect(find.byKey(const Key('history-list')), findsNothing);
        expect(find.byKey(const Key('history-empty-title')), findsOneWidget);
      },
    );

    testWidgets('zeigt error state und retry funktioniert', (tester) async {
      final repo = _FakeActivityRepository(throwOnWatch: true);
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
      );
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
      await tester.pumpWidget(
        _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-empty-title')), findsOneWidget);

      repo.emit(<Activity>[_activity('a-walk', ActivityType.walk)]);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-item-a-walk')), findsOneWidget);
    });

    testWidgets('lädt Trackpunkte für History-Kartenvorschau nach', (
      tester,
    ) async {
      final full = Activity(
        id: 'a-preview',
        activityType: ActivityType.run,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:10:00Z'),
        distanceMeters: 4200,
        trackPoints: [
          TrackPoint(
            latitude: 38.7200,
            longitude: -9.1300,
            timestamp: DateTime.parse('2026-03-09T10:00:00Z'),
          ),
          TrackPoint(
            latitude: 38.7210,
            longitude: -9.1310,
            timestamp: DateTime.parse('2026-03-09T10:01:00Z'),
          ),
        ],
      );
      final repo = _FakeActivityRepository(
        activities: <Activity>[full.copyWith(trackPoints: const [])],
      );
      repo.byId[full.id] = full;
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
      );
      await tester.pumpAndSettle();

      expect(repo.getTrackPointsPageCalls, greaterThan(0));
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
              return ActivityUploadResult.failure(
                attempts: 1,
                failureType: ActivityUploadFailureType.server,
              );
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

    testWidgets('retry upload button verschwindet sofort nach Erfolg', (
      tester,
    ) async {
      var retryCalls = 0;
      final activity = _activity('a-retry-ok', ActivityType.run);

      await tester.pumpWidget(
        _wrap(
          ActivityDetailScreen(
            activity: activity,
            onRetryUpload: () async {
              retryCalls++;
              return ActivityUploadResult.success(attempts: 1, statusCode: 201);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final retryButton = find.byKey(const Key('history-retry-upload-button'));
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(retryCalls, equals(1));
      expect(
        find.byKey(const Key('history-retry-upload-button')),
        findsNothing,
      );
    });

    testWidgets('zeigt Upload-Block-Hinweis bei ungueltiger Aktivitaet', (
      tester,
    ) async {
      final start = DateTime.parse('2026-03-19T11:22:00Z');
      final activity = Activity(
        id: 'a-invalid',
        activityType: ActivityType.run,
        startedAt: start,
        endedAt: start.add(const Duration(seconds: 9)),
        distanceMeters: 0,
        trackPoints: const <TrackPoint>[],
      );

      await tester.pumpWidget(
        _wrap(
          ActivityDetailScreen(
            activity: activity,
            onRetryUpload: () async => ActivityUploadResult.failure(
              attempts: 1,
              failureType: ActivityUploadFailureType.invalidActivity,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('history-retry-upload-button')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('history-upload-blocked-banner')),
        findsOneWidget,
      );
    });

    testWidgets(
      'zeigt Durchschnittsgeschwindigkeit auch fuer Run in Activity Details',
      (tester) async {
        final base = _activity('a-run-speed', ActivityType.run);
        final activity = base.copyWith(
          distanceMeters: 1200,
          endedAt: base.startedAt.add(const Duration(minutes: 6)),
        );

        await tester.pumpWidget(
          _wrap(
            ActivityDetailScreen(
              activity: activity,
              onRetryUpload: () async => ActivityUploadResult.failure(
                attempts: 1,
                failureType: ActivityUploadFailureType.server,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Avg speed'), findsOneWidget);
        expect(find.textContaining('km/h'), findsAtLeastNWidgets(1));
      },
    );

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

      await tester.pumpWidget(
        _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.byKey(const Key('history-item-a-today')), findsOneWidget);
      expect(find.textContaining('4.20 km'), findsAtLeastNWidgets(1));
    });

    testWidgets('zeigt Apply-Button im Filter-Dialog ohne Scrollen sichtbar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2160);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeActivityRepository(
        activities: <Activity>[_activity('a-run', ActivityType.run)],
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter & sort'));
      await tester.pumpAndSettle();

      final applyFinder = find.byKey(const Key('history-filter-apply'));
      final resetFinder = find.byKey(const Key('history-filter-reset'));
      expect(applyFinder, findsOneWidget);
      expect(resetFinder, findsOneWidget);

      final applyRect = tester.getRect(applyFinder);
      final viewportHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(applyRect.bottom, lessThanOrEqualTo(viewportHeight));
    });

    testWidgets('zeigt alle Kategorien im Filterdialog', (tester) async {
      final repo = _FakeActivityRepository(
        activities: <Activity>[_activity('a-run', ActivityType.run)],
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter & sort'));
      await tester.pumpAndSettle();

      expect(find.text('Trail run'), findsOneWidget);
      expect(find.text('Kayaking'), findsOneWidget);
    });

    testWidgets(
      'zeigt Sync-Infobox bei ausstehendem Upload und startet Connect',
      (tester) async {
        var connectCalls = 0;
        final repo = _FakeActivityRepository(
          activities: <Activity>[_activity('a-offline', ActivityType.run)],
        );
        addTearDown(repo.dispose);

        await tester.pumpWidget(
          _wrap(
            Scaffold(
              body: ActivityHistoryScreen(
                repository: repo,
                isServerConnected: false,
                onAuthRequired: () => connectCalls++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('history-sync-hint-card')), findsOneWidget);
        expect(find.text('Connect to server'), findsOneWidget);

        await tester.tap(find.byKey(const Key('history-sync-hint-connect')));
        await tester.pumpAndSettle();

        expect(connectCalls, equals(1));
      },
    );

    testWidgets('Sync-Infobox ist schließbar', (tester) async {
      var connectCalls = 0;
      final repo = _FakeActivityRepository(
        activities: <Activity>[_activity('a-close', ActivityType.run)],
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: ActivityHistoryScreen(
              repository: repo,
              isServerConnected: false,
              onAuthRequired: () => connectCalls++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-sync-hint-card')), findsOneWidget);

      await tester.tap(find.byKey(const Key('history-sync-hint-close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-sync-hint-card')), findsNothing);
      expect(connectCalls, equals(0));
    });

    testWidgets('filtert exakt nach Kategorie-ID wenn vorhanden', (
      tester,
    ) async {
      final repo = _FakeActivityRepository(
        activities: <Activity>[
          _activity('a-run', ActivityType.run, activityTypeId: 1),
          _activity('a-trail', ActivityType.run, activityTypeId: 2),
        ],
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter & sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trail run'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-item-a-trail')), findsOneWidget);
      expect(find.byKey(const Key('history-item-a-run')), findsNothing);
    });

    testWidgets('Reset setzt Filter auf All, All time und Newest zurueck', (
      tester,
    ) async {
      final repo = _FakeActivityRepository(
        activities: <Activity>[_activity('a-run', ActivityType.run)],
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _wrap(Scaffold(body: ActivityHistoryScreen(repository: repo))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter & sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trail run'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('7d'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('7d'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Oldest'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Oldest'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history-filter-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.textContaining('All • All time • Newest'), findsOneWidget);
    });

    testWidgets('zeigt bei Auth-Fehler Login-Aktion statt Upload-Retry', (
      tester,
    ) async {
      var authRequiredCalls = 0;
      var retryUploadCalls = 0;
      final activity = _activity('a-auth', ActivityType.run);
      final repo = _FakeActivityRepository(
        activities: <Activity>[activity.copyWith(trackPoints: const [])],
      );
      repo.byId[activity.id] = activity;
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: ActivityHistoryScreen(
              repository: repo,
              onAuthRequired: () => authRequiredCalls++,
              onRetryUpload: (_) async {
                retryUploadCalls++;
                return ActivityUploadResult.failure(
                  attempts: 1,
                  failureType: ActivityUploadFailureType.authentication,
                  serverDetail: 'Session expired. Please login again.',
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Card).first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('history-retry-upload-button')),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.byKey(const Key('history-retry-upload-button')));
      await tester.pumpAndSettle();

      expect(find.text('Session expired. Please login again.'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(retryUploadCalls, equals(1));
      expect(authRequiredCalls, equals(1));
    });
  });
}
