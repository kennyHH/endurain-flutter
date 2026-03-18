import 'dart:convert';

import 'package:drift/native.dart';
import 'package:endurain/core/database/app_database.dart' as db;
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/storage_migration_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorageService extends SecureStorageService {
  final Map<String, String?> _values = <String, String?>{};
  final List<String> deletedKeys = <String>[];

  void setValue(String key, String? value) {
    _values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> delete({required String key}) async {
    deletedKeys.add(key);
    _values.remove(key);
  }
}

Activity _legacyActivity({
  required String id,
  required DateTime startedAt,
}) {
  return Activity(
    id: id,
    activityType: ActivityType.run,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 5)),
    distanceMeters: 1200,
    trackPoints: [
      TrackPoint(
        latitude: 48.1372,
        longitude: 11.5756,
        timestamp: startedAt.add(const Duration(seconds: 5)),
      ),
      TrackPoint(
        latitude: 48.1375,
        longitude: 11.5760,
        timestamp: startedAt.add(const Duration(seconds: 35)),
      ),
    ],
  );
}

void main() {
  group('StorageMigrationService', () {
    late db.AppDatabase database;
    late _FakeStorageService storage;
    late StorageMigrationService service;

    setUp(() {
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      storage = _FakeStorageService();
      service = StorageMigrationService(database: database, storage: storage);
    });

    tearDown(() async {
      await database.close();
    });

    test('migrates legacy activities into drift and clears legacy key', () async {
      final legacy = [
        _legacyActivity(
          id: 'legacy-1',
          startedAt: DateTime.parse('2026-03-10T08:00:00Z'),
        ),
        _legacyActivity(
          id: 'legacy-2',
          startedAt: DateTime.parse('2026-03-10T09:00:00Z'),
        ),
      ];
      storage.setValue(
        'activities_v1',
        json.encode(legacy.map((activity) => activity.toJson()).toList()),
      );

      final migratedCount = await service.migrateFromLegacyStorage();

      expect(migratedCount, equals(2));
      expect(storage.deletedKeys, contains('activities_v1'));

      final activities = await database.select(database.activities).get();
      final trackPoints = await database.select(database.trackPoints).get();
      expect(activities, hasLength(2));
      expect(trackPoints, hasLength(4));
    });

    test('returns 0 when no legacy data is present', () async {
      final migratedCount = await service.migrateFromLegacyStorage();

      expect(migratedCount, equals(0));
      expect(storage.deletedKeys, isEmpty);
    });

    test('does not duplicate already migrated activities', () async {
      final legacy = _legacyActivity(
        id: 'legacy-dup',
        startedAt: DateTime.parse('2026-03-10T10:00:00Z'),
      );
      storage.setValue('activities_v1', json.encode([legacy.toJson()]));

      await service.migrateFromLegacyStorage();
      storage.setValue('activities_v1', json.encode([legacy.toJson()]));
      final secondRunCount = await service.migrateFromLegacyStorage();

      final activities = await database.select(database.activities).get();
      expect(secondRunCount, equals(1));
      expect(activities, hasLength(1));
    });
  });
}
