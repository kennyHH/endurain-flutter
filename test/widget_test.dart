// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:endurain/app.dart';
import 'package:endurain/features/settings/controllers/settings_controller.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/audio_feedback_service.dart';

import 'package:endurain/core/di/service_locator.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/error_handling/error_handler_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'widget_test.mocks.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:endurain/core/database/app_database.dart';

import 'package:endurain/features/auth/controllers/login_controller.dart';

@GenerateMocks([
  AuthService,
  SecureStorageService,
  ErrorHandlerService,
  AudioFeedbackService,
  LocationService,
  AppDatabase,
  LoginController,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuth;
  late MockSecureStorageService mockStorage;
  late MockErrorHandlerService mockError;
  late MockAudioFeedbackService mockAudio;
  late MockLocationService mockLocation;
  late MockAppDatabase mockDatabase;
  late MockLoginController mockLoginController;

  setUp(() async {
    mockAuth = MockAuthService();
    mockStorage = MockSecureStorageService();
    mockError = MockErrorHandlerService();
    mockAudio = MockAudioFeedbackService();
    mockLocation = MockLocationService();
    mockDatabase = MockAppDatabase();
    mockLoginController = MockLoginController();

    PackageInfo.setMockInitialValues(
      appName: 'Endurain',
      packageName: 'com.example.endurain',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    // Login Controller mocks
    when(mockLoginController.isLoading).thenReturn(false);
    when(mockLoginController.isStep2).thenReturn(false);
    when(mockLoginController.showMfaInput).thenReturn(false);
    when(mockLoginController.error).thenReturn(null);
    when(mockLoginController.loginSuccess).thenReturn(false);
    when(mockLoginController.localLoginEnabled).thenReturn(true);
    when(mockLoginController.availableIdPs).thenReturn([]);
    when(mockLoginController.serverSettings).thenReturn(null);
    when(mockLoginController.obscurePassword).thenReturn(true);

    when(mockAuth.isAuthenticated()).thenAnswer((_) async => false);

    // Settings mocks
    when(
      mockStorage.read(key: 'audio_enabled'),
    ).thenAnswer((_) async => 'true');
    when(mockStorage.read(key: 'audio_volume')).thenAnswer((_) async => null);
    when(
      mockStorage.read(key: 'audio_announce_start'),
    ).thenAnswer((_) async => 'true');
    when(
      mockStorage.read(key: 'audio_announce_splits'),
    ).thenAnswer((_) async => 'true');
    when(
      mockStorage.read(key: 'audio_announce_gps'),
    ).thenAnswer((_) async => 'true');
    when(
      mockStorage.read(key: 'dynamic_map_zoom_enabled'),
    ).thenAnswer((_) async => 'true');
    when(
      mockStorage.read(key: 'dynamic_map_zoom_preset'),
    ).thenAnswer((_) async => 'balanced');
    when(mockStorage.read(key: 'activities_v1')).thenAnswer((_) async => null);
    when(mockStorage.getThemeMode()).thenAnswer((_) async => null);
    when(mockStorage.getHighContrast()).thenAnswer((_) async => false);
    when(mockStorage.getThemePreset()).thenAnswer((_) async => null);
    when(mockStorage.getRouteDisplayMode()).thenAnswer((_) async => null);
    when(mockStorage.getEcoModeEnabled()).thenAnswer((_) async => false);
    when(mockStorage.getGpsFilterMode()).thenAnswer((_) async => null);
    when(mockStorage.getAllowInsecureTls()).thenAnswer((_) async => false);
    when(mockStorage.isAuthenticated()).thenAnswer((_) async => false);

    when(mockLocation.setEcoMode(any)).thenAnswer((_) async {});
    when(mockAudio.setVolume(any)).thenAnswer((_) async {});
    when(
      mockAudio.updateSettings(
        enabled: anyNamed('enabled'),
        announceSplits: anyNamed('announceSplits'),
        announceStart: anyNamed('announceStart'),
        announceGps: anyNamed('announceGps'),
      ),
    ).thenAnswer((_) async {});
    when(mockAudio.isEnabled).thenReturn(true);
    when(mockAudio.enabledStream).thenAnswer((_) => const Stream<bool>.empty());

    await serviceLocator.reset();
    serviceLocator.registerSingleton<AuthService>(mockAuth);
    serviceLocator.registerSingleton<SecureStorageService>(mockStorage);
    serviceLocator.registerSingleton<ErrorHandlerService>(mockError);
    serviceLocator.registerSingleton<AudioFeedbackService>(mockAudio);
    serviceLocator.registerSingleton<LocationService>(mockLocation);
    serviceLocator.registerSingleton<AppDatabase>(mockDatabase);
    serviceLocator.registerSingleton<LoginController>(mockLoginController);
  });

  testWidgets(
    'App startet ohne Pflicht-Login in einen nutzbaren Shell-Zustand',
    (WidgetTester tester) async {
      final settingsController = SettingsController(
        mockStorage,
        mockAudio,
        mockLocation,
      );
      await settingsController.init();

      serviceLocator.registerSingleton<SettingsController>(settingsController);

      // Build app and allow initial routing to complete.
      await tester.pumpWidget(const App());
      var scaffoldVisible = find.byType(Scaffold).evaluate().isNotEmpty;
      for (var i = 0; i < 20 && !scaffoldVisible; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        scaffoldVisible = find.byType(Scaffold).evaluate().isNotEmpty;
      }
      expect(scaffoldVisible, isTrue);
    },
  );
}
