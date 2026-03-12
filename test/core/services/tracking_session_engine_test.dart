import 'dart:async';

import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:endurain/core/services/audio_feedback_service.dart';

class MockAudioFeedbackService implements AudioFeedbackService {
  @override
  bool get isEnabled => false;

  @override
  Future<void> announceCountdown(int seconds) async {}

  @override
  Future<void> announceGpsStatus({required bool isLost}) async {}

  @override
  Future<void> announceSplit({required int km, required double paceSecondsPerKm}) async {}

  @override
  Future<void> announceStart() async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  void toggleEnabled(bool enabled) {}

  @override
  Future<void> updateSettings({required bool enabled, required bool announceSplits, required bool announceStart, bool announceGps = true}) async {}
}


class _FakePositionProvider implements PositionStreamProvider {
  final StreamController<PositionSample> controller =
      StreamController<PositionSample>.broadcast(sync: true);

  @override
  Stream<PositionSample> getPositionStream() => controller.stream;

  void emit({
    required double lat,
    required double lng,
    required DateTime time,
    double? altitude,
  }) {
    controller.add(
      PositionSample(
        latitude: lat,
        longitude: lng,
        timestamp: time,
        altitudeMeters: altitude,
      ),
    );
  }

  Future<void> dispose() => controller.close();
}

void main() {
  group('TrackingSessionEngine', () {
    test('start setzt recording state, stop setzt stopped state', () async {
      final repository = InMemoryActivityRepository();
      final provider = _FakePositionProvider();
      final engine = TrackingSessionEngine(
        audioService: MockAudioFeedbackService(),
        repository: repository,
        positionStreamProvider: provider,
      );

      final started = await engine.start(
        ActivityType.run,
        startedAt: DateTime.utc(2026, 3, 9, 10, 0, 0),
      );
      expect(started, isTrue);
      expect(engine.currentSessionState, TrackingSessionState.recording);

      final stopped = await engine.stop(
        endedAt: DateTime.utc(2026, 3, 9, 10, 0, 5),
      );
      expect(stopped, isNotNull);
      expect(engine.currentSessionState, TrackingSessionState.stopped);

      await provider.dispose();
      engine.dispose();
    });

    test('stop aus paused speichert Activity', () async {
      final repository = InMemoryActivityRepository();
      final provider = _FakePositionProvider();
      final engine = TrackingSessionEngine(
        audioService: MockAudioFeedbackService(),
        repository: repository,
        positionStreamProvider: provider,
      );

      final started = await engine.start(
        ActivityType.walk,
        startedAt: DateTime.utc(2026, 3, 9, 10, 0, 0),
      );
      expect(started, isTrue);

      await engine.pause();
      expect(engine.currentSessionState, TrackingSessionState.paused);

      final stopped = await engine.stop(
        endedAt: DateTime.utc(2026, 3, 9, 10, 0, 20),
      );
      expect(stopped, isNotNull);
      expect(engine.currentSessionState, TrackingSessionState.stopped);

      final all = await repository.listAll();
      expect(all, hasLength(1));

      await provider.dispose();
      engine.dispose();
    });

    test('addPoint im falschen state wird ignoriert', () async {
      final repository = InMemoryActivityRepository();
      final provider = _FakePositionProvider();
      final engine = TrackingSessionEngine(
        audioService: MockAudioFeedbackService(),
        repository: repository,
        positionStreamProvider: provider,
      );

      final accepted = engine.addPoint(
        TrackPoint(
          latitude: 38.7223,
          longitude: -9.1393,
          timestamp: DateTime.utc(2026, 3, 9, 10, 0, 0),
        ),
      );
      expect(accepted, isFalse);
      expect(engine.snapshot.trackPoints, isEmpty);

      await provider.dispose();
      engine.dispose();
    });

    test('start -> points -> stop speichert Activity im Repository', () async {
      final repository = InMemoryActivityRepository();
      final provider = _FakePositionProvider();
      var now = DateTime.utc(2026, 3, 9, 10, 0, 0);
      final engine = TrackingSessionEngine(
        audioService: MockAudioFeedbackService(),
        repository: repository,
        positionStreamProvider: provider,
        nowProvider: () => now,
      );

      final started = await engine.start(ActivityType.run);
      expect(started, isTrue);
      expect(engine.snapshot.state, TrackingSessionState.recording);

      provider.emit(lat: 38.7223, lng: -9.1393, time: now);
      now = now.add(const Duration(seconds: 10));
      provider.emit(lat: 38.7233, lng: -9.1383, time: now);

      final activity = await engine.stop(endedAt: now);
      final all = await repository.listAll();

      expect(activity, isNotNull);
      expect(activity!.activityType, ActivityType.run);
      expect(activity.trackPoints.length, 2);
      expect(activity.distanceMeters, greaterThan(0));
      expect(all, hasLength(1));

      await provider.dispose();
      engine.dispose();
    });

    test('Dauer wird mit festen Timestamps exakt berechnet', () async {
      final repository = InMemoryActivityRepository();
      final provider = _FakePositionProvider();
      final engine = TrackingSessionEngine(
        audioService: MockAudioFeedbackService(),
        repository: repository,
        positionStreamProvider: provider,
      );

      await engine.start(
        ActivityType.walk,
        startedAt: DateTime.utc(2026, 3, 9, 10, 0, 0),
      );
      final activity = await engine.stop(
        endedAt: DateTime.utc(2026, 3, 9, 10, 0, 42),
      );

      expect(activity, isNotNull);
      expect(activity!.durationSeconds, equals(42));

      await provider.dispose();
      engine.dispose();
    });

    test('noisy points unter min distance werden ignoriert', () async {
      final repository = InMemoryActivityRepository();
      final provider = _FakePositionProvider();
      final engine = TrackingSessionEngine(
        audioService: MockAudioFeedbackService(),
        repository: repository,
        positionStreamProvider: provider,
        minPointDistanceMeters: 10,
      );

      await engine.start(ActivityType.walk);
      final t = DateTime.utc(2026, 3, 9, 10, 0, 0);
      provider.emit(lat: 38.722300, lng: -9.139300, time: t);
      provider.emit(lat: 38.722301, lng: -9.139301, time: t);
      provider.emit(lat: 38.722600, lng: -9.139600, time: t);

      expect(engine.snapshot.trackPoints.length, 2);
      expect(engine.snapshot.distanceMeters, greaterThan(0));

      await provider.dispose();
      engine.dispose();
    });

    test('out-of-order timestamps werden ignoriert', () async {
      final repository = InMemoryActivityRepository();
      final provider = _FakePositionProvider();
      final engine = TrackingSessionEngine(
        audioService: MockAudioFeedbackService(),
        repository: repository,
        positionStreamProvider: provider,
      );

      await engine.start(
        ActivityType.run,
        startedAt: DateTime.utc(2026, 3, 9, 10, 0, 0),
      );
      provider.emit(
        lat: 38.7223,
        lng: -9.1393,
        time: DateTime.utc(2026, 3, 9, 10, 0, 10),
      );
      provider.emit(
        lat: 38.7233,
        lng: -9.1383,
        time: DateTime.utc(2026, 3, 9, 10, 0, 5),
      );

      expect(engine.snapshot.trackPoints.length, equals(1));

      await provider.dispose();
      engine.dispose();
    });

    test('stop mit 0/1 Punkten bleibt robust', () async {
      final repository = InMemoryActivityRepository();
      final provider = _FakePositionProvider();
      final engine = TrackingSessionEngine(
        audioService: MockAudioFeedbackService(),
        repository: repository,
        positionStreamProvider: provider,
      );

      await engine.start(ActivityType.ride);
      final activityNoPoints = await engine.stop();
      expect(activityNoPoints, isNotNull);
      expect(activityNoPoints!.trackPoints, isEmpty);
      expect(activityNoPoints.distanceMeters, equals(0));

      await engine.start(ActivityType.ride);
      provider.emit(
        lat: 38.7223,
        lng: -9.1393,
        time: DateTime.utc(2026, 3, 9, 10, 0, 0),
      );
      final activityOnePoint = await engine.stop();
      expect(activityOnePoint, isNotNull);
      expect(activityOnePoint!.trackPoints.length, 1);
      expect(activityOnePoint.distanceMeters, equals(0));

      await provider.dispose();
      engine.dispose();
    });

    test('duplicate points werden als sehr kurze Segmente ignoriert', () async {
      final repository = InMemoryActivityRepository();
      final provider = _FakePositionProvider();
      final engine = TrackingSessionEngine(
        audioService: MockAudioFeedbackService(),
        repository: repository,
        positionStreamProvider: provider,
      );

      await engine.start(
        ActivityType.ride,
        startedAt: DateTime.utc(2026, 3, 9, 10, 0, 0),
      );
      final t = DateTime.utc(2026, 3, 9, 10, 0, 10);
      provider.emit(lat: 38.7223, lng: -9.1393, time: t);
      provider.emit(lat: 38.7223, lng: -9.1393, time: t);

      expect(engine.snapshot.trackPoints.length, equals(1));
      expect(engine.snapshot.distanceMeters, equals(0));

      await provider.dispose();
      engine.dispose();
    });

    test('Elevation gain wird aus Hoehenprofil korrekt summiert', () async {
      final repository = InMemoryActivityRepository();
      final provider = _FakePositionProvider();
      final engine = TrackingSessionEngine(
        audioService: MockAudioFeedbackService(),
        repository: repository,
        positionStreamProvider: provider,
      );

      await engine.start(
        ActivityType.run,
        startedAt: DateTime.utc(2026, 3, 9, 10, 0, 0),
      );
      final t0 = DateTime.utc(2026, 3, 9, 10, 0, 0);
      provider.emit(lat: 38.7223, lng: -9.1393, time: t0, altitude: 100);
      provider.emit(
        lat: 38.7233,
        lng: -9.1383,
        time: t0.add(const Duration(seconds: 15)),
        altitude: 112,
      );
      provider.emit(
        lat: 38.7243,
        lng: -9.1373,
        time: t0.add(const Duration(seconds: 30)),
        altitude: 108,
      );
      provider.emit(
        lat: 38.7253,
        lng: -9.1363,
        time: t0.add(const Duration(seconds: 45)),
        altitude: 116,
      );

      final activity = await engine.stop(endedAt: t0.add(const Duration(minutes: 1)));
      expect(activity, isNotNull);
      expect(activity!.elevationGainMeters, closeTo(20, 0.001));
      expect(engine.snapshot.elevationGainMeters, closeTo(20, 0.001));

      await provider.dispose();
      engine.dispose();
    });
  });
}
