import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/features/activity/controllers/activity_recording_controller.dart';
import 'package:endurain/features/activity/models/activity_recording_state.dart';
import 'package:endurain/features/activity/services/activity_recording_service.dart';
import 'package:endurain/features/activity/services/activity_upload_service.dart';
import 'package:endurain/features/map/map_screen.dart';
import 'package:endurain/features/map/map_settings_repository.dart';
import 'package:endurain/features/map/map_state_controller.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import '../../helpers/fake_location_platform_adapter.dart';
import '../../helpers/widget_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = AppLocalizationsEn();

  setUp(() {
    debugDefaultTargetPlatformOverride = null;
    PlatformUtils.debugIsApplePlatformOverride = false;
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    PlatformUtils.debugResetOverrides();
  });

  group('MapScreen', () {
    testWidgets('renders map controls and toggles location lock', (
      tester,
    ) async {
      final platform = FakeLocationPlatformAdapter(
        currentPosition: testPosition(
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
      final platform = FakeLocationPlatformAdapter(
        currentPosition: testPosition(latitude: 41.1579, longitude: -8.6291),
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

    testWidgets('explains iOS background permission before recording', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      PlatformUtils.debugIsApplePlatformOverride = true;
      final platform = FakeLocationPlatformAdapter(
        currentPosition: testPosition(latitude: 41.1579, longitude: -8.6291),
        permission: LocationPermission.whileInUse,
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

      await tester.tap(find.byTooltip(l10n.activityStart));
      await tester.pumpAndSettle();

      expect(find.text(l10n.activityBackgroundPermissionTitle), findsOneWidget);
      expect(activityController.state.status, ActivityRecordingStatus.idle);

      await tester.tap(find.text(l10n.activityBackgroundPermissionContinue));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.activityBackgroundPermissionSettingsTitle),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.activityOpenSettings));
      await tester.pumpAndSettle();

      expect(platform.openAppSettingsCallCount, 1);
      expect(activityController.state.status, ActivityRecordingStatus.idle);

      debugDefaultTargetPlatformOverride = null;
      PlatformUtils.debugIsApplePlatformOverride = false;

      activityController.dispose();
      mapController.dispose();
      await platform.close();
    });
  });
}

Future<MapStateController> _mapController(
  FakeLocationPlatformAdapter platform,
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
  FakeLocationPlatformAdapter platform,
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

class _MapTestApp extends TestMaterialApp {
  const _MapTestApp({required super.child});
}
