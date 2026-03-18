import 'dart:async';

import 'package:flutter/material.dart';
import 'package:endurain/core/di/service_locator.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/audio_feedback_service.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/power_management_service.dart';
import 'package:endurain/core/constants/ui_constants.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:injectable/injectable.dart';
import 'package:endurain/core/models/gps_filter_mode.dart';
import 'package:endurain/core/models/route_display_mode.dart';
import 'package:endurain/core/models/dynamic_map_zoom_preset.dart';
import 'package:endurain/core/theme/app_theme.dart';
import 'package:endurain/core/network/endurain_http_overrides.dart';

const _forceUnlockForE2E = bool.fromEnvironment(
  'ENDURAIN_E2E_BYPASS_LOCK',
  defaultValue: false,
);

@singleton
class SettingsController extends ChangeNotifier {
  SettingsController(this._storage, this._audioService, this._locationService) {
    _audioEnabledSubscription = _audioService.enabledStream.listen((enabled) {
      if (_audioEnabled == enabled) return;
      _audioEnabled = enabled;
      notifyListeners();
    });
  }

  final SecureStorageService _storage;
  final AudioFeedbackService _audioService;
  final LocationService _locationService;
  StreamSubscription<bool>? _audioEnabledSubscription;
  PowerManagementService? _powerManagementService;

  PowerManagementService get _resolvedPowerManagementService {
    final existing = _powerManagementService;
    if (existing != null) {
      return existing;
    }
    if (serviceLocator.isRegistered<PowerManagementService>()) {
      final fromLocator = serviceLocator<PowerManagementService>();
      _powerManagementService = fromLocator;
      return fromLocator;
    }
    final fallback = PowerManagementService();
    _powerManagementService = fallback;
    return fallback;
  }

  // State
  String _version = '';
  String _buildInfo = '';
  String _copyright = '';
  bool _audioEnabled = true;
  double _voiceVolume = 0.8;
  bool _announceStart = true;
  bool _announceSplits = true;
  bool _announceGps = true;
  bool _dynamicMapZoomEnabled = true;
  DynamicMapZoomPreset _dynamicMapZoomPreset = DynamicMapZoomPreset.balanced;

  // Theme & Appearance
  ThemeMode _themeMode = ThemeMode.system;
  bool _highContrast = true;
  AppThemePreset _themePreset = AppThemePreset.slate;
  RouteDisplayMode _routeDisplayMode = RouteDisplayMode.auto;

  // System & Sensors
  bool _ecoModeEnabled = false;
  GpsFilterMode _gpsFilterMode = GpsFilterMode.auto;
  bool _allowInsecureTls = false;
  bool _batteryOptimizationIgnored = true;

  // Session State
  bool _isUnlocked = false;

  // Getters
  String get version => _version;
  String get buildInfo => _buildInfo;
  String get copyright => _copyright;
  bool get audioEnabled => _audioEnabled;
  double get voiceVolume => _voiceVolume;
  bool get announceStart => _announceStart;
  bool get announceSplits => _announceSplits;
  bool get announceGps => _announceGps;
  bool get dynamicMapZoomEnabled => _dynamicMapZoomEnabled;
  DynamicMapZoomPreset get dynamicMapZoomPreset => _dynamicMapZoomPreset;

  ThemeMode get themeMode => _themeMode;
  bool get highContrast => _highContrast;
  AppThemePreset get themePreset => _themePreset;
  RouteDisplayMode get routeDisplayMode => _routeDisplayMode;
  bool get ecoModeEnabled => _ecoModeEnabled;
  GpsFilterMode get gpsFilterMode => _gpsFilterMode;
  bool get allowInsecureTls => _allowInsecureTls;
  bool get batteryOptimizationIgnored => _batteryOptimizationIgnored;
  bool get supportsBatteryOptimizationControl => PlatformUtils.isAndroid;
  bool get isUnlocked => _isUnlocked;

  void unlock() {
    _isUnlocked = true;
    notifyListeners();
  }

  // Init
  Future<void> init() async {
    await _loadSettings();
    await _loadVersion();
    await refreshAudioState();
  }

  Future<void> _loadSettings() async {
    // Audio
    final enabledRaw = await _storage.read(key: 'audio_enabled');
    _audioEnabled = enabledRaw == null ? true : enabledRaw == 'true';
    _audioService.toggleEnabled(_audioEnabled);

    final storedVolumeRaw = await _storage.read(key: 'audio_volume');
    if (storedVolumeRaw != null) {
      _voiceVolume = (double.tryParse(storedVolumeRaw) ?? 0.8).clamp(0.0, 1.0);
    } else {
      _voiceVolume = 0.8;
      await _storage.write(key: 'audio_volume', value: _voiceVolume.toString());
    }
    final announceStartRaw = await _storage.read(key: 'audio_announce_start');
    _announceStart = announceStartRaw == null
        ? true
        : announceStartRaw == 'true';
    final announceSplitsRaw = await _storage.read(key: 'audio_announce_splits');
    _announceSplits = announceSplitsRaw == null
        ? true
        : announceSplitsRaw == 'true';
    final announceGpsRaw = await _storage.read(key: 'audio_announce_gps');
    _announceGps = announceGpsRaw == null ? true : announceGpsRaw == 'true';
    final dynamicZoomRaw = await _storage.read(key: 'dynamic_map_zoom_enabled');
    _dynamicMapZoomEnabled = dynamicZoomRaw == null
        ? true
        : dynamicZoomRaw == 'true';
    final dynamicZoomPresetRaw = await _storage.read(
      key: 'dynamic_map_zoom_preset',
    );
    _dynamicMapZoomPreset = dynamicMapZoomPresetFromStorage(
      dynamicZoomPresetRaw,
    );
    await _audioService.updateSettings(
      enabled: _audioEnabled,
      announceSplits: _announceSplits,
      announceStart: _announceStart,
      announceGps: _announceGps,
    );
    await _audioService.setVolume(_voiceVolume);

    // Theme
    final savedThemeMode = await _storage.getThemeMode();
    _themeMode = _themeModeFromStorage(savedThemeMode);

    _highContrast = true;

    final savedThemePreset = await _storage.getThemePreset();
    _themePreset = _themePresetFromStorage(savedThemePreset);

    // Display
    final savedRouteMode = await _storage.getRouteDisplayMode();
    _routeDisplayMode = routeDisplayModeFromStorage(savedRouteMode);

    // System
    _ecoModeEnabled = await _storage.getEcoModeEnabled();
    _locationService.setEcoMode(_ecoModeEnabled);

    final savedGpsMode = await _storage.getGpsFilterMode();
    _gpsFilterMode = gpsFilterModeFromStorage(savedGpsMode);

    _allowInsecureTls = await _storage.getAllowInsecureTls();
    EndurainHttpOverrides.allowInsecureTls = _allowInsecureTls;

    _isUnlocked = _forceUnlockForE2E;
    await refreshBatteryOptimizationStatus(notify: false);

    notifyListeners();
  }

  Future<void> refreshAudioState({bool notify = true}) async {
    final enabledRaw = await _storage.read(key: 'audio_enabled');
    _audioEnabled = enabledRaw == null ? true : enabledRaw == 'true';
    final storedVolumeRaw = await _storage.read(key: 'audio_volume');
    if (storedVolumeRaw != null) {
      _voiceVolume = (double.tryParse(storedVolumeRaw) ?? 0.8).clamp(0.0, 1.0);
    }
    final announceStartRaw = await _storage.read(key: 'audio_announce_start');
    _announceStart = announceStartRaw == null
        ? true
        : announceStartRaw == 'true';
    final announceSplitsRaw = await _storage.read(key: 'audio_announce_splits');
    _announceSplits = announceSplitsRaw == null
        ? true
        : announceSplitsRaw == 'true';
    final announceGpsRaw = await _storage.read(key: 'audio_announce_gps');
    _announceGps = announceGpsRaw == null ? true : announceGpsRaw == 'true';
    final dynamicZoomRaw = await _storage.read(key: 'dynamic_map_zoom_enabled');
    _dynamicMapZoomEnabled = dynamicZoomRaw == null
        ? true
        : dynamicZoomRaw == 'true';
    final dynamicZoomPresetRaw = await _storage.read(
      key: 'dynamic_map_zoom_preset',
    );
    _dynamicMapZoomPreset = dynamicMapZoomPresetFromStorage(
      dynamicZoomPresetRaw,
    );
    await _audioService.updateSettings(
      enabled: _audioEnabled,
      announceSplits: _announceSplits,
      announceStart: _announceStart,
      announceGps: _announceGps,
    );
    await _audioService.setVolume(_voiceVolume);
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentYear = DateTime.now().year;

    const buildDate = String.fromEnvironment(
      'BUILD_DATE',
      defaultValue: 'local',
    );
    const gitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'dev');

    _version = '${packageInfo.version} (${packageInfo.buildNumber})';
    _buildInfo = 'Build $buildDate • $gitSha';
    _copyright = '© ${UIConstants.copyrightStartYear} - $currentYear Endurain';
    notifyListeners();
  }

  // Actions
  Future<void> setVoiceVolume(double value) async {
    _voiceVolume = value.clamp(0.0, 1.0);
    notifyListeners();

    await _storage.write(key: 'audio_volume', value: _voiceVolume.toString());
    await _audioService.setVolume(_voiceVolume);
  }

  void toggleAudio(bool value) {
    _audioEnabled = value;
    unawaited(_audioService.setEnabledWithAnnouncement(_audioEnabled));
    notifyListeners();
  }

  Future<void> setAnnounceStart(bool value) async {
    _announceStart = value;
    notifyListeners();
    await _storage.write(key: 'audio_announce_start', value: value.toString());
    await _audioService.updateSettings(
      enabled: _audioEnabled,
      announceSplits: _announceSplits,
      announceStart: _announceStart,
      announceGps: _announceGps,
    );
  }

  Future<void> setAnnounceSplits(bool value) async {
    _announceSplits = value;
    notifyListeners();
    await _storage.write(key: 'audio_announce_splits', value: value.toString());
    await _audioService.updateSettings(
      enabled: _audioEnabled,
      announceSplits: _announceSplits,
      announceStart: _announceStart,
      announceGps: _announceGps,
    );
  }

  Future<void> setAnnounceGps(bool value) async {
    _announceGps = value;
    notifyListeners();
    await _storage.write(key: 'audio_announce_gps', value: value.toString());
    await _audioService.updateSettings(
      enabled: _audioEnabled,
      announceSplits: _announceSplits,
      announceStart: _announceStart,
      announceGps: _announceGps,
    );
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _isUnlocked = false;
    notifyListeners();
  }

  // Setters for new settings
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _storage.setThemeMode(_themeModeToStorage(mode));
  }

  Future<void> setHighContrast(bool enabled) async {
    if (_highContrast) return;
    _highContrast = true;
    notifyListeners();
    await _storage.setHighContrast(true);
  }

  Future<void> setThemePreset(AppThemePreset preset) async {
    if (_themePreset == preset) return;
    _themePreset = preset;
    notifyListeners();
    await _storage.setThemePreset(_themePresetToStorage(preset));
  }

  Future<void> setRouteDisplayMode(RouteDisplayMode mode) async {
    if (_routeDisplayMode == mode) return;
    _routeDisplayMode = mode;
    notifyListeners();
    await _storage.setRouteDisplayMode(routeDisplayModeToStorage(mode));
  }

  Future<void> setEcoMode(bool enabled) async {
    if (_ecoModeEnabled == enabled) return;
    _ecoModeEnabled = enabled;
    _locationService.setEcoMode(enabled);
    notifyListeners();
    await _storage.setEcoModeEnabled(enabled);
  }

  Future<void> setGpsFilterMode(GpsFilterMode mode) async {
    if (_gpsFilterMode == mode) return;
    _gpsFilterMode = mode;
    notifyListeners();
    await _storage.setGpsFilterMode(gpsFilterModeToStorage(mode));
  }

  Future<void> setDynamicMapZoomEnabled(bool enabled) async {
    if (_dynamicMapZoomEnabled == enabled) return;
    _dynamicMapZoomEnabled = enabled;
    notifyListeners();
    await _storage.write(
      key: 'dynamic_map_zoom_enabled',
      value: enabled.toString(),
    );
  }

  Future<void> setDynamicMapZoomPreset(DynamicMapZoomPreset preset) async {
    if (_dynamicMapZoomPreset == preset) return;
    _dynamicMapZoomPreset = preset;
    notifyListeners();
    await _storage.write(
      key: 'dynamic_map_zoom_preset',
      value: dynamicMapZoomPresetToStorage(preset),
    );
  }

  Future<void> setAllowInsecureTls(bool enabled) async {
    if (_allowInsecureTls == enabled) return;
    _allowInsecureTls = enabled;
    EndurainHttpOverrides.allowInsecureTls = enabled;
    notifyListeners();
    await _storage.setAllowInsecureTls(enabled);
  }

  Future<void> refreshBatteryOptimizationStatus({bool notify = true}) async {
    if (!supportsBatteryOptimizationControl) {
      _batteryOptimizationIgnored = true;
      if (notify) {
        notifyListeners();
      }
      return;
    }

    _batteryOptimizationIgnored = await _resolvedPowerManagementService
        .isBatteryOptimizationIgnored();
    if (notify) {
      notifyListeners();
    }
  }

  Future<bool> requestBatteryExemption() async {
    if (!supportsBatteryOptimizationControl) return true;
    final granted = await _resolvedPowerManagementService
        .requestBatteryExemption();
    await refreshBatteryOptimizationStatus(notify: false);
    notifyListeners();
    return granted && _batteryOptimizationIgnored;
  }

  // Helpers
  ThemeMode _themeModeFromStorage(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToStorage(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  AppThemePreset _themePresetFromStorage(String? value) {
    switch (value) {
      case 'ocean':
        return AppThemePreset.ocean;
      case 'forest':
        return AppThemePreset.forest;
      case 'slate':
        return AppThemePreset.slate;
      case 'twilight':
        return AppThemePreset.twilight;
      case 'ember':
        return AppThemePreset.ember;
      case 'berry':
        return AppThemePreset.berry;
      default:
        return AppThemePreset.slate;
    }
  }

  String _themePresetToStorage(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.ocean:
        return 'ocean';
      case AppThemePreset.forest:
        return 'forest';
      case AppThemePreset.slate:
        return 'slate';
      case AppThemePreset.twilight:
        return 'twilight';
      case AppThemePreset.ember:
        return 'ember';
      case AppThemePreset.berry:
        return 'berry';
    }
  }

  @override
  void dispose() {
    _audioEnabledSubscription?.cancel();
    super.dispose();
  }
}
