class TrackPoint {
  TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitudeMeters,
  }) {
    _validateLatitude(latitude);
    _validateLongitude(longitude);
    _validateAltitude(altitudeMeters);
  }

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitudeMeters;

  TrackPoint copyWith({
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    double? altitudeMeters,
    bool clearAltitude = false,
  }) {
    return TrackPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      altitudeMeters: clearAltitude
          ? null
          : (altitudeMeters ?? this.altitudeMeters),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'altitudeMeters': altitudeMeters,
    };
  }

  factory TrackPoint.fromJson(Map<String, dynamic> json) {
    return TrackPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble(),
    );
  }

  static void _validateLatitude(double value) {
    if (value < -90 || value > 90) {
      throw ArgumentError.value(value, 'latitude', 'Latitude out of bounds');
    }
  }

  static void _validateLongitude(double value) {
    if (value < -180 || value > 180) {
      throw ArgumentError.value(value, 'longitude', 'Longitude out of bounds');
    }
  }

  static void _validateAltitude(double? value) {
    if (value == null) return;
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        'altitudeMeters',
        'Altitude must be finite',
      );
    }
  }
}

enum ActivityType { run, ride, walk }

ActivityType activityTypeFromJson(String raw) {
  switch (raw) {
    case 'run':
      return ActivityType.run;
    case 'ride':
      return ActivityType.ride;
    case 'walk':
      return ActivityType.walk;
  }
  throw ArgumentError.value(raw, 'raw', 'Unsupported activity type');
}

String activityTypeToJson(ActivityType type) {
  switch (type) {
    case ActivityType.run:
      return 'run';
    case ActivityType.ride:
      return 'ride';
    case ActivityType.walk:
      return 'walk';
  }
}

class Activity {
  Activity({
    required this.id,
    required this.activityType,
    required this.startedAt,
    this.endedAt,
    this.name,
    this.uploaded = false,
    required this.distanceMeters,
    required List<TrackPoint> trackPoints,
  }) : trackPoints = List<TrackPoint>.unmodifiable(trackPoints) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Activity id cannot be empty');
    }
    if (distanceMeters < 0) {
      throw ArgumentError.value(
        distanceMeters,
        'distanceMeters',
        'Distance cannot be negative',
      );
    }
    if (endedAt != null && endedAt!.isBefore(startedAt)) {
      throw ArgumentError.value(
        endedAt,
        'endedAt',
        'endedAt cannot be before startedAt',
      );
    }
    if (name != null && name!.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Activity name cannot be blank');
    }
  }

  final String id;
  final ActivityType activityType;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? name;
  final bool uploaded;
  final double distanceMeters;
  final List<TrackPoint> trackPoints;

  int get durationSeconds {
    final end = endedAt;
    if (end == null) return 0;
    return end.difference(startedAt).inSeconds;
  }

  double? get averagePaceSecondsPerKm {
    if (distanceMeters <= 0 || durationSeconds <= 0) return null;
    final distanceKm = distanceMeters / 1000;
    if (distanceKm <= 0) return null;
    return durationSeconds / distanceKm;
  }

  double? get averageSpeedKmh {
    if (distanceMeters <= 0 || durationSeconds <= 0) return null;
    final metersPerSecond = distanceMeters / durationSeconds;
    if (!metersPerSecond.isFinite || metersPerSecond <= 0) return null;
    return metersPerSecond * 3.6;
  }

  double get elevationGainMeters {
    if (trackPoints.length < 2) return 0;
    var gain = 0.0;
    for (var i = 1; i < trackPoints.length; i++) {
      final previous = trackPoints[i - 1].altitudeMeters;
      final current = trackPoints[i].altitudeMeters;
      if (previous == null || current == null) continue;
      final delta = current - previous;
      if (delta > 0) {
        gain += delta;
      }
    }
    return gain;
  }

  double get elevationLossMeters {
    if (trackPoints.length < 2) return 0;
    var loss = 0.0;
    for (var i = 1; i < trackPoints.length; i++) {
      final previous = trackPoints[i - 1].altitudeMeters;
      final current = trackPoints[i].altitudeMeters;
      if (previous == null || current == null) continue;
      final delta = current - previous;
      if (delta < 0) {
        loss += -delta;
      }
    }
    return loss;
  }

  bool get isInProgress => endedAt == null;
  bool get isCompleted => endedAt != null;

  Activity copyWith({
    String? id,
    ActivityType? activityType,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    String? name,
    bool clearName = false,
    bool? uploaded,
    double? distanceMeters,
    List<TrackPoint>? trackPoints,
  }) {
    return Activity(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      name: clearName ? null : (name ?? this.name),
      uploaded: uploaded ?? this.uploaded,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      trackPoints: trackPoints ?? this.trackPoints,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityType': activityTypeToJson(activityType),
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'name': name,
      'uploaded': uploaded,
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'trackPoints': trackPoints.map((point) => point.toJson()).toList(),
    };
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    final points = (json['trackPoints'] as List<dynamic>? ?? [])
        .map((raw) => TrackPoint.fromJson(raw as Map<String, dynamic>))
        .toList();

    return Activity(
      id: json['id'] as String,
      activityType: activityTypeFromJson(json['activityType'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      name: json['name'] as String?,
      uploaded: json['uploaded'] as bool? ?? false,
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      trackPoints: points,
    );
  }
}
