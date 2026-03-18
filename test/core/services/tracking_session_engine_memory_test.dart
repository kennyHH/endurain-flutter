import 'dart:async';

import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/services/audio_feedback_service.dart';
import 'package:endurain/core/services/bluetooth_sensor_service.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'tracking_session_engine_memory_test.mocks.dart';

class _ScriptedPositionProvider implements PositionStreamProvider {
  final List<StreamController<PositionSample>> _controllers =
      <StreamController<PositionSample>>[];
  int _index = 0;

  StreamController<PositionSample> addStream() {
    final controller = StreamController<PositionSample>.broadcast();
    _controllers.add(controller);
    return controller;
  }

  @override
  Stream<PositionSample> getPositionStream() {
    if (_controllers.isEmpty) {
      throw StateError('No scripted streams configured');
    }
    final safeIndex = _index >= _controllers.length
        ? _controllers.length - 1
        : _index;
    _index++;
    return _controllers[safeIndex].stream;
  }
}

@GenerateMocks([
  ActivityRepository,
  AudioFeedbackService,
  BluetoothSensorService,
  LocationService,
])
void main() {
  late MockActivityRepository mockRepository;
  late MockAudioFeedbackService mockAudio;
  late MockBluetoothSensorService mockBluetooth;
  late MockLocationService mockLocationService;
  late StreamController<Position> positionStream;

  setUp(() {
    mockRepository = MockActivityRepository();
    mockAudio = MockAudioFeedbackService();
    mockBluetooth = MockBluetoothSensorService();
    mockLocationService = MockLocationService();
    positionStream = StreamController<Position>.broadcast();

    when(
      mockLocationService.getPositionStream(),
    ).thenAnswer((_) => positionStream.stream);
    when(mockRepository.create(any)).thenAnswer((_) async {});
    when(mockRepository.update(any)).thenAnswer((_) async {});
    when(mockRepository.insertTrackPoint(any, any)).thenAnswer((_) async {});
    when(mockAudio.announceStart()).thenAnswer((_) async {});
    when(
      mockAudio.announceSplit(
        km: anyNamed('km'),
        paceSecondsPerKm: anyNamed('paceSecondsPerKm'),
      ),
    ).thenAnswer((_) async {});

    when(mockBluetooth.heartRate).thenAnswer((_) => const Stream.empty());
    when(mockBluetooth.cadence).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() async {
    await positionStream.close();
  });

  test('Memory stability test: 10k points should trigger simplification', () async {
    final engine = TrackingSessionEngine(
      locationService: mockLocationService,
      activityRepository: mockRepository,
      audioService: mockAudio,
      bluetoothService: mockBluetooth,
    );
    addTearDown(engine.dispose);

    await engine.start(ActivityType.run);

    // Simulate 10,000 points in a line (simplifiable)
    // Roughly 11 meters apart to pass minPointDistanceMeters (5m)
    const baseLat = 52.5200;
    const baseLon = 13.4050;
    const step = 0.0001; // ~11m

    for (var i = 0; i < 10000; i++) {
      positionStream.add(
        Position(
          latitude: baseLat + (step * i),
          longitude: baseLon + (step * i),
          timestamp: DateTime.now().add(Duration(seconds: i)),
          accuracy: 5.0,
          altitude: 50.0,
          heading: 0.0,
          speed: 3.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );

      // Allow async processing
      await Future<void>.delayed(Duration.zero);
    }

    final snapshot = engine.snapshot;
    // We expect significantly less than 10,000 points due to simplification.
    expect(snapshot.trackPoints.length, lessThan(2000));
    expect(snapshot.trackPoints.length, greaterThan(0));

    // Verify DB insertion was called significantly more than the in-memory retention
    // Exact count varies due to smoothing and distance filters, but should be > 2000
    verify(mockRepository.insertTrackPoint(any, any)).called(greaterThan(2000));
  });

  test(
    'Low-speed poor-accuracy jitter is filtered by dynamic outlier policy',
    () async {
      final engine = TrackingSessionEngine(
        locationService: mockLocationService,
        activityRepository: mockRepository,
        audioService: mockAudio,
        bluetoothService: mockBluetooth,
      );
      addTearDown(engine.dispose);

      await engine.start(ActivityType.walk);

      final t0 = DateTime.now();
      positionStream.add(
        Position(
          latitude: 52.520000,
          longitude: 13.405000,
          timestamp: t0,
          accuracy: 8.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 1.1,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(engine.snapshot.trackPoints.length, 1);

      positionStream.add(
        Position(
          latitude: 52.520054,
          longitude: 13.405000,
          timestamp: t0.add(const Duration(seconds: 1)),
          accuracy: 28.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 0.4,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(engine.snapshot.trackPoints.length, 1);
    },
  );

  test(
    'Walk-Drift in Unsicherheitsradius wird als Low-Confidence-Sprung verworfen',
    () async {
      final engine = TrackingSessionEngine(
        locationService: mockLocationService,
        activityRepository: mockRepository,
        audioService: mockAudio,
        bluetoothService: mockBluetooth,
      );
      addTearDown(engine.dispose);

      await engine.start(ActivityType.walk);

      final t0 = DateTime.now();
      positionStream.add(
        Position(
          latitude: 52.520000,
          longitude: 13.405000,
          timestamp: t0,
          accuracy: 18.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 1.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(engine.snapshot.trackPoints.length, 1);

      positionStream.add(
        Position(
          latitude: 52.520072,
          longitude: 13.405000,
          timestamp: t0.add(const Duration(seconds: 25)),
          accuracy: 16.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 1.2,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(engine.snapshot.trackPoints.length, 1);
      expect(
        engine.snapshot.qualityMetrics.rejectedByMinDistance,
        greaterThan(0),
      );
    },
  );

  test(
    'Run-Warmup akzeptiert kurze Bewegung für bessere Startkontinuität',
    () async {
      final engine = TrackingSessionEngine(
        locationService: mockLocationService,
        activityRepository: mockRepository,
        audioService: mockAudio,
        bluetoothService: mockBluetooth,
      );
      addTearDown(engine.dispose);

      await engine.start(ActivityType.run);

      final t0 = DateTime.now();
      positionStream.add(
        Position(
          latitude: 52.520000,
          longitude: 13.405000,
          timestamp: t0,
          accuracy: 18.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 2.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(engine.snapshot.trackPoints.length, 1);

      positionStream.add(
        Position(
          latitude: 52.520110,
          longitude: 13.405000,
          timestamp: t0.add(const Duration(seconds: 4)),
          accuracy: 16.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 2.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(engine.snapshot.trackPoints.length, 2);
    },
  );

  test(
    'Kurzstrecken-Guardrail reduziert Distanzverlust nach MinDistance-Reject',
    () async {
      final engine = TrackingSessionEngine(
        locationService: mockLocationService,
        activityRepository: mockRepository,
        audioService: mockAudio,
        bluetoothService: mockBluetooth,
      );
      addTearDown(engine.dispose);

      await engine.start(ActivityType.run);

      final t0 = DateTime.now();
      positionStream.add(
        Position(
          latitude: 52.520000,
          longitude: 13.405000,
          timestamp: t0,
          accuracy: 10.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 3.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      positionStream.add(
        Position(
          latitude: 52.520036,
          longitude: 13.405000,
          timestamp: t0.add(const Duration(seconds: 25)),
          accuracy: 10.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 3.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      positionStream.add(
        Position(
          latitude: 52.520110,
          longitude: 13.405000,
          timestamp: t0.add(const Duration(seconds: 26)),
          accuracy: 10.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 3.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        engine.snapshot.qualityMetrics.rejectedByMinDistance,
        greaterThan(0),
      );
      expect(engine.snapshot.trackPoints.length, 2);
      expect(engine.snapshot.distanceMeters, greaterThan(9.0));
    },
  );

  test(
    'Start-Bias wird in den ersten Run-Samples auf den Median re-anchored',
    () async {
      final engine = TrackingSessionEngine(
        locationService: mockLocationService,
        activityRepository: mockRepository,
        audioService: mockAudio,
        bluetoothService: mockBluetooth,
      );
      addTearDown(engine.dispose);

      await engine.start(ActivityType.run);

      final t0 = DateTime.now();
      positionStream.add(
        Position(
          latitude: 52.520000,
          longitude: 13.405180,
          timestamp: t0,
          accuracy: 8.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 2.6,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      positionStream.add(
        Position(
          latitude: 52.520050,
          longitude: 13.405000,
          timestamp: t0.add(const Duration(seconds: 2)),
          accuracy: 6.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 2.8,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      positionStream.add(
        Position(
          latitude: 52.520100,
          longitude: 13.405000,
          timestamp: t0.add(const Duration(seconds: 4)),
          accuracy: 6.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 2.8,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      positionStream.add(
        Position(
          latitude: 52.520150,
          longitude: 13.405000,
          timestamp: t0.add(const Duration(seconds: 6)),
          accuracy: 6.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 2.8,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(engine.snapshot.trackPoints.length, greaterThanOrEqualTo(3));
      expect(engine.snapshot.trackPoints.first.longitude, lessThan(13.40508));
    },
  );

  test(
    'Ride mode accepts moderate accuracy at higher speed dynamically',
    () async {
      final engine = TrackingSessionEngine(
        locationService: mockLocationService,
        activityRepository: mockRepository,
        audioService: mockAudio,
        bluetoothService: mockBluetooth,
      );
      addTearDown(engine.dispose);

      await engine.start(ActivityType.ride);

      final t0 = DateTime.now();
      positionStream.add(
        Position(
          latitude: 52.520000,
          longitude: 13.405000,
          timestamp: t0,
          accuracy: 12.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 10.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      positionStream.add(
        Position(
          latitude: 52.520180,
          longitude: 13.405000,
          timestamp: t0.add(const Duration(seconds: 1)),
          accuracy: 34.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 12.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(engine.snapshot.trackPoints.length, 2);
    },
  );

  test('Quality metrics expose TTFF and rejection counters', () async {
    final engine = TrackingSessionEngine(
      locationService: mockLocationService,
      activityRepository: mockRepository,
      audioService: mockAudio,
      bluetoothService: mockBluetooth,
    );
    addTearDown(engine.dispose);

    await engine.start(ActivityType.walk);
    final t0 = DateTime.now();

    positionStream.add(
      Position(
        latitude: 52.520000,
        longitude: 13.405000,
        timestamp: t0,
        accuracy: 8.0,
        altitude: 40.0,
        heading: 0.0,
        speed: 1.1,
        speedAccuracy: 0.0,
        headingAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        isMocked: false,
        floor: 0,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    positionStream.add(
      Position(
        latitude: 52.520002,
        longitude: 13.405002,
        timestamp: t0.add(const Duration(seconds: 1)),
        accuracy: 45.0,
        altitude: 40.0,
        heading: 0.0,
        speed: 1.2,
        speedAccuracy: 0.0,
        headingAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        isMocked: false,
        floor: 0,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final metrics = engine.snapshot.qualityMetrics;
    expect(metrics.acceptedPoints, greaterThanOrEqualTo(1));
    expect(metrics.rejectedByAccuracy, greaterThanOrEqualTo(1));
    expect(metrics.ttffSeconds, isNotNull);
  });

  test(
    'GPS-Signal bleibt stabil bei kontinuierlichen Updates trotz schlechter Genauigkeit',
    () async {
      final engine = TrackingSessionEngine(
        locationService: mockLocationService,
        activityRepository: mockRepository,
        audioService: mockAudio,
        bluetoothService: mockBluetooth,
      );
      addTearDown(engine.dispose);

      await engine.start(ActivityType.walk);
      final t0 = DateTime.now();

      for (var i = 0; i < 6; i++) {
        positionStream.add(
          Position(
            latitude: 52.520000 + (i * 0.00002),
            longitude: 13.405000 + (i * 0.00002),
            timestamp: t0.add(Duration(seconds: i * 2)),
            accuracy: 65.0,
            altitude: 40.0,
            heading: 0.0,
            speed: 1.5,
            speedAccuracy: 0.0,
            headingAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            isMocked: false,
            floor: 0,
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      expect(engine.snapshot.isGpsSignalLost, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'GPS-Signal wird nach Inaktivität korrekt als verloren markiert',
    () async {
      final engine = TrackingSessionEngine(
        locationService: mockLocationService,
        activityRepository: mockRepository,
        audioService: mockAudio,
        bluetoothService: mockBluetooth,
      );
      addTearDown(engine.dispose);

      await engine.start(ActivityType.run);
      final t0 = DateTime.now();
      positionStream.add(
        Position(
          latitude: 52.520000,
          longitude: 13.405000,
          timestamp: t0,
          accuracy: 8.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 2.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(engine.snapshot.isGpsSignalLost, isFalse);

      await Future<void>.delayed(const Duration(seconds: 16));
      expect(engine.snapshot.isGpsSignalLost, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'GPS-Signal bleibt stabil bei langsamer aber kontinuierlicher Update-Kadenz',
    () async {
      final engine = TrackingSessionEngine(
        locationService: mockLocationService,
        activityRepository: mockRepository,
        audioService: mockAudio,
        bluetoothService: mockBluetooth,
      );
      addTearDown(engine.dispose);

      await engine.start(ActivityType.walk);
      final t0 = DateTime.now();
      for (var i = 0; i < 3; i++) {
        positionStream.add(
          Position(
            latitude: 52.520000 + (i * 0.00003),
            longitude: 13.405000 + (i * 0.00003),
            timestamp: t0.add(Duration(seconds: i * 11)),
            accuracy: 18.0,
            altitude: 40.0,
            heading: 0.0,
            speed: 1.2,
            speedAccuracy: 0.0,
            headingAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            isMocked: false,
            floor: 0,
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 11));
        expect(engine.snapshot.isGpsSignalLost, isFalse);
      }
    },
    timeout: const Timeout(Duration(seconds: 50)),
  );

  test(
    'Position stream reconnects after stream error',
    () async {
      final scriptedProvider = _ScriptedPositionProvider();
      final failingStream = scriptedProvider.addStream();
      final recoveryStream = scriptedProvider.addStream();
      addTearDown(() async {
        await failingStream.close();
        await recoveryStream.close();
      });

      final engine = TrackingSessionEngine(
        locationService: mockLocationService,
        activityRepository: mockRepository,
        audioService: mockAudio,
        bluetoothService: mockBluetooth,
        positionStreamProvider: scriptedProvider,
      );
      addTearDown(engine.dispose);

      await engine.start(ActivityType.run);

      failingStream.addError(Exception('permission denied'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(engine.snapshot.isGpsSignalLost, isTrue);

      await Future<void>.delayed(const Duration(seconds: 3));
      final now = DateTime.now();
      recoveryStream.add(
        PositionSample(
          latitude: 52.5201,
          longitude: 13.4051,
          timestamp: now,
          horizontalAccuracyMeters: 6,
          speed: 1.2,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(engine.snapshot.latestPosition, isNotNull);
      expect(
        engine.snapshot.latestPosition!.latitude,
        closeTo(52.5201, 0.00001),
      );
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  test('Phase-A diagnostics count accepted and rejected decisions', () async {
    final engine = TrackingSessionEngine(
      locationService: mockLocationService,
      activityRepository: mockRepository,
      audioService: mockAudio,
      bluetoothService: mockBluetooth,
      enablePhaseADiagnostics: true,
    );
    addTearDown(engine.dispose);

    await engine.start(ActivityType.walk);
    final t0 = DateTime.now();

    positionStream.add(
      Position(
        latitude: 52.520000,
        longitude: 13.405000,
        timestamp: t0,
        accuracy: 8.0,
        altitude: 40.0,
        heading: 0.0,
        speed: 1.1,
        speedAccuracy: 0.0,
        headingAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        isMocked: false,
        floor: 0,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    positionStream.add(
      Position(
        latitude: 52.520010,
        longitude: 13.405010,
        timestamp: t0.add(const Duration(seconds: 1)),
        accuracy: 60.0,
        altitude: 40.0,
        heading: 0.0,
        speed: 1.0,
        speedAccuracy: 0.0,
        headingAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        isMocked: false,
        floor: 0,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final summary = engine.diagnosticsSummary;
    expect(summary.enabled, isTrue);
    expect(summary.totalSamples, equals(2));
    expect(summary.acceptedSamples, greaterThanOrEqualTo(1));
    expect(summary.rejectedSamples, greaterThanOrEqualTo(1));
    expect(summary.rejectedByReason['accuracy'] ?? 0, greaterThanOrEqualTo(1));
    expect(engine.diagnosticsRecentEvents, isNotEmpty);
  });

  test('Phase-A diagnostics capture stream gap histogram buckets', () async {
    final engine = TrackingSessionEngine(
      locationService: mockLocationService,
      activityRepository: mockRepository,
      audioService: mockAudio,
      bluetoothService: mockBluetooth,
      enablePhaseADiagnostics: true,
    );
    addTearDown(engine.dispose);

    await engine.start(ActivityType.run);
    final t0 = DateTime.now();

    positionStream.add(
      Position(
        latitude: 52.520000,
        longitude: 13.405000,
        timestamp: t0,
        accuracy: 8.0,
        altitude: 40.0,
        heading: 0.0,
        speed: 2.6,
        speedAccuracy: 0.0,
        headingAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        isMocked: false,
        floor: 0,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    positionStream.add(
      Position(
        latitude: 52.520080,
        longitude: 13.405000,
        timestamp: t0.add(const Duration(seconds: 6)),
        accuracy: 9.0,
        altitude: 40.0,
        heading: 0.0,
        speed: 2.8,
        speedAccuracy: 0.0,
        headingAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        isMocked: false,
        floor: 0,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final summary = engine.diagnosticsSummary;
    expect(summary.totalSamples, equals(2));
    expect(summary.streamGapOver2sCount, equals(1));
    expect(summary.streamGapOver5sCount, equals(1));
    expect(summary.maxStreamGapMs, greaterThanOrEqualTo(6000));
  });

  test(
    'Phase-B quality metrics expose synthetic distance divergence',
    () async {
      final engine = TrackingSessionEngine(
        locationService: mockLocationService,
        activityRepository: mockRepository,
        audioService: mockAudio,
        bluetoothService: mockBluetooth,
        enablePhaseBDistanceConsistency: true,
      );
      addTearDown(engine.dispose);

      await engine.start(ActivityType.run);
      final t0 = DateTime.now();

      positionStream.add(
        Position(
          latitude: 52.520000,
          longitude: 13.405000,
          timestamp: t0,
          accuracy: 10.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 3.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      positionStream.add(
        Position(
          latitude: 52.520036,
          longitude: 13.405000,
          timestamp: t0.add(const Duration(seconds: 25)),
          accuracy: 10.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 3.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      positionStream.add(
        Position(
          latitude: 52.520110,
          longitude: 13.405000,
          timestamp: t0.add(const Duration(seconds: 26)),
          accuracy: 10.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 3.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final metrics = engine.snapshot.qualityMetrics;
      expect(metrics.phaseBConsistencyEnabled, isTrue);
      expect(metrics.syntheticDistanceCreditMeters, greaterThan(0));
      expect(metrics.acceptedTrackDistanceMeters, greaterThan(0));
      expect(metrics.distanceDivergenceMeters, greaterThan(0));
      expect(metrics.distanceDivergenceRatio, greaterThan(0));
    },
  );

  test(
    'Short-distance guardrail caps synthetic credit in short loops',
    () async {
      final engine = TrackingSessionEngine(
        locationService: mockLocationService,
        activityRepository: mockRepository,
        audioService: mockAudio,
        bluetoothService: mockBluetooth,
        enablePhaseBDistanceConsistency: true,
      );
      addTearDown(engine.dispose);

      await engine.start(ActivityType.run);
      final t0 = DateTime.now();

      positionStream.add(
        Position(
          latitude: 52.520000,
          longitude: 13.405000,
          timestamp: t0,
          accuracy: 8.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 2.0,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      for (var i = 1; i <= 30; i++) {
        final latitude = i.isEven ? 52.520030 : 52.520000;
        final longitude = i.isEven ? 13.405000 : 13.405030;
        positionStream.add(
          Position(
            latitude: latitude,
            longitude: longitude,
            timestamp: t0.add(Duration(seconds: i * 2)),
            accuracy: 8.0,
            altitude: 40.0,
            heading: 0.0,
            speed: 2.0,
            speedAccuracy: 0.0,
            headingAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            isMocked: false,
            floor: 0,
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));

      positionStream.add(
        Position(
          latitude: 52.520140,
          longitude: 13.405000,
          timestamp: t0.add(const Duration(seconds: 65)),
          accuracy: 8.0,
          altitude: 40.0,
          heading: 0.0,
          speed: 2.5,
          speedAccuracy: 0.0,
          headingAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          isMocked: false,
          floor: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final metrics = engine.snapshot.qualityMetrics;
      expect(metrics.syntheticDistanceCreditMeters, lessThanOrEqualTo(10.0));
      expect(metrics.distanceDivergenceMeters, lessThanOrEqualTo(10.0));
    },
  );

  test('quality metrics expose raw vs filtered elevation gain', () async {
    final engine = TrackingSessionEngine(
      locationService: mockLocationService,
      activityRepository: mockRepository,
      audioService: mockAudio,
      bluetoothService: mockBluetooth,
    );
    addTearDown(engine.dispose);

    await engine.start(ActivityType.run);
    final t0 = DateTime.now();

    positionStream.add(
      Position(
        latitude: 52.520000,
        longitude: 13.405000,
        timestamp: t0,
        accuracy: 8.0,
        altitude: 170.0,
        heading: 0.0,
        speed: 2.2,
        speedAccuracy: 0.0,
        headingAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        isMocked: false,
        floor: 0,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    positionStream.add(
      Position(
        latitude: 52.520100,
        longitude: 13.405000,
        timestamp: t0.add(const Duration(seconds: 10)),
        accuracy: 8.0,
        altitude: 170.8,
        heading: 0.0,
        speed: 2.2,
        speedAccuracy: 0.0,
        headingAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        isMocked: false,
        floor: 0,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    positionStream.add(
      Position(
        latitude: 52.520200,
        longitude: 13.405000,
        timestamp: t0.add(const Duration(seconds: 20)),
        accuracy: 8.0,
        altitude: 172.5,
        heading: 0.0,
        speed: 2.2,
        speedAccuracy: 0.0,
        headingAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        isMocked: false,
        floor: 0,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final metrics = engine.snapshot.qualityMetrics;
    expect(metrics.rawElevationGainMeters, closeTo(2.5, 0.05));
    expect(metrics.filteredElevationGainMeters, closeTo(1.7, 0.05));
    expect(
      metrics.rawElevationGainMeters,
      greaterThan(metrics.filteredElevationGainMeters),
    );
  });
}
