import 'dart:async';

import 'package:endurain/features/activity/models/activity_recording_state.dart';

class ActivityRecordingErrorKeys {
  const ActivityRecordingErrorKeys._();

  static const String invalidTransition = 'activityRecordingInvalidTransition';
}

class ActivityRecordingService {
  ActivityRecordingService({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final StreamController<ActivityRecordingState> _stateController =
      StreamController<ActivityRecordingState>.broadcast();

  ActivityRecordingState _state = ActivityRecordingState();
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
  }

  Future<void> stop() async {
    _ensureNotDisposed();
    if (!_state.isActive) {
      return;
    }

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
    _emit(ActivityRecordingState());
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await _stateController.close();
  }

  void _failInvalidTransition() {
    _emit(
      _state.copyWith(
        status: ActivityRecordingStatus.failed,
        lastErrorKey: ActivityRecordingErrorKeys.invalidTransition,
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