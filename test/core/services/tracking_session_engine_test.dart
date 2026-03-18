import 'package:endurain/core/models/activity.dart';
// import 'package:endurain/core/models/track_point.dart'; // Removed as file not found, likely exported via activity.dart or tracking_session_engine.dart
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/services/audio_feedback_service.dart';
import 'package:endurain/core/services/bluetooth_sensor_service.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'tracking_session_engine_test.mocks.dart';

@GenerateMocks([
  LocationService,
  ActivityRepository,
  AudioFeedbackService,
  BluetoothSensorService,
])
void main() {
  late TrackingSessionEngine engine;
  late MockLocationService mockLocationService;
  late MockActivityRepository mockRepository;
  late MockAudioFeedbackService mockAudio;
  late MockBluetoothSensorService mockSensors;

  setUp(() {
    mockLocationService = MockLocationService();
    mockRepository = MockActivityRepository();
    mockAudio = MockAudioFeedbackService();
    mockSensors = MockBluetoothSensorService();

    // Default stubbing
    when(mockLocationService.getPositionStream()).thenAnswer((_) => const Stream.empty());
    when(mockRepository.create(any)).thenAnswer((_) async {});
    when(mockAudio.announceCountdown(any)).thenAnswer((_) async {});
    when(mockAudio.announceStart()).thenAnswer((_) async {});
    // Mock Bluetooth streams
    // BluetoothSensorService exposes 'heartRate' and 'cadence' getters, not 'heartRateStream'
    when(mockSensors.heartRate).thenAnswer((_) => const Stream.empty());
    when(mockSensors.cadence).thenAnswer((_) => const Stream.empty());

    engine = TrackingSessionEngine(
      locationService: mockLocationService,
      activityRepository: mockRepository,
      audioService: mockAudio,
      bluetoothService: mockSensors,
    );
  });

  tearDown(() {
    engine.dispose();
  });

  group('TrackingSessionEngine Countdown Tests', () {
    test('start() with countdown should update snapshot countdownSeconds correctly', () async {
      // Act
      // Setup listener BEFORE calling start to capture all events
      final states = <int?>[];
      final sub = engine.stream.listen((snapshot) {
        if (snapshot.state == TrackingSessionState.initializing) {
          states.add(snapshot.countdownSeconds);
        } else if (snapshot.state == TrackingSessionState.recording) {
          states.add(snapshot.countdownSeconds); // Should be null here
        }
      });

      // Now call start
      await engine.start(ActivityType.run, useCountdown: true);
      
      // Wait a tiny bit for the last event to propagate through the stream
      await Future<void>.delayed(const Duration(milliseconds: 100));
      
      await sub.cancel();

      // Verify sequence: starts at 6, goes down to 1, then null
      // 6 comes from the initial setup before the loop
      // 5, 4, 3, 2, 1 come from the loop
      // null comes from transition to recording
      expect(states, containsAllInOrder([6, 5, 4, 3, 2, 1, null]));
      
      // Verify audio calls
      verify(mockAudio.announceCountdown(5)).called(1);
      verify(mockAudio.announceCountdown(1)).called(1);
      verify(mockAudio.announceStart()).called(1);
    });

    test('start() without countdown should go directly to recording', () async {
      // Act
      await engine.start(ActivityType.run, useCountdown: false);

      // Assert
      expect(engine.snapshot.state, TrackingSessionState.recording);
      expect(engine.snapshot.countdownSeconds, isNull);
      
      // Verify NO countdown audio calls
      verifyNever(mockAudio.announceCountdown(any));
      verify(mockAudio.announceStart()).called(1);
    });
  });
  
  group('TrackingSessionSnapshot Tests', () {
    test('copyWith clearCountdown=true should set countdownSeconds to null', () {
      const snapshot = TrackingSessionSnapshot.idle();
      final withCountdown = snapshot.copyWith(countdownSeconds: 5);
      expect(withCountdown.countdownSeconds, 5);
      
      final cleared = withCountdown.copyWith(clearCountdown: true);
      expect(cleared.countdownSeconds, isNull);
    });
    
    test('copyWith clearCountdown=false should preserve countdownSeconds', () {
      const snapshot = TrackingSessionSnapshot.idle();
      final withCountdown = snapshot.copyWith(countdownSeconds: 5);
      
      final preserved = withCountdown.copyWith(state: TrackingSessionState.initializing);
      expect(preserved.countdownSeconds, 5);
    });
  });
}
