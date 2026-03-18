import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:endurain/core/database/app_database.dart' as db;
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityRepository Benchmark', () {
    late db.AppDatabase database;
    late PersistentActivityRepository repo;

    setUp(() {
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      repo = PersistentActivityRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      '50k TrackPoints Vorher/Nachher Benchmark mit Median und P95',
      () async {
        const totalPoints = 50000;
        final startedAt = DateTime.parse('2026-03-10T06:00:00Z');
        const activityId = 'benchmark-50k';
        const iterations = 10;
        final trackPoints = List.generate(
          totalPoints,
          (i) => TrackPoint(
            latitude: 48.0 + (i / 100000.0),
            longitude: 11.0 + (i / 100000.0),
            timestamp: startedAt.add(Duration(seconds: i)),
          ),
        );

        final seedRssBefore = ProcessInfo.currentRss;
        final seedWatch = Stopwatch()..start();
        await repo.create(
          Activity(
            id: activityId,
            activityType: ActivityType.ride,
            startedAt: startedAt,
            endedAt: startedAt.add(const Duration(hours: 2)),
            distanceMeters: 80000,
            trackPoints: trackPoints,
          ),
        );
        seedWatch.stop();
        final seedRssAfter = ProcessInfo.currentRss;

        final legacyDurations = <int>[];
        final pagedDurations = <int>[];
        final summaryDurations = <int>[];
        List<TrackPoint>? legacyMapped;
        Activity? pagedFull;
        Activity? summary;

        final pagedRssBefore = ProcessInfo.currentRss;

        for (var i = 0; i < iterations; i++) {
          final legacyWatch = Stopwatch()..start();
          final legacyRows =
              await (database.select(database.trackPoints)
                    ..where((t) => t.activityId.equals(activityId))
                    ..orderBy([
                      (t) => drift.OrderingTerm(expression: t.timestamp),
                    ]))
                  .get();
          legacyMapped = legacyRows
              .map(
                (p) => TrackPoint(
                  latitude: p.latitude,
                  longitude: p.longitude,
                  timestamp: p.timestamp,
                  altitudeMeters: p.altitudeMeters ?? 0.0,
                  heartRate: p.heartRate,
                ),
              )
              .toList();
          legacyWatch.stop();
          legacyDurations.add(legacyWatch.elapsedMilliseconds);

          final pagedWatch = Stopwatch()..start();
          pagedFull = await repo.getById(activityId);
          pagedWatch.stop();
          pagedDurations.add(pagedWatch.elapsedMilliseconds);

          final summaryWatch = Stopwatch()..start();
          summary = await repo.getSummaryById(activityId);
          summaryWatch.stop();
          summaryDurations.add(summaryWatch.elapsedMilliseconds);
        }

        final pagedRssAfter = ProcessInfo.currentRss;

        final legacyMedian = _percentileMs(legacyDurations, 0.5);
        final legacyP95 = _percentileMs(legacyDurations, 0.95);
        final pagedMedian = _percentileMs(pagedDurations, 0.5);
        final pagedP95 = _percentileMs(pagedDurations, 0.95);
        final summaryMedian = _percentileMs(summaryDurations, 0.5);
        final summaryP95 = _percentileMs(summaryDurations, 0.95);

        stdout.writeln(
          'BENCHMARK_SEED_MS=${seedWatch.elapsedMilliseconds} '
          'BENCHMARK_SEED_RSS_DELTA_KB=${((seedRssAfter - seedRssBefore) / 1024).toStringAsFixed(1)}',
        );
        stdout.writeln(
          'BENCHMARK_ITERATIONS=$iterations '
          'BENCHMARK_LEGACY_MEDIAN_MS=$legacyMedian '
          'BENCHMARK_LEGACY_P95_MS=$legacyP95 '
          'BENCHMARK_LEGACY_POINTS=${legacyMapped?.length ?? 0}',
        );
        stdout.writeln(
          'BENCHMARK_PAGED_MEDIAN_MS=$pagedMedian '
          'BENCHMARK_PAGED_P95_MS=$pagedP95 '
          'BENCHMARK_PAGED_POINTS=${pagedFull?.trackPoints.length ?? 0} '
          'BENCHMARK_PAGED_RSS_DELTA_KB=${((pagedRssAfter - pagedRssBefore) / 1024).toStringAsFixed(1)}',
        );
        stdout.writeln(
          'BENCHMARK_SUMMARY_MEDIAN_MS=$summaryMedian '
          'BENCHMARK_SUMMARY_P95_MS=$summaryP95 '
          'BENCHMARK_SUMMARY_POINTS=${summary?.trackPoints.length ?? -1}',
        );

        expect(legacyMapped, isNotNull);
        expect(legacyMapped!.length, totalPoints);
        expect(pagedFull, isNotNull);
        expect(pagedFull!.trackPoints.length, totalPoints);
        expect(summary, isNotNull);
        expect(summary!.trackPoints, isEmpty);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

int _percentileMs(List<int> values, double percentile) {
  if (values.isEmpty) return 0;
  final sorted = List<int>.from(values)..sort();
  final rank = ((sorted.length - 1) * percentile).round();
  return sorted[rank.clamp(0, sorted.length - 1)];
}
