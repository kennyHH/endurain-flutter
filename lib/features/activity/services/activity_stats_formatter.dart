class ActivityStatsFormatter {
  const ActivityStatsFormatter();

  String formatDuration(int seconds) {
    final clampedSeconds = seconds < 0 ? 0 : seconds;
    final hours = clampedSeconds ~/ Duration.secondsPerHour;
    final minutes =
        (clampedSeconds % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
    final remainingSeconds = clampedSeconds % Duration.secondsPerMinute;

    if (hours > 0) {
      return '$hours:${_twoDigits(minutes)}:${_twoDigits(remainingSeconds)}';
    }
    return '$minutes:${_twoDigits(remainingSeconds)}';
  }

  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String formatSpeed(double? metersPerSecond) {
    if (metersPerSecond == null) {
      return '-';
    }
    return '${(metersPerSecond * 3.6).toStringAsFixed(1)} km/h';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}
