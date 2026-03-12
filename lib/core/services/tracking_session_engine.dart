import 'dart:async';
import 'dart:math' as math;

import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/models/gps_filter_mode.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/audio_feedback_service.dart';

enum TrackingSessionState { idle, recording, paused, stopped }

class PositionSample {
  const PositionSample({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitudeMeters,
    this.horizontalAccuracyMeters,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitudeMeters;
  final double? horizontalAccuracyMeters;
}

abstract class PositionStreamProvider {
  Stream<PositionSample> getPositionStream();
}

class LocationServicePositionStreamProvider implements PositionStreamProvider {
  const LocationServicePositionStreamProvider(this._locationService);

  final LocationService _locationService;

  @override
  Stream<PositionSample> getPositionStream() {
    return _locationService.getPositionStream().map(
      (position) => PositionSample(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
        altitudeMeters: position.altitude,
        horizontalAccuracyMeters: position.accuracy,
      ),
    );
  }
}

class TrackingSessionSnapshot {
  const TrackingSessionSnapshot({
    required this.state,
    required this.duration,
    required this.distanceMeters,
    required this.elevationGainMeters,
    required this.trackPoints,
    this.activityType,
    this.startTime,
    this.finalActivity,
  });

  const TrackingSessionSnapshot.idle()
    : state = TrackingSessionState.idle,
      activityType = null,
      startTime = null,
      duration = Duration.zero,
      distanceMeters = 0,
      elevationGainMeters = 0,
      trackPoints = const <TrackPoint>[],
      finalActivity = null;

  final TrackingSessionState state;
  final ActivityType? activityType;
  final DateTime? startTime;
  final Duration duration;
  final double distanceMeters;
  final double elevationGainMeters;
  final List<TrackPoint> trackPoints;
  final Activity? finalActivity;

  TrackingSessionSnapshot copyWith({
    TrackingSessionState? state,
    ActivityType? activityType,
    DateTime? startTime,
    Duration? duration,
    double? distanceMeters,
    double? elevationGainMeters,
    List<TrackPoint>? trackPoints,
    Activity? finalActivity,
  }) {
    return TrackingSessionSnapshot(
      state: state ?? this.state,
      activityType: activityType ?? this.activityType,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
      trackPoints: trackPoints ?? this.trackPoints,
      finalActivity: finalActivity ?? this.finalActivity,
    );
  }
}

class TrackingSessionEngine {
  TrackingSessionEngine({
    required ActivityRepository repository,
    required PositionStreamProvider positionStreamProvider,
    DateTime Function()? nowProvider,
    this.minPointDistanceMeters = 3,
    this.maxAcceptedAccuracyMeters = 28,
    this.maxSegmentSpeedMetersPerSecond = 45,
    this.maxAcceptedAccuracyWalkRunMeters = 22,
    this.maxAcceptedAccuracyRideMeters = 28,
    this.maxWalkSpeedMetersPerSecond = 8.0,
    this.maxRunSpeedMetersPerSecond = 16.0,
    this.maxRideSpeedMetersPerSecond = 22.0,
    GpsFilterMode gpsFilterMode = GpsFilterMode.auto,
    AudioFeedbackService? audioService,
  }) : _repository = repository,
       _positionStreamProvider = positionStreamProvider,
       _nowProvider = nowProvider ?? DateTime.now,
       _gpsFilterMode = gpsFilterMode,
       _audio = audioService ?? AudioFeedbackService();

  final ActivityRepository _repository;
  final PositionStreamProvider _positionStreamProvider;
  final DateTime Function() _nowProvider;
  final double minPointDistanceMeters;
  final double maxAcceptedAccuracyMeters;
  final double maxSegmentSpeedMetersPerSecond;
  final double maxAcceptedAccuracyWalkRunMeters;
  final double maxAcceptedAccuracyRideMeters;
  final double maxWalkSpeedMetersPerSecond;
  final double maxRunSpeedMetersPerSecond;
  final double maxRideSpeedMetersPerSecond;
    GpsFilterMode _gpsFilterMode;
  
  // Audio & Splits
  final AudioFeedbackService _audio;
  int _lastSplitKm = 0;
  DateTime? _lastSplitTime;
  
  // GPS Watchdog
  Timer? _gpsWatchdogTimer;
  bool _isGpsSignalLost = false;
  DateTime? _lastGpsAnnouncementTime;
  static const Duration _gpsDebounce = Duration(seconds: 60);


  final StreamController<TrackingSessionSnapshot> _streamController =
      StreamController<TrackingSessionSnapshot>.broadcast();

  TrackingSessionSnapshot _snapshot = const TrackingSessionSnapshot.idle();
  StreamSubscription<PositionSample>? _positionSubscription;
  Timer? _durationTicker;
  Timer? _positionReconnectTimer;

  TrackingSessionState get currentSessionState => _snapshot.state;
  TrackingSessionSnapshot get snapshot => _snapshot;
  Stream<TrackingSessionSnapshot> get stream => _streamController.stream;

  void setGpsFilterMode(GpsFilterMode mode) {
    _gpsFilterMode = mode;
  }

  Future<bool> start(ActivityType activityType, {DateTime? startedAt, bool useCountdown = false}) async {
    if (_snapshot.state == TrackingSessionState.recording) {
      return false;
    }
    
    if (useCountdown) {
      // 6, 5, 4, 3, 2, 1
      for (var i = 6; i > 0; i--) {
        await _audio.announceCountdown(i);
        await Future.delayed(const Duration(seconds: 1));
      }
      await _audio.announceStart(); // "Go!"
    } else {
      // Just announce start if no countdown
      await _audio.announceStart();
    }

    await _positionSubscription?.cancel();
    final startTime = startedAt ?? _nowProvider();
    _snapshot = TrackingSessionSnapshot(
      state: TrackingSessionState.recording,
      activityType: activityType,
      startTime: startTime,
      duration: Duration.zero,
      distanceMeters: 0,
      elevationGainMeters: 0,
      trackPoints: const <TrackPoint>[],
    );
    
    // Reset state
    _lastSplitKm = 0;
    _lastSplitTime = startTime;
    _isGpsSignalLost = false;
    _lastGpsAnnouncementTime = null;
    
    _emitSnapshot();
    _startDurationTicker();

    _subscribeToPositionStream();
    _startGpsWatchdog();
    
    return true;
  }

  Future<void> pause() async {
    if (_snapshot.state != TrackingSessionState.recording) return;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _durationTicker?.cancel();
    _gpsWatchdogTimer?.cancel();
    _durationTicker = null;
    _positionReconnectTimer?.cancel();
    _positionReconnectTimer = null;
    _snapshot = _snapshot.copyWith(state: TrackingSessionState.paused);
    _emitSnapshot();
  }

  Future<void> resume() async {
    if (_snapshot.state != TrackingSessionState.paused) return;
    _snapshot = _snapshot.copyWith(state: TrackingSessionState.recording);
    _emitSnapshot();
    _startDurationTicker();
    _subscribeToPositionStream();
  }

  Future<Activity?> stop({DateTime? endedAt}) async {
    if (_snapshot.state != TrackingSessionState.recording &&
        _snapshot.state != TrackingSessionState.paused) {
      return null;
    }
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _durationTicker?.cancel();
    _gpsWatchdogTimer?.cancel();
    _durationTicker = null;
    _positionReconnectTimer?.cancel();
    _positionReconnectTimer = null;

    final startTime = _snapshot.startTime;
    final activityType = _snapshot.activityType;
    if (startTime == null || activityType == null) {
      _snapshot = const TrackingSessionSnapshot.idle();
      _emitSnapshot();
      return null;
    }

    final candidateEnd = endedAt ?? _nowProvider();
    final endTime = candidateEnd.isBefore(startTime) ? startTime : candidateEnd;
    final activity = Activity(
      id: endTime.microsecondsSinceEpoch.toString(),
      activityType: activityType,
      startedAt: startTime,
      endedAt: endTime,
      distanceMeters: _snapshot.distanceMeters,
      trackPoints: List<TrackPoint>.from(_snapshot.trackPoints),
    );
    await _repository.create(activity);

    _snapshot = TrackingSessionSnapshot(
      state: TrackingSessionState.stopped,
      activityType: activityType,
      startTime: startTime,
      duration: Duration(seconds: activity.durationSeconds),
      distanceMeters: activity.distanceMeters,
      elevationGainMeters: activity.elevationGainMeters,
      trackPoints: activity.trackPoints,
      finalActivity: activity,
    );
    _emitSnapshot();
    return activity;
  }

  Future<void> reset() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _durationTicker?.cancel();
    _gpsWatchdogTimer?.cancel();
    _durationTicker = null;
    _positionReconnectTimer?.cancel();
    _positionReconnectTimer = null;
    _snapshot = const TrackingSessionSnapshot.idle();
    _emitSnapshot();
  }

  Future<void> deleteSavedActivity(String id) async {
    await _repository.delete(id);
  }

    void _startGpsWatchdog() {
    _gpsWatchdogTimer?.cancel();
    _gpsWatchdogTimer = Timer(const Duration(seconds: 10), _onGpsSignalLost);
  }
  
  void _onGpsSignalLost() {
    if (_snapshot.state != TrackingSessionState.recording) return;
    if (!_isGpsSignalLost) {
      _isGpsSignalLost = true;
      _announceGpsStatus(true);
    }
  }
  
  void _onGpsSignalRecovered() {
    if (_isGpsSignalLost) {
      _isGpsSignalLost = false;
      _announceGpsStatus(false);
    }
    _startGpsWatchdog();
  }
  
  void _announceGpsStatus(bool isLost) {
    final now = _nowProvider();
    if (_lastGpsAnnouncementTime == null || 
        now.difference(_lastGpsAnnouncementTime!) > _gpsDebounce) {
      _audio.announceGpsStatus(isLost: isLost);
      _lastGpsAnnouncementTime = now;
    }
  }
void dispose() {
    _positionSubscription?.cancel();
    _positionReconnectTimer?.cancel();
    _durationTicker?.cancel();
    _gpsWatchdogTimer?.cancel();
    _streamController.close();
  }

  void _subscribeToPositionStream() {
    _positionSubscription?.cancel();
    _positionSubscription = _positionStreamProvider.getPositionStream().listen(
      _onPosition,
      onError: _handlePositionStreamInterruption,
      onDone: _handlePositionStreamInterruption,
      cancelOnError: true,
    );
  }

  void _handlePositionStreamInterruption([Object? _]) {
    if (_snapshot.state != TrackingSessionState.recording) {
      return;
    }
    _positionReconnectTimer?.cancel();
    _positionReconnectTimer = Timer(const Duration(seconds: 2), () {
      if (_snapshot.state != TrackingSessionState.recording) {
        return;
      }
      _subscribeToPositionStream();
    });
  }

  void _onPosition(PositionSample sample) {
    // Reset watchdog on any update (even if low accuracy, at least we have signal)
    // But if accuracy is terrible, maybe we still consider it lost?
    // Let's assume ANY update means we have signal, but maybe poor quality.
    // User said "accuracy drops or signal is gone".
    
    final accuracy = sample.horizontalAccuracyMeters;
    
    // Check signal quality
    if (accuracy != null && accuracy > 50) { // Threshold for "Lost" signal quality
       _onGpsSignalLost();
    } else {
       _onGpsSignalRecovered();
    }

    final maxAcceptedAccuracy = _maxAccuracyForCurrentActivity();
    if (accuracy != null &&
        accuracy.isFinite &&
        accuracy > maxAcceptedAccuracy) {
      return;
    }
    final accepted = addPoint(
      TrackPoint(
        latitude: sample.latitude,
        longitude: sample.longitude,
        timestamp: sample.timestamp,
        altitudeMeters: sample.altitudeMeters,
      ),
    );
    if (!accepted) {
      return;
    }
    
    // Check splits
    _checkSplit();
  }

    void _checkSplit() {
    final currentKm = (_snapshot.distanceMeters / 1000).floor();
    if (currentKm > _lastSplitKm) {
      final now = _nowProvider();
      final lastTime = _lastSplitTime ?? _snapshot.startTime!;
      
      // Calculate pace for this specific kilometer (or segment)
      // Duration since last split
      final durationSinceLast = now.difference(lastTime);
      final seconds = durationSinceLast.inSeconds;
      
      // Distance covered: usually exactly 1km if we check often enough, 
      // but might be slightly more.
      // Pace = seconds / km.
      // If we crossed 1km boundary, we assume we covered 1km since last split?
      // Not exactly if we missed updates.
      // But good enough approximation: "Last Split Pace".
      
      // Better: Pace of the *current* km?
      // If currentKm = 1, _lastSplitKm = 0.
      // We covered 1km. Duration is `seconds`.
      // Pace = seconds per km.
      
      final pace = seconds.toDouble(); // seconds for 1 km
      
      _audio.announceSplit(km: currentKm, paceSecondsPerKm: pace);
      
      _lastSplitKm = currentKm;
      _lastSplitTime = now;
    }
  }
bool addPoint(TrackPoint point) {
    if (_snapshot.state != TrackingSessionState.recording ||
        _snapshot.startTime == null) {
      return false;
    }
    final nextPoints = List<TrackPoint>.from(_snapshot.trackPoints);
    var nextDistance = _snapshot.distanceMeters;

    if (nextPoints.isNotEmpty) {
      final last = nextPoints.last;
      if (point.timestamp.isBefore(last.timestamp)) {
        return false;
      }
      final delta = calculateDistanceMeters(last, point);
      if (delta < minPointDistanceMeters) {
        return false;
      }
      final elapsedSeconds = point.timestamp
          .difference(last.timestamp)
          .inMilliseconds /
          1000;
      if (elapsedSeconds > 0) {
        final segmentSpeed = delta / elapsedSeconds;
        if (segmentSpeed > _maxSpeedForCurrentActivity()) {
          return false;
        }
      }
      nextDistance += delta;
    }

    final startTime = _snapshot.startTime!;
    final duration = point.timestamp.isAfter(startTime)
        ? point.timestamp.difference(startTime)
        : Duration.zero;
    nextPoints.add(point);
    _snapshot = _snapshot.copyWith(
      duration: duration,
      distanceMeters: nextDistance,
      elevationGainMeters: calculateElevationGainMeters(nextPoints),
      trackPoints: nextPoints,
    );
    _emitSnapshot();
    return true;
  }

  void _emitSnapshot() {
    if (!_streamController.isClosed) {
      _streamController.add(_snapshot);
    }
  }

  void _startDurationTicker() {
    _durationTicker?.cancel();
    // Do not cancel watchdog here!
    _durationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_snapshot.state != TrackingSessionState.recording ||
          _snapshot.startTime == null) {
        return;
      }
      final now = _nowProvider();
      final startTime = _snapshot.startTime!;
      final duration = now.isAfter(startTime)
          ? now.difference(startTime)
          : Duration.zero;
      _snapshot = _snapshot.copyWith(duration: duration);
      _emitSnapshot();
    });
  }

  static double calculateDistanceMeters(TrackPoint from, TrackPoint to) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _degreesToRadians(from.latitude);
    final lat2 = _degreesToRadians(to.latitude);
    final deltaLat = _degreesToRadians(to.latitude - from.latitude);
    final deltaLng = _degreesToRadians(to.longitude - from.longitude);

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double calculateElevationGainMeters(List<TrackPoint> points) {
    if (points.length < 2) return 0;
    var gain = 0.0;
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1].altitudeMeters;
      final current = points[i].altitudeMeters;
      if (previous == null || current == null) continue;
      final delta = current - previous;
      if (delta > 0) {
        gain += delta;
      }
    }
    return gain;
  }

  static double _degreesToRadians(double degrees) => degrees * (math.pi / 180);

  double _maxAccuracyForCurrentActivity() {
    if (_gpsFilterMode == GpsFilterMode.normal) {
      return maxAcceptedAccuracyMeters;
    }
    if (_gpsFilterMode == GpsFilterMode.strict) {
      final activityType = _snapshot.activityType;
      if (activityType == ActivityType.ride) return 22;
      return 18;
    }
    final activityType = _snapshot.activityType;
    if (activityType == ActivityType.ride) return maxAcceptedAccuracyRideMeters;
    if (activityType == ActivityType.run || activityType == ActivityType.walk) {
      return maxAcceptedAccuracyWalkRunMeters;
    }
    return maxAcceptedAccuracyMeters;
  }

  double _maxSpeedForCurrentActivity() {
    if (_gpsFilterMode == GpsFilterMode.normal) {
      return maxSegmentSpeedMetersPerSecond;
    }
    if (_gpsFilterMode == GpsFilterMode.strict) {
      final activityType = _snapshot.activityType;
      switch (activityType) {
        case ActivityType.walk:
          return 6.0;
        case ActivityType.run:
          return 12.0;
        case ActivityType.ride:
          return 18.0;
        case null:
          return 18.0;
      }
    }
    final activityType = _snapshot.activityType;
    switch (activityType) {
      case ActivityType.walk:
        return maxWalkSpeedMetersPerSecond;
      case ActivityType.run:
        return maxRunSpeedMetersPerSecond;
      case ActivityType.ride:
        return maxRideSpeedMetersPerSecond;
      case null:
        return maxSegmentSpeedMetersPerSecond;
    }
  }
}
