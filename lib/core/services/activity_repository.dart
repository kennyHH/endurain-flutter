import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:endurain/core/database/app_database.dart' as db;
import 'package:endurain/core/models/activity.dart';
import 'package:injectable/injectable.dart';

abstract class ActivityRepository {
  Future<void> create(Activity activity);
  Future<void> update(Activity activity);
  Future<void> insertTrackPoint(String activityId, TrackPoint point);
  Future<Activity?> getById(String id);
  Future<Activity?> getSummaryById(String id) async {
    final activity = await getById(id);
    if (activity == null) return null;
    return activity.copyWith(trackPoints: const <TrackPoint>[]);
  }

  Future<int> countTrackPoints(String activityId) async {
    final activity = await getById(activityId);
    return activity?.trackPoints.length ?? 0;
  }

  Future<List<TrackPoint>> getTrackPointsPage(
    String activityId, {
    required int limit,
    int offset = 0,
  }) async {
    final activity = await getById(activityId);
    final points = activity?.trackPoints ?? const <TrackPoint>[];
    if (offset >= points.length) return const <TrackPoint>[];
    final end = (offset + limit).clamp(0, points.length);
    return points.sublist(offset, end);
  }

  Future<List<Activity>> listAll();
  Stream<List<Activity>> watchAll();
  Future<void> delete(String id);
}

class InMemoryActivityRepository implements ActivityRepository {
  final Map<String, Activity> _items = <String, Activity>{};
  final StreamController<List<Activity>> _streamController =
      StreamController<List<Activity>>.broadcast(sync: true);

  @override
  Future<void> create(Activity activity) async {
    _items[activity.id] = activity;
    _emit();
  }

  @override
  Future<void> update(Activity activity) async {
    final existing = _items[activity.id];
    final persistedPoints = existing?.trackPoints ?? activity.trackPoints;
    _items[activity.id] = activity.copyWith(trackPoints: persistedPoints);
    _emit();
  }

  @override
  Future<void> insertTrackPoint(String activityId, TrackPoint point) async {
    final activity = _items[activityId];
    if (activity != null) {
      final newPoints = List<TrackPoint>.from(activity.trackPoints)..add(point);
      _items[activityId] = activity.copyWith(trackPoints: newPoints);
      _emit();
    }
  }

  @override
  Future<Activity?> getById(String id) async {
    return _items[id];
  }

  @override
  Future<Activity?> getSummaryById(String id) async {
    final activity = _items[id];
    if (activity == null) return null;
    return activity.copyWith(trackPoints: const <TrackPoint>[]);
  }

  @override
  Future<int> countTrackPoints(String activityId) async {
    return _items[activityId]?.trackPoints.length ?? 0;
  }

  @override
  Future<List<TrackPoint>> getTrackPointsPage(
    String activityId, {
    required int limit,
    int offset = 0,
  }) async {
    final points = _items[activityId]?.trackPoints ?? const <TrackPoint>[];
    if (offset >= points.length) return const <TrackPoint>[];
    final end = (offset + limit).clamp(0, points.length);
    return points.sublist(offset, end);
  }

  @override
  Future<List<Activity>> listAll() async {
    return _sortedItems();
  }

  @override
  Stream<List<Activity>> watchAll() async* {
    yield _sortedItems();
    yield* _streamController.stream;
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
    _emit();
  }

  List<Activity> _sortedItems() {
    final values = _items.values.toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return List<Activity>.unmodifiable(values);
  }

  void _emit() {
    if (!_streamController.isClosed) {
      _streamController.add(_sortedItems());
    }
  }
}

@Singleton(as: ActivityRepository)
class PersistentActivityRepository implements ActivityRepository {
  PersistentActivityRepository({required db.AppDatabase database})
    : _db = database;

  final db.AppDatabase _db;
  static const int _trackPointPageSize = 1000;

  @override
  Future<void> create(Activity activity) async {
    await _db.transaction(() async {
      await _db
          .into(_db.activities)
          .insert(
            db.ActivitiesCompanion.insert(
              id: activity.id,
              activityType: activity.activityType,
              activityTypeId: drift.Value(activity.activityTypeId),
              startedAt: activity.startedAt,
              endedAt: drift.Value(activity.endedAt),
              name: drift.Value(activity.name),
              uploaded: drift.Value(activity.uploaded),
              distanceMeters: activity.distanceMeters,
              qualityMetricsJson: drift.Value(
                activity.qualityMetrics == null
                    ? null
                    : jsonEncode(activity.qualityMetrics),
              ),
            ),
          );

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
                heartRate: drift.Value(tp.heartRate),
                cadence: drift.Value(tp.cadence),
              ),
            ),
          );
        });
      }
    });
  }

  @override
  Future<void> insertTrackPoint(String activityId, TrackPoint point) async {
    await _db
        .into(_db.trackPoints)
        .insert(
          db.TrackPointsCompanion.insert(
            activityId: activityId,
            latitude: point.latitude,
            longitude: point.longitude,
            timestamp: point.timestamp,
            altitudeMeters: drift.Value(point.altitudeMeters),
            heartRate: drift.Value(point.heartRate),
          ),
        );
  }

  @override
  Future<void> update(Activity activity) async {
    await (_db.update(
      _db.activities,
    )..where((t) => t.id.equals(activity.id))).write(
      db.ActivitiesCompanion(
        activityType: drift.Value(activity.activityType),
        activityTypeId: drift.Value(activity.activityTypeId),
        startedAt: drift.Value(activity.startedAt),
        endedAt: drift.Value(activity.endedAt),
        name: drift.Value(activity.name),
        uploaded: drift.Value(activity.uploaded),
        distanceMeters: drift.Value(activity.distanceMeters),
        qualityMetricsJson: drift.Value(
          activity.qualityMetrics == null
              ? null
              : jsonEncode(activity.qualityMetrics),
        ),
      ),
    );
  }

  @override
  Future<Activity?> getById(String id) async {
    final activityRow = await (_db.select(
      _db.activities,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (activityRow == null) return null;

    final pointCount = await countTrackPoints(id);
    final points = <TrackPoint>[];
    var offset = 0;
    while (offset < pointCount) {
      final page = await getTrackPointsPage(
        id,
        limit: _trackPointPageSize,
        offset: offset,
      );
      if (page.isEmpty) break;
      points.addAll(page);
      offset += page.length;
    }

    return Activity(
      id: activityRow.id,
      activityType: activityRow.activityType,
      activityTypeId: activityRow.activityTypeId,
      startedAt: activityRow.startedAt,
      endedAt: activityRow.endedAt,
      name: activityRow.name,
      uploaded: activityRow.uploaded,
      distanceMeters: activityRow.distanceMeters,
      qualityMetrics: _decodeQualityMetrics(activityRow.qualityMetricsJson),
      trackPoints: points,
    );
  }

  @override
  Future<Activity?> getSummaryById(String id) async {
    final activityRow = await (_db.select(
      _db.activities,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (activityRow == null) return null;
    return _mapRowToSummary(activityRow);
  }

  @override
  Future<int> countTrackPoints(String activityId) async {
    final countExp = _db.trackPoints.id.count();
    final query = _db.selectOnly(_db.trackPoints)
      ..addColumns([countExp])
      ..where(_db.trackPoints.activityId.equals(activityId));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  @override
  Future<List<TrackPoint>> getTrackPointsPage(
    String activityId, {
    required int limit,
    int offset = 0,
  }) async {
    final rows =
        await (_db.select(_db.trackPoints)
              ..where((t) => t.activityId.equals(activityId))
              ..orderBy([(t) => drift.OrderingTerm(expression: t.timestamp)])
              ..limit(limit, offset: offset))
            .get();
    return rows
        .map(
          (p) => TrackPoint(
            latitude: p.latitude,
            longitude: p.longitude,
            timestamp: p.timestamp,
            altitudeMeters: p.altitudeMeters ?? 0.0,
            heartRate: p.heartRate,
            cadence: p.cadence,
          ),
        )
        .toList();
  }

  @override
  Future<List<Activity>> listAll() async {
    final activities =
        await (_db.select(_db.activities)..orderBy([
              (t) => drift.OrderingTerm(
                expression: t.startedAt,
                mode: drift.OrderingMode.asc,
              ),
            ]))
            .get();

    return activities.map(_mapRowToSummary).toList();
  }

  @override
  Stream<List<Activity>> watchAll() {
    final query = _db.select(_db.activities)
      ..orderBy([
        (t) => drift.OrderingTerm(
          expression: t.startedAt,
          mode: drift.OrderingMode.asc,
        ),
      ]);

    return query.watch().map((rows) => rows.map(_mapRowToSummary).toList());
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.activities)..where((t) => t.id.equals(id))).go();
  }

  Map<String, dynamic>? _decodeQualityMetrics(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Activity _mapRowToSummary(db.Activity row) {
    return Activity(
      id: row.id,
      activityType: row.activityType,
      activityTypeId: row.activityTypeId,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      name: row.name,
      uploaded: row.uploaded,
      distanceMeters: row.distanceMeters,
      qualityMetrics: _decodeQualityMetrics(row.qualityMetricsJson),
      trackPoints: const <TrackPoint>[],
    );
  }
}
