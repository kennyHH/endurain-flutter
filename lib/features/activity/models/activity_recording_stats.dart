class ActivityRecordingStats {
  const ActivityRecordingStats({
    required this.distanceMeters,
    required this.durationSeconds,
    this.averageSpeedMetersPerSecond,
    this.currentSpeedMetersPerSecond,
  });

  final double distanceMeters;
  final int durationSeconds;
  final double? averageSpeedMetersPerSecond;
  final double? currentSpeedMetersPerSecond;
}