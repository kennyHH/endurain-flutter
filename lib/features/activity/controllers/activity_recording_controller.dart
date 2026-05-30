import 'dart:async';

import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/features/activity/services/activity_recording_service.dart';
import 'package:flutter/foundation.dart';

class ActivityRecordingController extends ChangeNotifier {
  ActivityRecordingController({
    ActivityRecordingService? recordingService,
    bool ownsService = true,
  })
    : _recordingService = recordingService ?? ActivityRecordingService(),
      _ownsService = ownsService {
    _stateSubscription = _recordingService.stateStream.listen((state) {
      _state = state;
      _notifyListeners();
    });
  }

  final ActivityRecordingService _recordingService;
  final bool _ownsService;
  late final StreamSubscription<ActivityRecordingState> _stateSubscription;
  bool _isDisposed = false;

  ActivityRecordingState _state = ActivityRecordingState();
  ActivityType _selectedActivityType = ActivityType.run;

  ActivityRecordingState get state => _state;

  ActivityType get selectedActivityType => _selectedActivityType;

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
    selectActivityType(type);
    await _recordingService.start(activityType: _selectedActivityType);
  }

  Future<void> pause() async {
    await _recordingService.pause();
  }

  Future<void> resume() async {
    await _recordingService.resume();
  }

  Future<void> stop() async {
    await _recordingService.stop();
  }

  Future<void> discard() async {
    await _recordingService.discard();
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