import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorageService extends SecureStorageService {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }
}

void main() {
  group('InMemoryActivityRepository', () {
    test('create + getById funktionieren', () async {
      final repo = InMemoryActivityRepository();
      final activity = Activity(
        id: 'id-1',
        activityType: ActivityType.ride,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:01:00Z'),
        distanceMeters: 1000,
        trackPoints: const [],
      );

      await repo.create(activity);

      final byId = await repo.getById('id-1');
      expect(byId?.id, equals('id-1'));
      expect(byId?.activityType, equals(ActivityType.ride));
    });

    test('update ersetzt bestehenden Datensatz', () async {
      final repo = InMemoryActivityRepository();
      final activity = Activity(
        id: 'id-1',
        activityType: ActivityType.walk,
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

    test('listAll ist sortiert nach startedAt', () async {
      final repo = InMemoryActivityRepository();
      await repo.create(
        Activity(
          id: 'id-late',
          activityType: ActivityType.run,
          startedAt: DateTime.parse('2026-03-09T10:10:00Z'),
          endedAt: null,
          distanceMeters: 1,
          trackPoints: const [],
        ),
      );
      await repo.create(
        Activity(
          id: 'id-early',
          activityType: ActivityType.run,
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
  });

  group('PersistentActivityRepository', () {
    test('persistiert Aktivitäten über Repository-Neustart', () async {
      final storage = _FakeStorageService();
      final repoA = PersistentActivityRepository(storage: storage);
      final repoB = PersistentActivityRepository(storage: storage);

      final activity = Activity(
        id: 'persist-1',
        activityType: ActivityType.run,
        startedAt: DateTime.parse('2026-03-09T11:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T11:30:10Z'),
        distanceMeters: 5000,
        trackPoints: const [],
      );
      await repoA.create(activity);

      final loaded = await repoB.listAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, equals('persist-1'));
      expect(loaded.single.durationSeconds, equals(1810));
    });
  });
}
