import 'package:endurain/core/models/dynamic_map_zoom_preset.dart';
import 'package:endurain/features/map/controllers/dynamic_map_zoom_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DynamicMapZoomPolicy', () {
    test('maps speed tiers to expected zoom levels', () {
      final policy = DynamicMapZoomPolicy(
        minZoomChangeInterval: Duration.zero,
        minZoomDelta: 0,
        smoothingWindow: Duration.zero,
      );
      final now = DateTime.utc(2026, 3, 15, 10, 0, 0);

      final standing = policy.evaluate(
        speedKmh: 0.4,
        timestamp: now,
        currentZoom: 15,
        minZoom: 12,
        maxZoom: 19,
      );
      final walking = policy.evaluate(
        speedKmh: 3.0,
        timestamp: now.add(const Duration(seconds: 1)),
        currentZoom: standing ?? 15,
        minZoom: 12,
        maxZoom: 19,
      );
      final running = policy.evaluate(
        speedKmh: 8.0,
        timestamp: now.add(const Duration(seconds: 2)),
        currentZoom: walking ?? standing ?? 15,
        minZoom: 12,
        maxZoom: 19,
      );
      final cycling = policy.evaluate(
        speedKmh: 28.0,
        timestamp: now.add(const Duration(seconds: 3)),
        currentZoom: running ?? walking ?? standing ?? 15,
        minZoom: 12,
        maxZoom: 19,
      );

      expect(standing, 17.8);
      expect(walking, 17.0);
      expect(running, 16.2);
      expect(cycling, 14.4);
    });

    test('applies cooldown before next zoom change', () {
      final policy = DynamicMapZoomPolicy(
        minZoomChangeInterval: const Duration(seconds: 5),
        minZoomDelta: 0,
        smoothingWindow: Duration.zero,
      );
      final now = DateTime.utc(2026, 3, 15, 10, 0, 0);

      final first = policy.evaluate(
        speedKmh: 20,
        timestamp: now,
        currentZoom: 17,
        minZoom: 12,
        maxZoom: 19,
      );
      final blocked = policy.evaluate(
        speedKmh: 30,
        timestamp: now.add(const Duration(seconds: 2)),
        currentZoom: first ?? 17,
        minZoom: 12,
        maxZoom: 19,
      );
      final allowed = policy.evaluate(
        speedKmh: 30,
        timestamp: now.add(const Duration(seconds: 6)),
        currentZoom: first ?? 17,
        minZoom: 12,
        maxZoom: 19,
      );

      expect(first, 15.2);
      expect(blocked, isNull);
      expect(allowed, 14.4);
    });

    test('uses hysteresis to avoid boundary jitter', () {
      final policy = DynamicMapZoomPolicy(
        minZoomChangeInterval: Duration.zero,
        minZoomDelta: 0,
        hysteresisKmh: 0.8,
        smoothingWindow: Duration.zero,
      );
      final now = DateTime.utc(2026, 3, 15, 10, 0, 0);

      final base = policy.evaluate(
        speedKmh: 4.8,
        timestamp: now,
        currentZoom: 15,
        minZoom: 12,
        maxZoom: 19,
      );
      final nearBoundary = policy.evaluate(
        speedKmh: 5.2,
        timestamp: now.add(const Duration(seconds: 1)),
        currentZoom: base ?? 15,
        minZoom: 12,
        maxZoom: 19,
      );
      final aboveHysteresis = policy.evaluate(
        speedKmh: 5.9,
        timestamp: now.add(const Duration(seconds: 2)),
        currentZoom: nearBoundary ?? base ?? 15,
        minZoom: 12,
        maxZoom: 19,
      );

      expect(base, 17.0);
      expect(nearBoundary, isNull);
      expect(aboveHysteresis, 16.2);
    });

    test('ignores tiny zoom deltas under threshold', () {
      final policy = DynamicMapZoomPolicy(
        minZoomChangeInterval: Duration.zero,
        minZoomDelta: 0.35,
      );
      final now = DateTime.utc(2026, 3, 15, 10, 0, 0);

      final noChange = policy.evaluate(
        speedKmh: 0.1,
        timestamp: now,
        currentZoom: 17.7,
        minZoom: 12,
        maxZoom: 19,
      );

      expect(noChange, isNull);
    });

    test('uses conservative preset with less zoom-out at high speed', () {
      final policy = DynamicMapZoomPolicy(
        preset: DynamicMapZoomPreset.conservative,
        minZoomChangeInterval: Duration.zero,
        minZoomDelta: 0,
        smoothingWindow: Duration.zero,
      );
      final now = DateTime.utc(2026, 3, 15, 10, 0, 0);

      final highSpeedZoom = policy.evaluate(
        speedKmh: 30,
        timestamp: now,
        currentZoom: 17,
        minZoom: 12,
        maxZoom: 19,
      );

      expect(highSpeedZoom, 15.0);
    });

    test('uses aggressive preset with more zoom-out at high speed', () {
      final policy = DynamicMapZoomPolicy(
        preset: DynamicMapZoomPreset.aggressive,
        minZoomChangeInterval: Duration.zero,
        minZoomDelta: 0,
        smoothingWindow: Duration.zero,
      );
      final now = DateTime.utc(2026, 3, 15, 10, 0, 0);

      final highSpeedZoom = policy.evaluate(
        speedKmh: 30,
        timestamp: now,
        currentZoom: 17,
        minZoom: 12,
        maxZoom: 19,
      );

      expect(highSpeedZoom, 13.8);
    });
  });
}
