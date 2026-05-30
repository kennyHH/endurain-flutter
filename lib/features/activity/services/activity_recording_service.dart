import 'dart:async';

import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_track_point.dart';
import 'package:geolocator/geolocator.dart';

class ActivityRecordingErrorKeys {
  const ActivityRecordingErrorKeys._();

  static const String invalidTransition = 'activityRecordingInvalidTransition';
  static const String locationStreamFailed = 'activityLocationStreamFailed';
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
  bool _isDisposed = false;

  ActivityRecordingState get state => _state;

  Stream<ActivityRecordingState> get stateStream => _stateController.stream;

  Future<void> start({required String activityType}) async {
    _ensureNotDisposed();
    if (_state.isActive || _state.status == ActivityRecordingStatus.stopping) {
      return;
    }

    _emit(
      ActivityRecordingState(
        status: ActivityRecordingStatus.recording,
        activityType: activityType,
        startedAt: _now(),
      ),
    );
    _startLocationStream();
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

    await _cancelPositionSubscription();
    _emit(_state.copyWith(status: ActivityRecordingStatus.paused));
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

    _emit(_state.copyWith(status: ActivityRecordingStatus.recording));
    _startLocationStream();
  }

  Future<void> stop() async {
    _ensureNotDisposed();
    if (!_state.isActive) {
      return;
    }

    await _cancelPositionSubscription();
    _emit(_state.copyWith(status: ActivityRecordingStatus.stopping));
    _emit(
      _state.copyWith(
        status: ActivityRecordingStatus.completed,
        endedAt: _now(),
      ),
    );
  }

  Future<void> discard() async {
    _ensureNotDisposed();
    await _cancelPositionSubscription();
    _emit(ActivityRecordingState());
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await _cancelPositionSubscription();
    await _stateController.close();
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

  void _failInvalidTransition() {
    _fail(ActivityRecordingErrorKeys.invalidTransition);
  }

  void _fail(String errorKey) {
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