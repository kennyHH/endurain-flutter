import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/models/activity.dart' as model;
import 'package:endurain/core/models/gps_filter_mode.dart';
import 'package:endurain/core/models/route_display_mode.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/services/activity_upload_service.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:endurain/core/services/bluetooth_sensor_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/di/service_locator.dart';
import 'package:endurain/features/history/activity_history_screen.dart';
import 'package:endurain/features/map/map_screen.dart';
import 'package:endurain/features/settings/settings_screen.dart';
import 'package:endurain/features/auth/login_screen.dart';
import 'package:endurain/core/constants/ui_constants.dart';
import 'package:endurain/core/database/app_database.dart';
import 'package:endurain/core/theme/app_theme.dart';
import 'package:endurain/core/utils/platform_utils.dart';

class AppBottomNav extends StatefulWidget {
  const AppBottomNav({
    super.key,
    required this.database,
    this.onLogout,
    required this.themeMode,
    this.onThemeModeChanged,
    required this.routeDisplayMode,
    this.onRouteDisplayModeChanged,
    required this.gpsFilterMode,
    this.onGpsFilterModeChanged,
    required this.allowInsecureTls,
    this.onAllowInsecureTlsChanged,
    required this.selectedThemePreset,
    this.onThemePresetChanged,
    this.ecoModeEnabled = false,
    this.onEcoModeChanged,
  });

  final VoidCallback? onLogout;
  final ThemeMode themeMode;
  final bool ecoModeEnabled;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<bool>? onEcoModeChanged;
  final RouteDisplayMode routeDisplayMode;
  final ValueChanged<RouteDisplayMode>? onRouteDisplayModeChanged;
  final GpsFilterMode gpsFilterMode;
  final ValueChanged<GpsFilterMode>? onGpsFilterModeChanged;
  final bool allowInsecureTls;
  final ValueChanged<bool>? onAllowInsecureTlsChanged;
  final AppThemePreset selectedThemePreset;
  final ValueChanged<AppThemePreset>? onThemePresetChanged;

  final AppDatabase database;

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  int _currentIndex = 0;
  bool _focusBatteryOptimizationSettings = false;
  late final ActivityRepository _activityRepository;
  late final TrackingSessionEngine _trackingSessionEngine;
  late final ActivityUploadService _activityUploadService;
  late final BluetoothSensorService _bluetoothSensorService;
  late final SecureStorageService _secureStorageService;
  StreamSubscription<List<model.Activity>>? _activityWatchSubscription;
  model.ActivityType? _lastActivityType;
  bool _isServerConnected = false;

  @override
  void initState() {
    super.initState();
    _activityRepository = serviceLocator<ActivityRepository>();
    _bluetoothSensorService = serviceLocator<BluetoothSensorService>();
    // _bluetoothSensorService.init(); // Fire and forget initialization - assuming DI handles init or it's lazy

    _trackingSessionEngine = serviceLocator<TrackingSessionEngine>();
    _activityUploadService = serviceLocator<ActivityUploadService>();
    _secureStorageService = serviceLocator<SecureStorageService>();
    unawaited(_refreshServerConnectionStatus());

    _activityWatchSubscription = _activityRepository.watchAll().listen((items) {
      final latestCompleted =
          items.where((item) => item.endedAt != null).toList()
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      final nextType = latestCompleted.isEmpty
          ? null
          : latestCompleted.first.activityType;
      if (nextType == _lastActivityType || !mounted) return;
      setState(() {
        _lastActivityType = nextType;
      });
    });
  }

  @override
  void dispose() {
    _activityWatchSubscription?.cancel();
    _trackingSessionEngine.dispose();
    _bluetoothSensorService.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gpsFilterMode != widget.gpsFilterMode) {
      _trackingSessionEngine.setGpsFilterMode(widget.gpsFilterMode);
    }
  }

  Future<void> _refreshServerConnectionStatus() async {
    final tokenAvailable = await _secureStorageService.isAuthenticated();
    final serverUrl = await _secureStorageService.getServerUrl();
    final connected = tokenAvailable && (serverUrl?.isNotEmpty ?? false);
    if (!mounted || connected == _isServerConnected) return;
    setState(() {
      _isServerConnected = connected;
    });
  }

  Future<bool> _showConnectAndUploadPrompt() async {
    final l10n = AppLocalizations.of(context)!;
    if (PlatformUtils.isApplePlatform) {
      final action = await showCupertinoModalPopup<String>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Text(l10n.connectUploadTitle),
          message: Text(l10n.connectUploadMessage),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('connect'),
              child: Text(l10n.connectUploadAction),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: Text(l10n.cancel),
          ),
        ),
      );
      return action == 'connect';
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.connectUploadTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(l10n.connectUploadMessage),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop('connect'),
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: Text(l10n.connectUploadAction),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop('cancel'),
                  child: Text(l10n.cancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return action == 'connect';
  }

  Future<void> _openServerLogin() async {
    if (!mounted) return;
    final shouldLogin = await _showConnectAndUploadPrompt();
    if (!mounted || !shouldLogin) return;
    if (PlatformUtils.isApplePlatform) {
      await Navigator.of(context).push<bool>(
        CupertinoPageRoute<bool>(
          builder: (context) => LoginScreen(
            onLoginSuccess: () => Navigator.of(context).pop(true),
          ),
        ),
      );
      await _refreshServerConnectionStatus();
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) =>
            LoginScreen(onLoginSuccess: () => Navigator.of(context).pop(true)),
      ),
    );
    await _refreshServerConnectionStatus();
  }

  Future<ActivityUploadResult> _uploadWithOnDemandLogin(
    model.Activity activity,
  ) async {
    var result = await _activityUploadService.uploadActivity(activity);
    if (result.success ||
        result.failureType != ActivityUploadFailureType.authentication) {
      return result;
    }
    await _openServerLogin();
    result = await _activityUploadService.uploadActivity(activity);
    return result;
  }

  Future<ActivityUploadResult> _deleteOnServerWithOnDemandLogin(
    model.Activity activity,
  ) async {
    var result = await _activityUploadService.deleteActivity(activity);
    if (result.success ||
        result.failureType != ActivityUploadFailureType.authentication) {
      return result;
    }
    await _openServerLogin();
    result = await _activityUploadService.deleteActivity(activity);
    return result;
  }

  List<Widget> get _screens => [
    MapScreen(
      trackingSessionEngine: _trackingSessionEngine,
      uploadService: _activityUploadService,
      routeDisplayMode: widget.routeDisplayMode,
      gpsFilterMode: widget.gpsFilterMode,
      suggestedActivityType: _lastActivityType,
      onOpenBatteryOptimizationSettings: () {
        setState(() {
          _currentIndex = 2;
          _focusBatteryOptimizationSettings = true;
        });
      },
      onAuthRequired: _openServerLogin,
      onUploadFinished: (activity, success) async {
        final stored = await _activityRepository.getById(activity.id);
        if (stored == null) return;
        await _activityRepository.update(stored.copyWith(uploaded: success));
      },
    ),
    ActivityHistoryScreen(
      repository: _activityRepository,
      routeDisplayMode: widget.routeDisplayMode,
      onAuthRequired: _openServerLogin,
      isServerConnected: _isServerConnected,
      onStartFirstActivity: () {
        setState(() {
          _currentIndex = 0;
        });
      },
      onDeleteActivity: (activity) async {
        if (activity.uploaded) {
          final result = await _deleteOnServerWithOnDemandLogin(activity);
          if (!result.success) {
            return result.serverDetail ??
                'Server deletion failed. Activity was not removed locally.';
          }
        }
        await _activityRepository.delete(activity.id);
        return null;
      },
      onRetryUpload: (activity) async {
        final result = await _uploadWithOnDemandLogin(activity);
        if (result.success) {
          final stored = await _activityRepository.getById(activity.id);
          if (stored != null) {
            await _activityRepository.update(stored.copyWith(uploaded: true));
          }
        }
        return result;
      },
    ),
    SettingsScreen(
      onLogout: () {
        widget.onLogout?.call();
        unawaited(_refreshServerConnectionStatus());
      },
      onOpenServerLogin: _openServerLogin,
      isServerConnected: _isServerConnected,
      selectedThemeMode: widget.themeMode,
      ecoModeEnabled: widget.ecoModeEnabled,
      onThemeModeChanged: widget.onThemeModeChanged,
      onEcoModeChanged: widget.onEcoModeChanged,
      routeDisplayMode: widget.routeDisplayMode,
      onRouteDisplayModeChanged: widget.onRouteDisplayModeChanged,
      gpsFilterMode: widget.gpsFilterMode,
      onGpsFilterModeChanged: widget.onGpsFilterModeChanged,
      selectedThemePreset: widget.selectedThemePreset,
      onThemePresetChanged: widget.onThemePresetChanged,
      bluetoothService: _bluetoothSensorService,
      focusBatteryOptimization: _focusBatteryOptimizationSettings,
      onBatteryFocusHandled: () {
        if (!_focusBatteryOptimizationSettings) return;
        setState(() {
          _focusBatteryOptimizationSettings = false;
        });
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Use Cupertino tab bar on iOS/macOS
    if (PlatformUtils.isApplePlatform) {
      return CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          height: UIConstants.tabBarHeight,
          iconSize: 26,
          items: [
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(top: UIConstants.paddingSmall),
                child: Icon(CupertinoIcons.map, size: 26),
              ),
              label: l10n.mapTab,
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(top: UIConstants.paddingSmall),
                child: Icon(CupertinoIcons.clock, size: 26),
              ),
              label: l10n.historyTab,
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(top: UIConstants.paddingSmall),
                child: Icon(CupertinoIcons.settings, size: 26),
              ),
              label: l10n.settingsTab,
            ),
          ],
        ),
        tabBuilder: (context, index) {
          return CupertinoTabView(builder: (context) => _screens[index]);
        },
      );
    }

    // Use Material bottom navigation on Android
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        iconSize: 28,
        selectedFontSize: 13,
        unselectedFontSize: 12,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined, size: 28),
            label: l10n.mapTab,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history_outlined, size: 28),
            label: l10n.historyTab,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined, size: 28),
            label: l10n.settingsTab,
          ),
        ],
      ),
    );
  }
}
