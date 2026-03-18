import 'package:drift/native.dart';
import 'package:endurain/core/database/app_database.dart' as db;
import 'package:endurain/core/models/activity.dart' as model;
import 'package:endurain/core/services/activity_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryActivityRepository', () {
    test('create + getById funktionieren', () async {
      final repo = InMemoryActivityRepository();
      final activity = model.Activity(
        id: 'id-1',
        activityType: model.ActivityType.ride,
        activityTypeId: 12,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:01:00Z'),
        distanceMeters: 1000,
        trackPoints: const [],
      );

      await repo.create(activity);

      final byId = await repo.getById('id-1');
      expect(byId?.id, equals('id-1'));
      expect(byId?.activityType, equals(model.ActivityType.ride));
      expect(byId?.activityTypeId, equals(12));
    });

    test('update ersetzt bestehenden Datensatz', () async {
      final repo = InMemoryActivityRepository();
      final activity = model.Activity(
        id: 'id-1',
        activityType: model.ActivityType.walk,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: null,
        distanceMeters: 10,
        trackPoints: const [],
      );
      await repo.create(activity);

      await repo.update(
        activity.copyWith(
          endedAt: DateTime.parse('2026-03-09T10:00:30Z'),
          distanceMeters: 120,
        ),
      );

      final updated = await repo.getById('id-1');
      expect(updated, isNotNull);
      expect(updated!.distanceMeters, equals(120));
      expect(updated.isCompleted, isTrue);
    });

    test('update behält vorhandene TrackPoints bei Metadaten-Update', () async {
      final repo = InMemoryActivityRepository();
      final startedAt = DateTime.parse('2026-03-09T10:00:00Z');
      final activity = model.Activity(
        id: 'id-keep-points',
        activityType: model.ActivityType.walk,
        startedAt: startedAt,
        endedAt: null,
        distanceMeters: 10,
        trackPoints: const [],
      );
      await repo.create(activity);
      await repo.insertTrackPoint(
        'id-keep-points',
        model.TrackPoint(
          latitude: 48.1,
          longitude: 11.5,
          timestamp: startedAt.add(const Duration(seconds: 1)),
        ),
      );

      await repo.update(
        activity.copyWith(
          endedAt: startedAt.add(const Duration(minutes: 2)),
          distanceMeters: 250,
          trackPoints: const [],
        ),
      );

      final updated = await repo.getById('id-keep-points');
      expect(updated, isNotNull);
      expect(updated!.trackPoints, hasLength(1));
      expect(updated.distanceMeters, equals(250));
      expect(updated.isCompleted, isTrue);
    });

    test('listAll ist sortiert nach startedAt', () async {
      final repo = InMemoryActivityRepository();
      await repo.create(
        model.Activity(
          id: 'id-late',
          activityType: model.ActivityType.run,
          startedAt: DateTime.parse('2026-03-09T10:10:00Z'),
          endedAt: null,
          distanceMeters: 1,
          trackPoints: const [],
        ),
      );
      await repo.create(
        model.Activity(
          id: 'id-early',
          activityType: model.ActivityType.run,
          startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
          endedAt: null,
          distanceMeters: 1,
          trackPoints: const [],
        ),
      );

      final all = await repo.listAll();
      expect(all, hasLength(2));
      expect(all.first.id, equals('id-early'));
      expect(all.last.id, equals('id-late'));
    });

    test('nicht vorhandene ID liefert null', () async {
      final repo = InMemoryActivityRepository();
      final missing = await repo.getById('missing');
      expect(missing, isNull);
    });

    test(
      'countTrackPoints und getTrackPointsPage funktionieren im Speicher',
      () async {
        final repo = InMemoryActivityRepository();
        final startedAt = DateTime.parse('2026-03-09T10:00:00Z');
        await repo.create(
          model.Activity(
            id: 'id-page-memory',
            activityType: model.ActivityType.run,
            startedAt: startedAt,
            endedAt: null,
            distanceMeters: 0,
            trackPoints: const [],
          ),
        );
        for (var i = 0; i < 5; i++) {
          await repo.insertTrackPoint(
            'id-page-memory',
            model.TrackPoint(
              latitude: 48.0 + i,
              longitude: 11.0 + i,
              timestamp: startedAt.add(Duration(seconds: i)),
            ),
          );
        }

        final count = await repo.countTrackPoints('id-page-memory');
        expect(count, equals(5));
        final page = await repo.getTrackPointsPage(
          'id-page-memory',
          limit: 2,
          offset: 2,
        );
        expect(page, hasLength(2));
        expect(page.first.latitude, equals(50.0));
      },
    );
  });

  group('PersistentActivityRepository', () {
    late db.AppDatabase database;
    late PersistentActivityRepository repo;

    setUp(() {
      // Use in-memory database for testing
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      repo = PersistentActivityRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('persistiert Aktivitäten (DB Integration Test)', () async {
      final activity = model.Activity(
        id: 'id-db-1',
        activityType: model.ActivityType.run,
        activityTypeId: 2,
        startedAt: DateTime.parse('2026-03-09T12:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T12:30:00Z'),
        distanceMeters: 5000,
        trackPoints: const [],
      );

      await repo.create(activity);

      // Verify via repo
      final fetched = await repo.getById('id-db-1');
      expect(fetched, isNotNull);
      expect(fetched!.activityType, equals(model.ActivityType.run));
      expect(fetched.activityTypeId, equals(2));
      expect(fetched.distanceMeters, equals(5000));
    });

    test(
      'listAll liefert summary ohne TrackPoints, getById liefert volle Daten',
      () async {
        final startedAt = DateTime.parse('2026-03-09T12:00:00Z');
        final activity = model.Activity(
          id: 'id-db-summary',
          activityType: model.ActivityType.run,
          activityTypeId: 2,
          startedAt: startedAt,
          endedAt: startedAt.add(const Duration(minutes: 20)),
          distanceMeters: 4200,
          trackPoints: [
            model.TrackPoint(
              latitude: 48.1,
              longitude: 11.5,
              timestamp: startedAt.add(const Duration(seconds: 1)),
            ),
            model.TrackPoint(
              latitude: 48.2,
              longitude: 11.6,
              timestamp: startedAt.add(const Duration(seconds: 10)),
            ),
          ],
        );

        await repo.create(activity);

        final summaryList = await repo.listAll();
        expect(summaryList, hasLength(1));
        expect(summaryList.first.id, equals('id-db-summary'));
        expect(summaryList.first.activityTypeId, equals(2));
        expect(summaryList.first.trackPoints, isEmpty);

        final full = await repo.getById('id-db-summary');
        expect(full, isNotNull);
        expect(full!.trackPoints, hasLength(2));
      },
    );

    test(
      'update schreibt nur Metadaten und behält bestehende TrackPoints in der DB',
      () async {
        final startedAt = DateTime.parse('2026-03-09T12:00:00Z');
        final activity = model.Activity(
          id: 'id-db-meta-only',
          activityType: model.ActivityType.run,
          startedAt: startedAt,
          endedAt: null,
          distanceMeters: 1000,
          trackPoints: [
            model.TrackPoint(
              latitude: 48.1,
              longitude: 11.5,
              timestamp: startedAt.add(const Duration(seconds: 1)),
            ),
            model.TrackPoint(
              latitude: 48.2,
              longitude: 11.6,
              timestamp: startedAt.add(const Duration(seconds: 2)),
            ),
          ],
        );
        await repo.create(activity);

        await repo.update(
          activity.copyWith(
            endedAt: startedAt.add(const Duration(minutes: 12)),
            distanceMeters: 4100,
            trackPoints: const [],
          ),
        );

        final full = await repo.getById('id-db-meta-only');
        expect(full, isNotNull);
        expect(full!.trackPoints, hasLength(2));
        expect(full.distanceMeters, equals(4100));
        expect(full.isCompleted, isTrue);
      },
    );

    test(
      'mehrfache Metadaten-Updates bleiben idempotent für TrackPoints',
      () async {
        final startedAt = DateTime.parse('2026-03-09T13:00:00Z');
        final activity = model.Activity(
          id: 'id-db-idempotent',
          activityType: model.ActivityType.ride,
          startedAt: startedAt,
          endedAt: null,
          distanceMeters: 500,
          trackPoints: [
            model.TrackPoint(
              latitude: 48.0,
              longitude: 11.0,
              timestamp: startedAt.add(const Duration(seconds: 1)),
            ),
            model.TrackPoint(
              latitude: 48.01,
              longitude: 11.01,
              timestamp: startedAt.add(const Duration(seconds: 2)),
            ),
          ],
        );
        await repo.create(activity);

        await repo.update(
          activity.copyWith(distanceMeters: 1200, trackPoints: const []),
        );
        await repo.update(
          activity.copyWith(
            endedAt: startedAt.add(const Duration(minutes: 30)),
            distanceMeters: 1300,
            trackPoints: const [],
          ),
        );

        final full = await repo.getById('id-db-idempotent');
        expect(full, isNotNull);
        expect(full!.trackPoints, hasLength(2));
        expect(full.distanceMeters, equals(1300));
        expect(full.isCompleted, isTrue);
      },
    );

    test(
      'countTrackPoints und getTrackPointsPage funktionieren in der DB',
      () async {
        final startedAt = DateTime.parse('2026-03-09T14:00:00Z');
        await repo.create(
          model.Activity(
            id: 'id-db-paging',
            activityType: model.ActivityType.walk,
            startedAt: startedAt,
            endedAt: null,
            distanceMeters: 0,
            trackPoints: List.generate(
              6,
              (i) => model.TrackPoint(
                latitude: 48.0 + i,
                longitude: 11.0 + i,
                timestamp: startedAt.add(Duration(seconds: i)),
              ),
            ),
          ),
        );

        final count = await repo.countTrackPoints('id-db-paging');
        expect(count, equals(6));

        final page = await repo.getTrackPointsPage(
          'id-db-paging',
          limit: 3,
          offset: 2,
        );
        expect(page, hasLength(3));
        expect(page.first.latitude, equals(50.0));
        expect(page.last.latitude, equals(52.0));
      },
    );

    test('getSummaryById liefert Activity ohne TrackPoints', () async {
      final startedAt = DateTime.parse('2026-03-09T15:00:00Z');
      await repo.create(
        model.Activity(
          id: 'id-db-summary-by-id',
          activityType: model.ActivityType.run,
          startedAt: startedAt,
          endedAt: null,
          distanceMeters: 1500,
          trackPoints: [
            model.TrackPoint(
              latitude: 48.1,
              longitude: 11.5,
              timestamp: startedAt.add(const Duration(seconds: 1)),
            ),
          ],
        ),
      );

      final summary = await repo.getSummaryById('id-db-summary-by-id');
      expect(summary, isNotNull);
      expect(summary!.distanceMeters, equals(1500));
      expect(summary.trackPoints, isEmpty);
    });

    test('getById lädt große Trackdaten vollständig über Paging', () async {
      final startedAt = DateTime.parse('2026-03-09T16:00:00Z');
      final points = List.generate(
        2505,
        (i) => model.TrackPoint(
          latitude: 48.0 + (i / 10000),
          longitude: 11.0 + (i / 10000),
          timestamp: startedAt.add(Duration(seconds: i)),
        ),
      );
      await repo.create(
        model.Activity(
          id: 'id-db-paged-full',
          activityType: model.ActivityType.ride,
          startedAt: startedAt,
          endedAt: startedAt.add(const Duration(hours: 1)),
          distanceMeters: 42000,
          trackPoints: points,
        ),
      );

      final full = await repo.getById('id-db-paged-full');
      expect(full, isNotNull);
      expect(full!.trackPoints, hasLength(2505));
      expect(
        full.trackPoints.last.timestamp.difference(
          full.trackPoints.first.timestamp,
        ),
        equals(const Duration(seconds: 2504)),
      );
    });
  });
}
