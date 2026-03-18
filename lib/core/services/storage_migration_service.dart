import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:endurain/core/database/app_database.dart' as db;
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/secure_storage_service.dart';

class StorageMigrationService {
  StorageMigrationService({
    required db.AppDatabase database,
    SecureStorageService? storage,
  }) : _db = database,
       _storage = storage ?? SecureStorageService();

  final db.AppDatabase _db;
  final SecureStorageService _storage;
  static const String _legacyActivitiesKey = 'activities_v1';

  /// Migrates activities from SecureStorage to SQLite (Drift).
  /// Returns the number of migrated activities.
  Future<int> migrateFromLegacyStorage() async {
    // 1. Check if legacy data exists
    final legacyJson = await _storage.read(key: _legacyActivitiesKey);
    if (legacyJson == null || legacyJson.isEmpty) {
      return 0;
    }

    try {
      // 2. Parse JSON
      final dynamic decodedJson = json.decode(legacyJson);
      if (decodedJson is! List) {
        return 0;
      }
      final List<dynamic> decoded = decodedJson;
      final List<Activity> activities = decoded
          .map(
            (item) => Activity.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

      if (activities.isEmpty) {
        // Empty list but key existed? Just delete key.
        await _storage.delete(key: _legacyActivitiesKey);
        return 0;
      }

      // 3. Insert into Drift (Batch Transaction)
      await _db.transaction(() async {
        for (final activity in activities) {
          // Check if already exists to be safe
          final exists = await (_db.select(
            _db.activities,
          )..where((tbl) => tbl.id.equals(activity.id))).getSingleOrNull();

          if (exists == null) {
            // Insert Activity
            await _db
                .into(_db.activities)
                .insert(
                  db.ActivitiesCompanion.insert(
                    id: activity.id,
                    activityType: activity.activityType,
                    startedAt: activity.startedAt,
                    endedAt: drift.Value(activity.endedAt),
                    name: drift.Value(activity.name),
                    uploaded: drift.Value(activity.uploaded),
                    distanceMeters: activity.distanceMeters,
                  ),
                );

            // Insert TrackPoints
            if (activity.trackPoints.isNotEmpty) {
              await _db.batch((batch) {
                batch.insertAll(
                  _db.trackPoints,
                  activity.trackPoints.map(
                    (tp) => db.TrackPointsCompanion.insert(
                      activityId: activity.id,
                      latitude: tp.latitude,
                      longitude: tp.longitude,
                      timestamp: tp.timestamp,
                      altitudeMeters: drift.Value(tp.altitudeMeters),
                      // speed, heartRate, cadence are null for legacy data
                    ),
                  ),
                );
              });
            }
          }
        }
      });

      // 4. Verify & Cleanup
      // We assume if transaction completed, data is safe.
      // Delete legacy key to prevent re-migration and free up SecureStorage.
      await _storage.delete(key: _legacyActivitiesKey);

      return activities.length;
    } catch (e) {
      // Log error but DO NOT delete legacy data if migration fails
      debugPrint('Migration failed: $e');
      rethrow;
    }
  }
}
