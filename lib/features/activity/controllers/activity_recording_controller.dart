import 'dart:async';

import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/services/activity_gpx_builder.dart';
import 'package:endurain/features/activity/services/activity_recording_service.dart';
import 'package:flutter/foundation.dart';

class ActivityRecordingController extends ChangeNotifier {
  ActivityRecordingController({
    ActivityRecordingService? recordingService,
    ActivityGpxBuilder gpxBuilder = const ActivityGpxBuilder(),
    bool ownsService = true,
  })
    : _recordingService = recordingService ?? ActivityRecordingService(),
      _gpxBuilder = gpxBuilder,
      _ownsService = ownsService {
    _stateSubscription = _recordingService.stateStream.listen((state) {
      _setState(state);
    });
  }

  final ActivityRecordingService _recordingService;
  final ActivityGpxBuilder _gpxBuilder;
  final bool _ownsService;
  late final StreamSubscription<ActivityRecordingState> _stateSubscription;
  bool _isDisposed = false;

  ActivityRecordingState _state = ActivityRecordingState();
  ActivityType _selectedActivityType = ActivityType.run;
  String? _completedGpx;

  ActivityRecordingState get state => _state;

  ActivityType get selectedActivityType => _selectedActivityType;

  String? get completedGpx => _completedGpx;

  void selectActivityType(ActivityType type) {
    if (_state.isActive || _state.status == ActivityRecordingStatus.stopping) {
      return;
    }
    if (_selectedActivityType == type) {
      return;
    }
    _selectedActivityType = type;
    _notifyListeners();
  }

  Future<void> start(ActivityType type) async {
    _completedGpx = null;
    selectActivityType(type);
    await _recordingService.start(activityType: _selectedActivityType);
    _setState(_recordingService.state);
  }

  Future<void> pause() async {
    await _recordingService.pause();
    _setState(_recordingService.state);
  }

  Future<void> resume() async {
    await _recordingService.resume();
    _setState(_recordingService.state);
  }

  Future<void> stop() async {
    await _recordingService.stop();
    final completedState = _recordingService.state;
    if (completedState.status == ActivityRecordingStatus.completed) {
      _completedGpx = _gpxBuilder.build(completedState);
      _setState(completedState);
      return;
    }
    _completedGpx = null;
    _setState(completedState);
  }

  Future<void> discard() async {
    _completedGpx = null;
    await _recordingService.discard();
    _setState(_recordingService.state);
  }

  void _setState(ActivityRecordingState state) {
    _state = state;
    _notifyListeners();
  }

  void _notifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_stateSubscription.cancel());
    if (_ownsService) {
      _recordingService.dispose();
    }
    super.dispose();
  }
}