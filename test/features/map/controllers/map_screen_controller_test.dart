import 'dart:async';

import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/power_management_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:endurain/features/map/controllers/map_screen_controller.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../map/tracking_controls_test.mocks.dart' as map_mocks;
import '../../../widget_test.mocks.dart' as app_mocks;

class _TestStorage extends SecureStorageService {
  bool authenticated = true;
  bool permissionsOnboardingCompleted = false;
  int permissionsOnboardingWrites = 0;
  (double, double)? cachedLocation;
  final Map<String, String> _values = <String, String>{
    'audio_enabled': 'true',
    'dynamic_map_zoom_enabled': 'true',
    'dynamic_map_zoom_preset': 'balanced',
  };

  @override
  Future<String?> getTileServerUrl() async => null;

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<bool> isAuthenticated() async => authenticated;

  @override
  Future<bool> getPermissionsOnboardingCompleted() async =>
      permissionsOnboardingCompleted;

  @override
  Future<void> setPermissionsOnboardingCompleted(bool completed) async {
    permissionsOnboardingCompleted = completed;
    permissionsOnboardingWrites++;
  }

  @override
  Future<void> setLastLocation(double lat, double lng) async {
    cachedLocation = (lat, lng);
  }

  @override
  Future<(double, double)?> getLastLocation() async => cachedLocation;
}

class _FakePowerManagementService extends PowerManagementService {
  int batteryExemptionRequests = 0;

  @override
  Future<void> enableWakelock() async {}

  @override
  Future<void> disableWakelock() async {}

  @override
  Future<bool> isBatteryOptimizationIgnored() async => true;

  @override
  Future<bool> requestBatteryExemption() async {
    batteryExemptionRequests++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapScreenController start gating', () {
    late map_mocks.MockTrackingSessionEngine mockEngine;
    late _TestStorage mockStorage;
    late app_mocks.MockLocationService mockLocation;
    late app_mocks.MockAudioFeedbackService mockAudio;
    late StreamController<TrackingSessionSnapshot> streamController;
    late StreamController<bool> audioEnabledStreamController;

    setUp(() {
      mockEngine = map_mocks.MockTrackingSessionEngine();
      mockStorage = _TestStorage();
      mockLocation = app_mocks.MockLocationService();
      mockAudio = app_mocks.MockAudioFeedbackService();
      streamController = StreamController<TrackingSessionSnapshot>.broadcast();
      audioEnabledStreamController = StreamController<bool>.broadcast();

      when(mockEngine.stream).thenAnswer((_) => streamController.stream);
      when(
        mockEngine.start(any, useCountdown: anyNamed('useCountdown')),
      ).thenAnswer((_) async => true);
      when(
        mockLocation.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        mockLocation.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(mockLocation.getLastKnownPosition()).thenAnswer((_) async => null);
      when(mockLocation.getCurrentPosition()).thenAnswer((_) async => null);
      when(mockAudio.isEnabled).thenReturn(true);
      when(mockAudio.toggleEnabled(any)).thenReturn(null);
      when(
        mockAudio.enabledStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
    });

    tearDown(() async {
      await streamController.close();
      await audioEnabledStreamController.close();
    });

    test('normalisiert negative Kompass-Werte korrekt auf 0..360', () {
      expect(
        MapScreenController.normalizeHeadingDegrees(-90),
        closeTo(270, 0.001),
      );
      expect(
        MapScreenController.normalizeHeadingDegrees(450),
        closeTo(90, 0.001),
      );
    });

    test('synchronisiert Audio-State aus Service-Events', () async {
      when(
        mockAudio.enabledStream,
      ).thenAnswer((_) => audioEnabledStreamController.stream);
      final controller = MapScreenController(
        locationService: mockLocation,
        storage: mockStorage,
        trackingSessionEngine: mockEngine,
        audioFeedbackService: mockAudio,
        powerManagementService: _FakePowerManagementService(),
      );
      addTearDown(controller.dispose);
      controller.isLocationLocked = false;

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.audioEnabled, isTrue);

      audioEnabledStreamController.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.audioEnabled, isFalse);

      audioEnabledStreamController.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.audioEnabled, isTrue);
    });

    test('startTracking blockiert Warm-Start ohne stabilen GPS-Fix', () async {
      mockStorage.cachedLocation = (51.0, 13.7);

      final controller = MapScreenController(
        locationService: mockLocation,
        storage: mockStorage,
        trackingSessionEngine: mockEngine,
        audioFeedbackService: mockAudio,
        powerManagementService: _FakePowerManagementService(),
      );
      addTearDown(controller.dispose);
      controller.isLocationLocked = false;

      await Future<void>.delayed(const Duration(milliseconds: 60));
      controller.startTracking(ActivityType.run);

      verifyNever(
        mockEngine.start(any, useCountdown: anyNamed('useCountdown')),
      );
    });

    test('startTracking erlaubt Start nach stabilen GPS-Fixes', () async {
      mockStorage.cachedLocation = null;

      final controller = MapScreenController(
        locationService: mockLocation,
        storage: mockStorage,
        trackingSessionEngine: mockEngine,
        audioFeedbackService: mockAudio,
        powerManagementService: _FakePowerManagementService(),
      );
      addTearDown(controller.dispose);
      controller.isLocationLocked = false;
      controller.isLocationLocked = false;

      await Future<void>.delayed(const Duration(milliseconds: 60));
      final now = DateTime.now().toUtc();
      for (var i = 0; i < 3; i++) {
        streamController.add(
          TrackingSessionSnapshot(
            state: TrackingSessionState.idle,
            duration: Duration.zero,
            distanceMeters: 0,
            elevationGainMeters: 0,
            trackPoints: const [],
            lastPositionAt: now,
            latestPosition: PositionSample(
              latitude: 51.0 + (i * 0.00001),
              longitude: 13.7 + (i * 0.00001),
              timestamp: now.add(Duration(seconds: i)),
              horizontalAccuracyMeters: 10,
              speed: 1.2,
            ),
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));

      controller.startTracking(ActivityType.run);

      verify(mockEngine.start(ActivityType.run, useCountdown: true)).called(1);
    });

    test(
      'nutzt Kurs-Heading als Fallback wenn kein frischer Kompasswert vorliegt',
      () async {
        final controller = MapScreenController(
          locationService: mockLocation,
          storage: mockStorage,
          trackingSessionEngine: mockEngine,
          audioFeedbackService: mockAudio,
          powerManagementService: _FakePowerManagementService(),
        );
        addTearDown(controller.dispose);
        controller.isLocationLocked = false;

        await Future<void>.delayed(const Duration(milliseconds: 60));
        final baseTime = DateTime.now().toUtc();

        streamController.add(
          TrackingSessionSnapshot(
            state: TrackingSessionState.idle,
            duration: Duration.zero,
            distanceMeters: 0,
            elevationGainMeters: 0,
            trackPoints: const [],
            lastPositionAt: baseTime,
            latestPosition: PositionSample(
              latitude: 51.00000,
              longitude: 13.70000,
              timestamp: baseTime,
              horizontalAccuracyMeters: 8,
              speed: 2.2,
            ),
          ),
        );
        streamController.add(
          TrackingSessionSnapshot(
            state: TrackingSessionState.idle,
            duration: Duration.zero,
            distanceMeters: 0,
            elevationGainMeters: 0,
            trackPoints: const [],
            lastPositionAt: baseTime.add(const Duration(seconds: 1)),
            latestPosition: PositionSample(
              latitude: 51.00000,
              longitude: 13.70020,
              timestamp: baseTime.add(const Duration(seconds: 1)),
              horizontalAccuracyMeters: 8,
              speed: 2.2,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(controller.heading, greaterThan(60));
        expect(controller.heading, lessThan(120));
      },
    );

    test(
      'nutzt keinen Kurs-Fallback bei stationärer langsamer Bewegung',
      () async {
        final controller = MapScreenController(
          locationService: mockLocation,
          storage: mockStorage,
          trackingSessionEngine: mockEngine,
          audioFeedbackService: mockAudio,
          powerManagementService: _FakePowerManagementService(),
        );
        addTearDown(controller.dispose);
        controller.isLocationLocked = false;

        await Future<void>.delayed(const Duration(milliseconds: 60));
        final baseTime = DateTime.now().toUtc();

        streamController.add(
          TrackingSessionSnapshot(
            state: TrackingSessionState.idle,
            duration: Duration.zero,
            distanceMeters: 0,
            elevationGainMeters: 0,
            trackPoints: const [],
            lastPositionAt: baseTime,
            latestPosition: PositionSample(
              latitude: 51.00000,
              longitude: 13.70000,
              timestamp: baseTime,
              horizontalAccuracyMeters: 8,
              speed: 0.2,
            ),
          ),
        );
        streamController.add(
          TrackingSessionSnapshot(
            state: TrackingSessionState.idle,
            duration: Duration.zero,
            distanceMeters: 0,
            elevationGainMeters: 0,
            trackPoints: const [],
            lastPositionAt: baseTime.add(const Duration(seconds: 1)),
            latestPosition: PositionSample(
              latitude: 51.00000,
              longitude: 13.70020,
              timestamp: baseTime.add(const Duration(seconds: 1)),
              horizontalAccuracyMeters: 8,
              speed: 0.2,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(controller.heading, closeTo(0, 0.001));
      },
    );

    test('nutzt keinen Kurs-Fallback bei schlechter GPS-Genauigkeit', () async {
      final controller = MapScreenController(
        locationService: mockLocation,
        storage: mockStorage,
        trackingSessionEngine: mockEngine,
        audioFeedbackService: mockAudio,
        powerManagementService: _FakePowerManagementService(),
      );
      addTearDown(controller.dispose);
      controller.isLocationLocked = false;

      await Future<void>.delayed(const Duration(milliseconds: 60));
      final baseTime = DateTime.now().toUtc();

      streamController.add(
        TrackingSessionSnapshot(
          state: TrackingSessionState.idle,
          duration: Duration.zero,
          distanceMeters: 0,
          elevationGainMeters: 0,
          trackPoints: const [],
          lastPositionAt: baseTime,
          latestPosition: PositionSample(
            latitude: 51.00000,
            longitude: 13.70000,
            timestamp: baseTime,
            horizontalAccuracyMeters: 40,
            speed: 2.5,
          ),
        ),
      );
      streamController.add(
        TrackingSessionSnapshot(
          state: TrackingSessionState.idle,
          duration: Duration.zero,
          distanceMeters: 0,
          elevationGainMeters: 0,
          trackPoints: const [],
          lastPositionAt: baseTime.add(const Duration(seconds: 1)),
          latestPosition: PositionSample(
            latitude: 51.00000,
            longitude: 13.70020,
            timestamp: baseTime.add(const Duration(seconds: 1)),
            horizontalAccuracyMeters: 40,
            speed: 2.5,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(controller.heading, closeTo(0, 0.001));
    });

    test('heilt Permission-Flag bei eingehender Live-Position', () async {
      when(
        mockLocation.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.denied);
      final controller = MapScreenController(
        locationService: mockLocation,
        storage: mockStorage,
        trackingSessionEngine: mockEngine,
        audioFeedbackService: mockAudio,
        powerManagementService: _FakePowerManagementService(),
      );
      addTearDown(controller.dispose);
      controller.isLocationLocked = false;

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(controller.hasLocationPermission, isFalse);

      final now = DateTime.now().toUtc();
      streamController.add(
        TrackingSessionSnapshot(
          state: TrackingSessionState.idle,
          duration: Duration.zero,
          distanceMeters: 0,
          elevationGainMeters: 0,
          trackPoints: const [],
          lastPositionAt: now,
          latestPosition: PositionSample(
            latitude: 51.01,
            longitude: 13.71,
            timestamp: now,
            horizontalAccuracyMeters: 12,
            speed: 1.0,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.hasLocationPermission, isTrue);
      expect(controller.gpsStartupState, equals(GpsStartupState.uiReady));
    });

    test(
      'setzt Startup-State auf permissionDenied ohne Standortfreigabe',
      () async {
        when(
          mockLocation.checkPermission(),
        ).thenAnswer((_) async => LocationPermission.denied);
        final controller = MapScreenController(
          locationService: mockLocation,
          storage: mockStorage,
          trackingSessionEngine: mockEngine,
          audioFeedbackService: mockAudio,
          powerManagementService: _FakePowerManagementService(),
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(
          controller.gpsStartupState,
          equals(GpsStartupState.permissionDenied),
        );
        expect(controller.shouldRenderUserLocation, isFalse);
      },
    );

    test(
      'promoted Startup-State auf uiReady bei erfolgreichem Single-Fix',
      () async {
        when(mockLocation.getCurrentPosition()).thenAnswer(
          (_) async => Position(
            latitude: 51.06,
            longitude: 13.75,
            timestamp: DateTime.now().toUtc(),
            accuracy: 6.0,
            altitude: 120.0,
            heading: 0.0,
            speed: 0.2,
            speedAccuracy: 0.0,
            headingAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            isMocked: false,
            floor: 0,
          ),
        );
        final controller = MapScreenController(
          locationService: mockLocation,
          storage: mockStorage,
          trackingSessionEngine: mockEngine,
          audioFeedbackService: mockAudio,
          powerManagementService: _FakePowerManagementService(),
        );
        addTearDown(controller.dispose);
        controller.isLocationLocked = false;

        await Future<void>.delayed(const Duration(milliseconds: 700));
        expect(controller.gpsStartupState, equals(GpsStartupState.uiReady));
        expect(controller.shouldRenderUserLocation, isTrue);
      },
    );

    test(
      'checkLocationPermission reinitialisiert bei gleicher Permission ohne frischen Fix',
      () async {
        final controller = MapScreenController(
          locationService: mockLocation,
          storage: mockStorage,
          trackingSessionEngine: mockEngine,
          audioFeedbackService: mockAudio,
          powerManagementService: _FakePowerManagementService(),
        );
        addTearDown(controller.dispose);
        controller.isLocationLocked = false;

        await Future<void>.delayed(const Duration(milliseconds: 700));
        await controller.checkLocationPermission();
        await Future<void>.delayed(const Duration(milliseconds: 700));

        verify(mockLocation.getCurrentPosition()).called(2);
      },
    );

    test(
      'startTracking erlaubt Start mit stabilem Single-Fix ohne Stream',
      () async {
        when(mockLocation.getCurrentPosition()).thenAnswer(
          (_) async => Position(
            latitude: 51.05,
            longitude: 13.74,
            timestamp: DateTime.now().toUtc(),
            accuracy: 8.0,
            altitude: 120.0,
            heading: 0.0,
            speed: 0.2,
            speedAccuracy: 0.0,
            headingAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            isMocked: false,
            floor: 0,
          ),
        );
        final controller = MapScreenController(
          locationService: mockLocation,
          storage: mockStorage,
          trackingSessionEngine: mockEngine,
          audioFeedbackService: mockAudio,
          powerManagementService: _FakePowerManagementService(),
        );
        addTearDown(controller.dispose);
        controller.isLocationLocked = false;

        await Future<void>.delayed(const Duration(milliseconds: 700));
        expect(controller.hasStableStartFix, isTrue);

        controller.startTracking(ActivityType.run);
        verify(
          mockEngine.start(ActivityType.run, useCountdown: true),
        ).called(1);
      },
    );

    test('zeigt Permission-Onboarding beim Erststart unabhängig vom Login', () async {
      mockStorage.permissionsOnboardingCompleted = false;
      mockStorage.authenticated = false;
      final controller = MapScreenController(
        locationService: mockLocation,
        storage: mockStorage,
        trackingSessionEngine: mockEngine,
        audioFeedbackService: mockAudio,
        powerManagementService: _FakePowerManagementService(),
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(controller.shouldShowPermissionOnboarding, isTrue);
    });

    test('blendet Permission-Onboarding aus wenn bereits abgeschlossen', () async {
      mockStorage.permissionsOnboardingCompleted = true;
      final controller = MapScreenController(
        locationService: mockLocation,
        storage: mockStorage,
        trackingSessionEngine: mockEngine,
        audioFeedbackService: mockAudio,
        powerManagementService: _FakePowerManagementService(),
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(controller.shouldShowPermissionOnboarding, isFalse);
    });

    test(
      'skipPermissionOnboarding blendet Dialog aus und setzt Flag',
      () async {
        final controller = MapScreenController(
          locationService: mockLocation,
          storage: mockStorage,
          trackingSessionEngine: mockEngine,
          audioFeedbackService: mockAudio,
          powerManagementService: _FakePowerManagementService(),
        );
        addTearDown(controller.dispose);
        controller.isLocationLocked = false;
        controller.isLocationLocked = false;

        await Future<void>.delayed(const Duration(milliseconds: 80));
        await controller.skipPermissionOnboarding();

        expect(controller.shouldShowPermissionOnboarding, isFalse);
        expect(mockStorage.permissionsOnboardingWrites, equals(1));
      },
    );

    test(
      'runPermissionOnboardingSetup führt Freigaben sequentiell aus',
      () async {
        var permissionChecks = 0;
        when(mockLocation.checkPermission()).thenAnswer((_) async {
          permissionChecks++;
          if (permissionChecks <= 2) {
            return LocationPermission.denied;
          }
          return LocationPermission.whileInUse;
        });
        when(
          mockLocation.requestPermission(),
        ).thenAnswer((_) async => LocationPermission.whileInUse);
        final power = _FakePowerManagementService();
        final controller = MapScreenController(
          locationService: mockLocation,
          storage: mockStorage,
          trackingSessionEngine: mockEngine,
          audioFeedbackService: mockAudio,
          powerManagementService: power,
        );
        addTearDown(controller.dispose);
        controller.isLocationLocked = false;

        await Future<void>.delayed(const Duration(milliseconds: 80));
        await controller.runPermissionOnboardingSetup();

        expect(controller.shouldShowPermissionOnboarding, isFalse);
        verify(mockLocation.requestPermission()).called(1);
        expect(mockStorage.permissionsOnboardingWrites, equals(1));
      },
    );

    test(
      'runPermissionOnboardingSetup bleibt offen wenn Standort nicht freigegeben',
      () async {
        when(
          mockLocation.checkPermission(),
        ).thenAnswer((_) async => LocationPermission.denied);
        when(
          mockLocation.requestPermission(),
        ).thenAnswer((_) async => LocationPermission.denied);
        final power = _FakePowerManagementService();
        final controller = MapScreenController(
          locationService: mockLocation,
          storage: mockStorage,
          trackingSessionEngine: mockEngine,
          audioFeedbackService: mockAudio,
          powerManagementService: power,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(const Duration(milliseconds: 80));
        await controller.runPermissionOnboardingSetup();

        expect(controller.hasLocationPermission, isFalse);
        expect(controller.shouldShowPermissionOnboarding, isTrue);
        verify(mockLocation.requestPermission()).called(1);
        expect(mockStorage.permissionsOnboardingCompleted, isFalse);
      },
    );
  });
}
