import 'dart:async';

import 'package:endurain/core/services/location_platform_adapter.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/features/activity/controllers/activity_recording_controller.dart';
import 'package:endurain/features/activity/services/activity_recording_service.dart';
import 'package:endurain/features/activity/services/activity_upload_service.dart';
import 'package:endurain/features/map/map_screen.dart';
import 'package:endurain/features/map/map_settings_repository.dart';
import 'package:endurain/features/map/map_state_controller.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = AppLocalizationsEn();

  setUp(() {
    PlatformUtils.debugIsApplePlatformOverride = false;
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  tearDown(PlatformUtils.debugResetOverrides);

  group('MapScreen', () {
    testWidgets('renders map controls and toggles location lock', (
      tester,
    ) async {
      final platform = _FakeLocationPlatformAdapter(
        currentPosition: _position(
          latitude: 41.1579,
          longitude: -8.6291,
          heading: 30,
        ),
      );
      final mapController = await _mapController(platform);
      final activityController = _activityController(platform);

      await tester.pumpWidget(
        _MapTestApp(
          child: MapScreen(
            controller: mapController,
            activityController: activityController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.myLocation), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.myLocation));
      await tester.pump();

      expect(find.byIcon(Icons.location_searching), findsOneWidget);
      expect(mapController.isLocationLocked, isFalse);

      activityController.dispose();
      mapController.dispose();
      await platform.close();
    });

    testWidgets('shows the loading indicator while location loads', (
      tester,
    ) async {
      final platform = _FakeLocationPlatformAdapter(
        currentPosition: _position(latitude: 41.1579, longitude: -8.6291),
        completeCurrentPosition: false,
      );
      final mapController = await _mapController(platform);
      final activityController = _activityController(platform);

      await tester.pumpWidget(
        _MapTestApp(
          child: MapScreen(
            controller: mapController,
            activityController: activityController,
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      platform.completePosition();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      activityController.dispose();
      mapController.dispose();
      await platform.close();
    });
  });
}

Future<MapStateController> _mapController(
  _FakeLocationPlatformAdapter platform,
) async {
  final storage = SecureStorageService();
  await storage.setTileServerUrl('https://tiles.example.test/{z}/{x}/{y}.png');

  final controller = MapStateController(
    locationService: LocationService(platformAdapter: platform),
    mapSettingsRepository: MapSettingsRepository(storage: storage),
  );
  controller.tileServerUrl = 'https://tiles.example.test/{z}/{x}/{y}.png';
  return controller;
}

ActivityRecordingController _activityController(
  _FakeLocationPlatformAdapter platform,
) {
  return ActivityRecordingController(
    recordingService: ActivityRecordingService(
      locationService: LocationService(platformAdapter: platform),
    ),
    uploadService: ActivityUploadService(
      config: const ActivityUploadConfig(endpoint: '', fieldName: ''),
    ),
    ownsService: true,
  );
}

Position _position({
  required double latitude,
  required double longitude,
  double heading = 0,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.utc(2026),
    accuracy: 5,
    altitude: 10,
    altitudeAccuracy: 1,
    heading: heading,
    headingAccuracy: 1,
    speed: 3,
    speedAccuracy: 1,
  );
}

class _FakeLocationPlatformAdapter implements LocationPlatformAdapter {
  _FakeLocationPlatformAdapter({
    required this.currentPosition,
    this.completeCurrentPosition = true,
  });

  final Position currentPosition;
  final bool completeCurrentPosition;
  final _positionController = StreamController<Position>.broadcast();
  final _currentPositionCompleter = Completer<Position>();

  void completePosition() {
    if (!_currentPositionCompleter.isCompleted) {
      _currentPositionCompleter.complete(currentPosition);
    }
  }

  Future<void> close() {
    return _positionController.close();
  }

  @override
  Future<LocationPermission> checkPermission() async {
    return LocationPermission.whileInUse;
  }

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  }) async {
    if (completeCurrentPosition) {
      return currentPosition;
    }

    return _currentPositionCompleter.future;
  }

  @override
  Stream<Position> getPositionStream({
    required LocationSettings locationSettings,
  }) {
    return _positionController.stream;
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    return true;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    return LocationPermission.whileInUse;
  }
}

class _MapTestApp extends StatelessWidget {
  const _MapTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }
}
