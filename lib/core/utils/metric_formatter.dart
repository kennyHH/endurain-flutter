import 'package:endurain/core/models/activity.dart';

class MetricFormatter {
  const MetricFormatter._();

  static String formatDistanceKm(double distanceMeters, String unitKm) {
    final km = distanceMeters / 1000;
    return '${km.toStringAsFixed(2)} $unitKm';
  }

  static String formatDurationClock(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      final h = hours.toString().padLeft(2, '0');
      return '$h:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  static String formatDurationLabeled(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  static String formatPace(double? paceSecondsPerKm, String paceUnit) {
    if (paceSecondsPerKm == null ||
        !paceSecondsPerKm.isFinite ||
        paceSecondsPerKm <= 0) {
      return '-';
    }
    final seconds = paceSecondsPerKm.round();
    final minutesPart = (seconds ~/ 60).toString().padLeft(2, '0');
    final secondsPart = (seconds % 60).toString().padLeft(2, '0');
    return '$minutesPart:$secondsPart $paceUnit';
  }

  static String formatSpeedKmh(double? speedKmh, String speedUnit) {
    if (speedKmh == null || !speedKmh.isFinite || speedKmh <= 0) {
      return '-';
    }
    return '${speedKmh.toStringAsFixed(1)} $speedUnit';
  }

  static String formatMovement({
    required ActivityType activityType,
    required double distanceMeters,
    required int durationSeconds,
    required String paceUnit,
    required String speedUnit,
  }) {
    if (distanceMeters <= 0 || durationSeconds <= 0) return '-';
    if (activityType == ActivityType.ride) {
      final speedKmh = (distanceMeters / durationSeconds) * 3.6;
      return formatSpeedKmh(speedKmh, speedUnit);
    }
    final paceSecondsPerKm = durationSeconds / (distanceMeters / 1000);
    return formatPace(paceSecondsPerKm, paceUnit);
  }
}
