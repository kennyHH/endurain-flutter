import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/models/gps_filter_mode.dart';
import 'package:endurain/core/models/route_display_mode.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/services/activity_upload_service.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:endurain/features/history/activity_history_screen.dart';
import 'package:endurain/features/map/map_screen.dart';
import 'package:endurain/features/settings/settings_screen.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/core/constants/ui_constants.dart';
import 'package:endurain/core/theme/app_theme.dart';

class AppBottomNav extends StatefulWidget {
  const AppBottomNav({
    super.key,
    this.onLogout,
    required this.themeMode,
    required this.highContrast,
    this.onThemeModeChanged,
    this.onHighContrastChanged,
    required this.routeDisplayMode,
    this.onRouteDisplayModeChanged,
    required this.gpsFilterMode,
    this.onGpsFilterModeChanged,
    required this.allowInsecureTls,
    this.onAllowInsecureTlsChanged,
    required this.selectedThemePreset,
    this.onThemePresetChanged,
  });

  final VoidCallback? onLogout;
  final ThemeMode themeMode;
  final bool highContrast;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<bool>? onHighContrastChanged;
  final RouteDisplayMode routeDisplayMode;
  final ValueChanged<RouteDisplayMode>? onRouteDisplayModeChanged;
  final GpsFilterMode gpsFilterMode;
  final ValueChanged<GpsFilterMode>? onGpsFilterModeChanged;
  final bool allowInsecureTls;
  final ValueChanged<bool>? onAllowInsecureTlsChanged;
  final AppThemePreset selectedThemePreset;
  final ValueChanged<AppThemePreset>? onThemePresetChanged;

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  int _currentIndex = 0;
  late final ActivityRepository _activityRepository;
  late final TrackingSessionEngine _trackingSessionEngine;
  late final ActivityUploadService _activityUploadService;
  StreamSubscription<List<Activity>>? _activityWatchSubscription;
  ActivityType? _lastActivityType;

  @override
  void initState() {
    super.initState();
    _activityRepository = PersistentActivityRepository();
    _trackingSessionEngine = TrackingSessionEngine(
      repository: _activityRepository,
      positionStreamProvider: LocationServicePositionStreamProvider(
        LocationService(),
      ),
      gpsFilterMode: widget.gpsFilterMode,
    );
    _activityUploadService = ActivityUploadService();
    _activityWatchSubscription = _activityRepository.watchAll().listen((items) {
      final latestCompleted = items.where((item) => item.endedAt != null).toList()
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
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gpsFilterMode != widget.gpsFilterMode) {
      _trackingSessionEngine.setGpsFilterMode(widget.gpsFilterMode);
    }
  }

  List<Widget> get _screens => [
    MapScreen(
      trackingSessionEngine: _trackingSessionEngine,
      uploadService: _activityUploadService,
      routeDisplayMode: widget.routeDisplayMode,
      gpsFilterMode: widget.gpsFilterMode,
      suggestedActivityType: _lastActivityType,
      onUploadFinished: (activity, success) async {
        final stored = await _activityRepository.getById(activity.id);
        if (stored == null) return;
        await _activityRepository.update(stored.copyWith(uploaded: success));
      },
    ),
    ActivityHistoryScreen(
      repository: _activityRepository,
      routeDisplayMode: widget.routeDisplayMode,
      onStartFirstActivity: () {
        setState(() {
          _currentIndex = 0;
        });
      },
      onDeleteActivity: (activity) async {
        if (activity.uploaded) {
          final result = await _activityUploadService.deleteActivity(activity);
          if (!result.success) {
            return result.serverDetail ??
                'Server deletion failed. Activity was not removed locally.';
          }
        }
        await _activityRepository.delete(activity.id);
        return null;
      },
      onRetryUpload: (activity) async {
        final result = await _activityUploadService.uploadActivity(activity);
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
      onLogout: widget.onLogout,
      selectedThemeMode: widget.themeMode,
      highContrast: widget.highContrast,
      onThemeModeChanged: widget.onThemeModeChanged,
      onHighContrastChanged: widget.onHighContrastChanged,
      routeDisplayMode: widget.routeDisplayMode,
      onRouteDisplayModeChanged: widget.onRouteDisplayModeChanged,
      gpsFilterMode: widget.gpsFilterMode,
      onGpsFilterModeChanged: widget.onGpsFilterModeChanged,
      selectedThemePreset: widget.selectedThemePreset,
      onThemePresetChanged: widget.onThemePresetChanged,
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
