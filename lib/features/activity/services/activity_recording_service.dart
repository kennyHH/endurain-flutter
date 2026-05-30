import 'dart:async';

import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_track_point.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;

class ActivityRecordingErrorKeys {
  const ActivityRecordingErrorKeys._();

  static const String invalidTransition = 'activityRecordingInvalidTransition';
  static const String locationStreamFailed = 'activityLocationStreamFailed';
  static const String emptyRecording = 'activityRecordingEmpty';
  static const String locationServiceDisabled =
      'activityLocationServiceDisabled';
  static const String locationPermissionDenied =
      'activityLocationPermissionDenied';
  static const String locationPermissionDeniedForever =
      'activityLocationPermissionDeniedForever';
}

class ActivityRecordingService {
  ActivityRecordingService({
    DateTime Function()? now,
    LocationService? locationService,
  }) : _now = now ?? DateTime.now,
       _locationService = locationService ?? LocationService();

  final DateTime Function() _now;
  final LocationService _locationService;
  final StreamController<ActivityRecordingState> _stateController =
      StreamController<ActivityRecordingState>.broadcast();

  ActivityRecordingState _state = ActivityRecordingState();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _elapsedTimer;
  DateTime? _recordingSegmentStartedAt;
  int _elapsedBeforeCurrentSegmentSeconds = 0;
  bool _isDisposed = false;

  ActivityRecordingState get state => _state;

  Stream<ActivityRecordingState> get stateStream => _stateController.stream;

  Future<void> start({required ActivityType activityType}) async {
    _ensureNotDisposed();
    if (_state.isActive || _state.status == ActivityRecordingStatus.stopping) {
      return;
    }

    final locationErrorKey = await _locationErrorKey();
    if (locationErrorKey != null) {
      _emit(
        ActivityRecordingState(
          status: ActivityRecordingStatus.failed,
          activityType: activityType,
          lastErrorKey: locationErrorKey,
        ),
      );
      return;
    }

    final startedAt = _now();
    _recordingSegmentStartedAt = startedAt;
    _elapsedBeforeCurrentSegmentSeconds = 0;
    _emit(
      ActivityRecordingState(
        status: ActivityRecordingStatus.recording,
        activityType: activityType,
        startedAt: startedAt,
      ),
    );
    _startElapsedTimer();
    _startLocationStream();
  }

  Future<bool> openAppSettings() {
    return _locationService.openAppSettings();
  }

  Future<void> pause() async {
    _ensureNotDisposed();
    if (_state.status == ActivityRecordingStatus.paused) {
      return;
    }
    if (_state.status != ActivityRecordingStatus.recording) {
      _failInvalidTransition();
      return;
    }

    final elapsedDurationSeconds = _currentElapsedDurationSeconds();
    _elapsedBeforeCurrentSegmentSeconds = elapsedDurationSeconds;
    _recordingSegmentStartedAt = null;
    _cancelElapsedTimer();
    final cancelPositionSubscription = _cancelPositionSubscription();
    _emit(
      _state.copyWith(
        status: ActivityRecordingStatus.paused,
        elapsedDurationSeconds: elapsedDurationSeconds,
      ),
    );
    await cancelPositionSubscription;
  }

  Future<void> resume() async {
    _ensureNotDisposed();
    if (_state.status == ActivityRecordingStatus.recording) {
      return;
    }
    if (_state.status != ActivityRecordingStatus.paused) {
      _failInvalidTransition();
      return;
    }

    _recordingSegmentStartedAt = _now();
    _emit(_state.copyWith(status: ActivityRecordingStatus.recording));
    _startElapsedTimer();
    _startLocationStream();
  }

  Future<void> stop() async {
    _ensureNotDisposed();
    if (!_state.isActive) {
      return;
    }

    final elapsedDurationSeconds = _currentElapsedDurationSeconds();
    _elapsedBeforeCurrentSegmentSeconds = elapsedDurationSeconds;
    _recordingSegmentStartedAt = null;
    _cancelElapsedTimer();
    await _cancelPositionSubscription();
    if (_state.points.isEmpty) {
      _emit(
        _state.copyWith(
          status: ActivityRecordingStatus.failed,
          endedAt: _now(),
          lastErrorKey: ActivityRecordingErrorKeys.emptyRecording,
          elapsedDurationSeconds: elapsedDurationSeconds,
        ),
      );
      return;
    }

    _emit(
      _state.copyWith(
        status: ActivityRecordingStatus.stopping,
        elapsedDurationSeconds: elapsedDurationSeconds,
      ),
    );
    _emit(
      _state.copyWith(
        status: ActivityRecordingStatus.completed,
        endedAt: _now(),
      ),
    );
  }

  Future<void> discard() async {
    _ensureNotDisposed();
    _cancelElapsedTimer();
    _recordingSegmentStartedAt = null;
    _elapsedBeforeCurrentSegmentSeconds = 0;
    await _cancelPositionSubscription();
    _emit(ActivityRecordingState());
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _cancelElapsedTimer();
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _stateController.close();
  }

  void _startElapsedTimer() {
    _cancelElapsedTimer();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.status != ActivityRecordingStatus.recording) {
        return;
      }
      final elapsedDurationSeconds = _currentElapsedDurationSeconds();
      if (elapsedDurationSeconds == _state.elapsedDurationSeconds) {
        return;
      }
      _emit(_state.copyWith(elapsedDurationSeconds: elapsedDurationSeconds));
    });
  }

  void _cancelElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  int _currentElapsedDurationSeconds() {
    final segmentStartedAt = _recordingSegmentStartedAt;
    if (segmentStartedAt == null) {
      return _elapsedBeforeCurrentSegmentSeconds;
    }
    final segmentSeconds = _now().difference(segmentStartedAt).inSeconds;
    return _elapsedBeforeCurrentSegmentSeconds +
        (segmentSeconds < 0 ? 0 : segmentSeconds);
  }

  void _startLocationStream() {
    if (_positionSubscription != null) {
      return;
    }

    try {
      _positionSubscription = _locationService.getPositionStream().listen(
        _recordPosition,
        onError: _handlePositionError,
      );
    } catch (_) {
      _fail(ActivityRecordingErrorKeys.locationStreamFailed);
    }
  }

  Future<void> _cancelPositionSubscription() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
  }

  void _recordPosition(Position position) {
    if (_state.status != ActivityRecordingStatus.recording) {
      return;
    }
    _emit(_state.addPoint(ActivityTrackPoint.fromPosition(position)));
  }

  void _handlePositionError(Object error, StackTrace stackTrace) {
    _fail(ActivityRecordingErrorKeys.locationStreamFailed);
  }

  Future<String?> _locationErrorKey() async {
    if (!await _locationService.isLocationServiceEnabled()) {
      return ActivityRecordingErrorKeys.locationServiceDisabled;
    }

    var permission = await _locationService.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _locationService.requestPermission();
    }

    return switch (permission) {
      LocationPermission.always || LocationPermission.whileInUse => null,
      LocationPermission.denied =>
        ActivityRecordingErrorKeys.locationPermissionDenied,
      LocationPermission.deniedForever =>
        ActivityRecordingErrorKeys.locationPermissionDeniedForever,
      LocationPermission.unableToDetermine =>
        ActivityRecordingErrorKeys.locationPermissionDenied,
    };
  }

  void _failInvalidTransition() {
    _fail(ActivityRecordingErrorKeys.invalidTransition);
  }

  void _fail(String errorKey) {
    _cancelElapsedTimer();
    _recordingSegmentStartedAt = null;
    unawaited(_cancelPositionSubscription());
    _emit(
      _state.copyWith(
        status: ActivityRecordingStatus.failed,
        lastErrorKey: errorKey,
      ),
    );
  }

  void _emit(ActivityRecordingState state) {
    _state = state;
    _stateController.add(state);
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('ActivityRecordingService is disposed.');
    }
  }
}
