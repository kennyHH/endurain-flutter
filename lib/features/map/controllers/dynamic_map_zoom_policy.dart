import 'package:endurain/core/models/dynamic_map_zoom_preset.dart';

class DynamicZoomTier {
  const DynamicZoomTier({required this.minSpeedKmh, required this.zoom});

  final double minSpeedKmh;
  final double zoom;
}

class DynamicMapZoomPolicy {
  DynamicMapZoomPolicy({
    this.smoothingWindow = const Duration(seconds: 5),
    this.minZoomChangeInterval = const Duration(seconds: 5),
    this.minZoomDelta = 0.35,
    this.hysteresisKmh = 0.8,
    this.preset = DynamicMapZoomPreset.balanced,
    List<DynamicZoomTier>? customTiers,
  }) : tiers =
           customTiers ??
           tiersForPreset(preset);

  final Duration smoothingWindow;
  final Duration minZoomChangeInterval;
  final double minZoomDelta;
  final double hysteresisKmh;
  final DynamicMapZoomPreset preset;
  final List<DynamicZoomTier> tiers;

  static List<DynamicZoomTier> tiersForPreset(DynamicMapZoomPreset preset) {
    return switch (preset) {
      DynamicMapZoomPreset.conservative => const [
        DynamicZoomTier(minSpeedKmh: 0, zoom: 17.5),
        DynamicZoomTier(minSpeedKmh: 1, zoom: 16.9),
        DynamicZoomTier(minSpeedKmh: 5, zoom: 16.3),
        DynamicZoomTier(minSpeedKmh: 12, zoom: 15.6),
        DynamicZoomTier(minSpeedKmh: 25, zoom: 15.0),
      ],
      DynamicMapZoomPreset.balanced => const [
        DynamicZoomTier(minSpeedKmh: 0, zoom: 17.8),
        DynamicZoomTier(minSpeedKmh: 1, zoom: 17.0),
        DynamicZoomTier(minSpeedKmh: 5, zoom: 16.2),
        DynamicZoomTier(minSpeedKmh: 12, zoom: 15.2),
        DynamicZoomTier(minSpeedKmh: 25, zoom: 14.4),
      ],
      DynamicMapZoomPreset.aggressive => const [
        DynamicZoomTier(minSpeedKmh: 0, zoom: 18.0),
        DynamicZoomTier(minSpeedKmh: 1, zoom: 17.1),
        DynamicZoomTier(minSpeedKmh: 5, zoom: 16.0),
        DynamicZoomTier(minSpeedKmh: 12, zoom: 14.9),
        DynamicZoomTier(minSpeedKmh: 25, zoom: 13.8),
      ],
    };
  }

  final List<_SpeedSample> _samples = <_SpeedSample>[];
  int? _activeTierIndex;
  DateTime? _lastAppliedAt;

  void reset() {
    _samples.clear();
    _activeTierIndex = null;
    _lastAppliedAt = null;
  }

  double? evaluate({
    required double speedKmh,
    required DateTime timestamp,
    required double currentZoom,
    required double minZoom,
    required double maxZoom,
  }) {
    final normalizedSpeed = _normalizeSpeed(speedKmh);
    _samples.add(_SpeedSample(timestamp: timestamp, speedKmh: normalizedSpeed));
    _trimSamples(timestamp);
    final smoothedSpeed = _smoothedSpeed();
    final tierIndex = _resolveTierIndex(smoothedSpeed);
    _activeTierIndex = tierIndex;

    final targetZoom = tiers[tierIndex].zoom.clamp(minZoom, maxZoom).toDouble();
    final requiredDelta = minZoomDelta <= 0 ? 0.0001 : minZoomDelta;
    final hasMeaningfulDelta =
        (targetZoom - currentZoom).abs() >= requiredDelta;

    if (!hasMeaningfulDelta) {
      return null;
    }

    if (_lastAppliedAt != null &&
        timestamp.difference(_lastAppliedAt!) < minZoomChangeInterval) {
      return null;
    }

    _lastAppliedAt = timestamp;
    return targetZoom;
  }

  double _normalizeSpeed(double speedKmh) {
    if (!speedKmh.isFinite) return 0;
    if (speedKmh < 0) return 0;
    return speedKmh;
  }

  void _trimSamples(DateTime now) {
    final cutoff = now.subtract(smoothingWindow);
    _samples.removeWhere((sample) => sample.timestamp.isBefore(cutoff));
  }

  double _smoothedSpeed() {
    if (_samples.isEmpty) return 0;
    final sum = _samples.fold<double>(
      0,
      (acc, sample) => acc + sample.speedKmh,
    );
    return sum / _samples.length;
  }

  int _resolveTierIndex(double speedKmh) {
    if (tiers.isEmpty) return 0;
    final currentIndex = _activeTierIndex ?? _baseTierIndex(speedKmh);
    final lowerBound = tiers[currentIndex].minSpeedKmh;
    final upperBound = currentIndex == tiers.length - 1
        ? double.infinity
        : tiers[currentIndex + 1].minSpeedKmh;

    if (speedKmh < lowerBound - hysteresisKmh) {
      return _baseTierIndex(speedKmh);
    }
    if (speedKmh >= upperBound + hysteresisKmh) {
      return _baseTierIndex(speedKmh);
    }
    return currentIndex;
  }

  int _baseTierIndex(double speedKmh) {
    var index = 0;
    for (var i = 0; i < tiers.length; i++) {
      if (speedKmh >= tiers[i].minSpeedKmh) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }
}

class _SpeedSample {
  const _SpeedSample({required this.timestamp, required this.speedKmh});

  final DateTime timestamp;
  final double speedKmh;
}
