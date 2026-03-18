import 'dart:async';

import 'package:endurain/features/settings/controllers/settings_controller.dart';
import 'package:endurain/core/di/service_locator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/features/settings/server_settings_screen.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/core/theme/app_theme.dart';
import 'package:endurain/core/models/gps_filter_mode.dart';
import 'package:endurain/core/models/route_display_mode.dart';
import 'package:endurain/core/models/dynamic_map_zoom_preset.dart';
import 'package:endurain/features/settings/sensor_settings_screen.dart';
import 'package:endurain/core/services/bluetooth_sensor_service.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/power_management_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/utils/dialog_utils.dart';
import 'package:endurain/core/utils/error_mapper.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.onLogout,
    required this.selectedThemeMode,
    this.ecoModeEnabled = false,
    required this.routeDisplayMode,
    required this.gpsFilterMode,
    required this.selectedThemePreset,

    this.onThemeModeChanged,
    this.onRouteDisplayModeChanged,
    this.onGpsFilterModeChanged,
    this.onThemePresetChanged,
    this.onEcoModeChanged,
    required this.bluetoothService,
    this.settingsController, // Allow injection for testing
    this.focusBatteryOptimization = false,
    this.onBatteryFocusHandled,
    this.onOpenServerLogin,
    this.isServerConnected = false,
  });

  final VoidCallback? onLogout;
  final ThemeMode selectedThemeMode;
  final bool ecoModeEnabled;
  final RouteDisplayMode routeDisplayMode;
  final GpsFilterMode gpsFilterMode;
  final AppThemePreset selectedThemePreset;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<bool>? onEcoModeChanged;
  final ValueChanged<RouteDisplayMode>? onRouteDisplayModeChanged;
  final ValueChanged<GpsFilterMode>? onGpsFilterModeChanged;
  final ValueChanged<AppThemePreset>? onThemePresetChanged;
  final BluetoothSensorService bluetoothService;
  final SettingsController? settingsController;
  final bool focusBatteryOptimization;
  final VoidCallback? onBatteryFocusHandled;
  final Future<void> Function()? onOpenServerLogin;
  final bool isServerConnected;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _controller;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _batteryTileKey = GlobalKey();
  bool _highlightBatteryTile = false;
  bool _expandedTracking = false;
  bool _expandedDisplay = false;
  bool _expandedDeviceSensors = false;
  bool _expandedServerSync = false;

  @override
  void initState() {
    super.initState();
    // Do NOT create a new controller if we are using the singleton
    _controller =
        widget.settingsController ?? serviceLocator<SettingsController>();
    // Do NOT call _controller.init() here!
    // The singleton is already initialized in App.dart or on first access.
    // Calling init() again might reset values or cause flickering.
    // Also, _controller.dispose() in dispose() is dangerous for a Singleton!
    if (widget.focusBatteryOptimization) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusBatteryOptimizationTile();
      });
    }
    unawaited(_controller.refreshAudioState());
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusBatteryOptimization &&
        !oldWidget.focusBatteryOptimization) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusBatteryOptimizationTile();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // DO NOT dispose a Singleton controller!
    // It must live as long as the app lives.
    super.dispose();
  }

  Future<void> _focusBatteryOptimizationTile() async {
    setState(() {
      _expandedDeviceSensors = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final tileContext = _batteryTileKey.currentContext;
      if (tileContext == null) return;
      await Scrollable.ensureVisible(
        tileContext,
        duration: const Duration(milliseconds: 280),
        alignment: 0.2,
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
      setState(() {
        _highlightBatteryTile = true;
      });
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          _highlightBatteryTile = false;
        });
      });
      widget.onBatteryFocusHandled?.call();
    });
  }

  Future<ThemeMode?> _pickThemeMode(AppLocalizations l10n) async {
    final options = {
      ThemeMode.system: l10n.settingsThemeSystem,
      ThemeMode.light: l10n.settingsThemeLight,
      ThemeMode.dark: l10n.settingsThemeDark,
    };
    if (PlatformUtils.isApplePlatform) {
      final selected = await showCupertinoModalPopup<ThemeMode>(
        context: context,
        builder: (context) {
          return CupertinoActionSheet(
            title: Text(l10n.settingsThemeMode),
            actions: options.entries
                .map(
                  (entry) => CupertinoActionSheetAction(
                    onPressed: () => Navigator.of(context).pop(entry.key),
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          );
        },
      );
      if (selected != null) {
        await _controller.setThemeMode(selected);
      }
      return selected;
    }

    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.entries
                .map(
                  (entry) => ListTile(
                    title: Text(entry.value),
                    trailing: _controller.themeMode == entry.key
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(context).pop(entry.key),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (selected != null) {
      await _controller.setThemeMode(selected);
    }
    return selected;
  }

  Future<AppThemePreset?> _pickThemePreset(AppLocalizations l10n) async {
    final options = {
      AppThemePreset.slate: 'Slate',
      AppThemePreset.ocean: l10n.settingsThemePresetOcean,
      AppThemePreset.forest: 'Forest', // TODO: Localize
      AppThemePreset.twilight: 'Twilight', // TODO: Localize
      AppThemePreset.ember: 'Ember', // TODO: Localize
      AppThemePreset.berry: 'Berry', // TODO: Localize
    };
    if (PlatformUtils.isApplePlatform) {
      final selected = await showCupertinoModalPopup<AppThemePreset>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Text(l10n.settingsThemePreset),
          actions: options.entries
              .map(
                (entry) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(context).pop(entry.key),
                  child: Text(entry.value),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ),
      );
      if (selected != null) {
        await _controller.setThemePreset(selected);
      }
      return selected;
    }
    final selected = await showModalBottomSheet<AppThemePreset>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.entries
              .map(
                (entry) => ListTile(
                  title: Text(entry.value),
                  trailing: _controller.themePreset == entry.key
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(context).pop(entry.key),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      await _controller.setThemePreset(selected);
    }
    return selected;
  }

  String _themeModeLabel(AppLocalizations l10n, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return l10n.settingsThemeLight;
      case ThemeMode.dark:
        return l10n.settingsThemeDark;
      case ThemeMode.system:
        return l10n.settingsThemeSystem;
    }
  }

  String _themePresetLabel(AppLocalizations l10n, AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.ocean:
        return l10n.settingsThemePresetOcean;
      case AppThemePreset.forest:
        return l10n.settingsThemePresetForest;
      case AppThemePreset.slate:
        return 'Slate';
      case AppThemePreset.twilight:
        return 'Twilight';
      case AppThemePreset.ember:
        return 'Ember';
      case AppThemePreset.berry:
        return 'Berry';
    }
  }

  Future<RouteDisplayMode?> _pickRouteDisplayMode(AppLocalizations l10n) async {
    final options = {
      RouteDisplayMode.auto: l10n.settingsRouteDisplayModeAuto,
      RouteDisplayMode.matched: l10n.settingsRouteDisplayModeMatched,
      RouteDisplayMode.raw: l10n.settingsRouteDisplayModeRaw,
    };
    if (PlatformUtils.isApplePlatform) {
      final selected = await showCupertinoModalPopup<RouteDisplayMode>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Text(l10n.settingsRouteDisplayModeTitle),
          actions: options.entries
              .map(
                (entry) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(context).pop(entry.key),
                  child: Text(entry.value),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ),
      );
      if (selected != null) {
        await _controller.setRouteDisplayMode(selected);
      }
      return selected;
    }
    final selected = await showModalBottomSheet<RouteDisplayMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.entries
              .map(
                (entry) => ListTile(
                  title: Text(entry.value),
                  trailing: _controller.routeDisplayMode == entry.key
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(context).pop(entry.key),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      await _controller.setRouteDisplayMode(selected);
    }
    return selected;
  }

  String _routeDisplayModeLabel(AppLocalizations l10n, RouteDisplayMode mode) {
    switch (mode) {
      case RouteDisplayMode.auto:
        return l10n.settingsRouteDisplayModeAuto;
      case RouteDisplayMode.matched:
        return l10n.settingsRouteDisplayModeMatched;
      case RouteDisplayMode.raw:
        return l10n.settingsRouteDisplayModeRaw;
    }
  }

  Future<GpsFilterMode?> _pickGpsFilterMode(AppLocalizations l10n) async {
    final options = {
      GpsFilterMode.auto: l10n.settingsGpsFilterModeAuto,
      GpsFilterMode.normal: l10n.settingsGpsFilterModeNormal,
      GpsFilterMode.strict: l10n.settingsGpsFilterModeStrict,
    };
    if (PlatformUtils.isApplePlatform) {
      final selected = await showCupertinoModalPopup<GpsFilterMode>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Text(l10n.settingsGpsFilterModeTitle),
          actions: options.entries
              .map(
                (entry) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(context).pop(entry.key),
                  child: Text(entry.value),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ),
      );
      if (selected != null) {
        await _controller.setGpsFilterMode(selected);
      }
      return selected;
    }
    final selected = await showModalBottomSheet<GpsFilterMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.entries
              .map(
                (entry) => ListTile(
                  title: Text(entry.value),
                  trailing: _controller.gpsFilterMode == entry.key
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(context).pop(entry.key),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      await _controller.setGpsFilterMode(selected);
    }
    return selected;
  }

  String _gpsFilterModeLabel(AppLocalizations l10n, GpsFilterMode mode) {
    switch (mode) {
      case GpsFilterMode.auto:
        return l10n.settingsGpsFilterModeAuto;
      case GpsFilterMode.normal:
        return l10n.settingsGpsFilterModeNormal;
      case GpsFilterMode.strict:
        return l10n.settingsGpsFilterModeStrict;
    }
  }

  String _gpsFilterModeDescription(AppLocalizations l10n, GpsFilterMode mode) {
    switch (mode) {
      case GpsFilterMode.auto:
        return l10n.settingsGpsFilterModeAutoDescription;
      case GpsFilterMode.normal:
        return l10n.settingsGpsFilterModeNormalDescription;
      case GpsFilterMode.strict:
        return l10n.settingsGpsFilterModeStrictDescription;
    }
  }

  Future<DynamicMapZoomPreset?> _pickDynamicMapZoomPreset(
    AppLocalizations l10n,
  ) async {
    final options = {
      DynamicMapZoomPreset.conservative:
          l10n.settingsDynamicMapZoomPresetConservative,
      DynamicMapZoomPreset.balanced: l10n.settingsDynamicMapZoomPresetBalanced,
      DynamicMapZoomPreset.aggressive:
          l10n.settingsDynamicMapZoomPresetAggressive,
    };
    final selected = await showModalBottomSheet<DynamicMapZoomPreset>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.entries
              .map(
                (entry) => ListTile(
                  title: Text(entry.value),
                  trailing: _controller.dynamicMapZoomPreset == entry.key
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(context).pop(entry.key),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      await _controller.setDynamicMapZoomPreset(selected);
    }
    return selected;
  }

  String _dynamicMapZoomPresetLabel(
    AppLocalizations l10n,
    DynamicMapZoomPreset preset,
  ) {
    switch (preset) {
      case DynamicMapZoomPreset.conservative:
        return l10n.settingsDynamicMapZoomPresetConservative;
      case DynamicMapZoomPreset.balanced:
        return l10n.settingsDynamicMapZoomPresetBalanced;
      case DynamicMapZoomPreset.aggressive:
        return l10n.settingsDynamicMapZoomPresetAggressive;
    }
  }

  Future<void> _logout(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    bool confirmed = false;
    if (PlatformUtils.isApplePlatform) {
      confirmed =
          await showCupertinoDialog<bool>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: Text(l10n.logout),
              content: const Text('Are you sure you want to log out?'),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.cancel),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.logout),
                ),
              ],
            ),
          ) ??
          false;
    } else {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.logout),
              content: const Text('Are you sure you want to log out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.logout),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!confirmed) {
      return;
    }

    await _controller.logout();
    widget.onLogout?.call();
  }

  Future<void> _handleBatteryExemptionAction(BuildContext context) async {
    final granted = await _controller.requestBatteryExemption();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Background tracking reliability improved.'
              : 'Battery optimization is still active. Background GPS may pause.',
        ),
      ),
    );
  }

  Future<void> _reconfigureTrackingPermissions() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await DialogUtils.showConfirmDialog(
      context,
      title: l10n.settingsTrackingPermissionsTitle,
      message: l10n.settingsTrackingPermissionsDialogMessage,
      confirmText: l10n.settingsTrackingPermissionsAction,
    );
    if (!mounted || !confirmed) return;
    try {
      final locationService = serviceLocator<LocationService>();
      final powerManagementService = serviceLocator<PowerManagementService>();
      final storage = serviceLocator<SecureStorageService>();
      final serviceEnabled = await locationService.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await locationService.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await locationService.requestPermission();
        }
      }
      if (PlatformUtils.isAndroid) {
        await powerManagementService.requestBatteryExemption();
      }
      await storage.setPermissionsOnboardingCompleted(true);
      if (!mounted) return;
      await DialogUtils.showSuccessDialog(
        context,
        l10n.settingsTrackingPermissionsSuccess,
      );
    } catch (e) {
      if (!mounted) return;
      await DialogUtils.showErrorDialog(
        context,
        AppErrorMapper.toUserMessage(e, l10n),
      );
    }
  }

  String _batteryPolicySubtitle() {
    if (_controller.batteryOptimizationIgnored) {
      return 'Battery optimization disabled for Endurain';
    }
    return 'Battery optimization active. GPS can pause in background.';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (PlatformUtils.isApplePlatform) {
          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text(l10n.settingsScreen),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      children: [
                        CupertinoListSection.insetGrouped(
                          header: Text(l10n.settingsSectionTheme),
                          children: [
                            CupertinoListTile.notched(
                              leading: const Tooltip(
                                message:
                                    'Choose between Light, Dark, or System theme.',
                                child: Icon(CupertinoIcons.brightness),
                              ),
                              title: Text(l10n.settingsThemeMode),
                              subtitle: Text(
                                _themeModeLabel(l10n, widget.selectedThemeMode),
                              ),
                              trailing: const CupertinoListTileChevron(),
                              onTap: () => _pickThemeMode(l10n),
                            ),
                            CupertinoListTile.notched(
                              leading: const Tooltip(
                                message:
                                    'Select a color scheme for the app UI.',
                                child: Icon(CupertinoIcons.drop),
                              ),
                              title: Text(l10n.settingsThemePreset),
                              subtitle: Text(
                                _themePresetLabel(
                                  l10n,
                                  widget.selectedThemePreset,
                                ),
                              ),
                              trailing: const CupertinoListTileChevron(),
                              onTap: () => _pickThemePreset(l10n),
                            ),
                          ],
                        ),
                        CupertinoListSection.insetGrouped(
                          header: Text(l10n.settingsSectionVoiceCoach),
                          children: [
                            CupertinoListTile.notched(
                              leading: const Icon(CupertinoIcons.speaker_2),
                              title: Text(l10n.settingsVoiceCoachEnabled),
                              subtitle: Text(
                                l10n.settingsVoiceCoachEnabledDescription,
                              ),
                              trailing: CupertinoSwitch(
                                value: _controller.audioEnabled,
                                onChanged: (val) {
                                  _controller.toggleAudio(val);
                                },
                              ),
                            ),
                            CupertinoListTile.notched(
                              leading: const Icon(CupertinoIcons.volume_up),
                              title: Text(l10n.settingsVoiceCoachVolume),
                              subtitle: Text(
                                l10n.settingsVoiceCoachVolumeDescription,
                              ),
                              additionalInfo: Text(
                                l10n.settingsVoiceCoachVolumeValue(
                                  (_controller.voiceVolume * 100).round(),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: CupertinoSlider(
                                value: _controller.voiceVolume,
                                min: 0,
                                max: 1,
                                divisions: 20,
                                onChanged: _controller.audioEnabled
                                    ? (value) async {
                                        await _controller.setVoiceVolume(value);
                                      }
                                    : null,
                              ),
                            ),
                            CupertinoListTile.notched(
                              leading: const Icon(CupertinoIcons.timer),
                              title: Text(l10n.settingsVoiceCoachStartPrompts),
                              subtitle: Text(
                                l10n.settingsVoiceCoachStartPromptsDescription,
                              ),
                              trailing: CupertinoSwitch(
                                value: _controller.announceStart,
                                onChanged: _controller.audioEnabled
                                    ? (val) async {
                                        await _controller.setAnnounceStart(val);
                                      }
                                    : null,
                              ),
                            ),
                            CupertinoListTile.notched(
                              leading: const Icon(CupertinoIcons.speedometer),
                              title: Text(
                                l10n.settingsVoiceCoachSplitAnnouncements,
                              ),
                              subtitle: Text(
                                l10n.settingsVoiceCoachSplitAnnouncementsDescription,
                              ),
                              trailing: CupertinoSwitch(
                                value: _controller.announceSplits,
                                onChanged: _controller.audioEnabled
                                    ? (val) async {
                                        await _controller.setAnnounceSplits(
                                          val,
                                        );
                                      }
                                    : null,
                              ),
                            ),
                            CupertinoListTile.notched(
                              leading: const Icon(
                                CupertinoIcons.location_solid,
                              ),
                              title: Text(
                                l10n.settingsVoiceCoachGpsAnnouncements,
                              ),
                              subtitle: Text(
                                l10n.settingsVoiceCoachGpsAnnouncementsDescription,
                              ),
                              trailing: CupertinoSwitch(
                                value: _controller.announceGps,
                                onChanged: _controller.audioEnabled
                                    ? (val) async {
                                        await _controller.setAnnounceGps(val);
                                      }
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        CupertinoListSection.insetGrouped(
                          header: Text(l10n.settingsSectionRouteDisplay),
                          children: [
                            CupertinoListTile.notched(
                              leading: const Tooltip(
                                message:
                                    'Choose how the route is drawn on the map.',
                                child: Icon(CupertinoIcons.map_pin_ellipse),
                              ),
                              title: Text(l10n.settingsRouteDisplayModeTitle),
                              additionalInfo: Text(
                                _routeDisplayModeLabel(
                                  l10n,
                                  widget.routeDisplayMode,
                                ),
                              ),
                              trailing: const CupertinoListTileChevron(),
                              onTap: () => _pickRouteDisplayMode(l10n),
                            ),
                            CupertinoListTile.notched(
                              leading: const Tooltip(
                                message: 'Configure GPS filtering strength.',
                                child: Icon(CupertinoIcons.location_solid),
                              ),
                              title: Text(l10n.settingsGpsFilterModeTitle),
                              subtitle: Text(
                                _gpsFilterModeDescription(
                                  l10n,
                                  widget.gpsFilterMode,
                                ),
                              ),
                              additionalInfo: Text(
                                _gpsFilterModeLabel(l10n, widget.gpsFilterMode),
                              ),
                              trailing: const CupertinoListTileChevron(),
                              onTap: () => _pickGpsFilterMode(l10n),
                            ),
                            CupertinoListTile.notched(
                              leading: const Icon(CupertinoIcons.map),
                              title: Text(l10n.settingsDynamicMapZoomTitle),
                              subtitle: Text(
                                l10n.settingsDynamicMapZoomDescription,
                              ),
                              trailing: CupertinoSwitch(
                                value: _controller.dynamicMapZoomEnabled,
                                onChanged: (val) async {
                                  await _controller.setDynamicMapZoomEnabled(
                                    val,
                                  );
                                },
                              ),
                            ),
                            CupertinoListTile.notched(
                              leading: const Tooltip(
                                message:
                                    'Battery saving mode for long activities.',
                                child: Icon(CupertinoIcons.battery_25),
                              ),
                              title: const Text('Eco Mode'), // TODO: Localize
                              subtitle: const Text(
                                'Reduces GPS update frequency',
                              ),
                              trailing: CupertinoSwitch(
                                value: _controller.ecoModeEnabled,
                                onChanged: (val) {
                                  _controller.setEcoMode(val);
                                },
                              ),
                            ),
                          ],
                        ),
                        CupertinoListSection.insetGrouped(
                          header: Text(l10n.settingsTrackingPermissionsTitle),
                          children: [
                            CupertinoListTile.notched(
                              leading: const Icon(
                                CupertinoIcons.location_solid,
                              ),
                              title: Text(l10n.settingsTrackingPermissionsAction),
                              subtitle: Text(
                                l10n.settingsTrackingPermissionsDescription,
                              ),
                              trailing: const CupertinoListTileChevron(),
                              onTap: _reconfigureTrackingPermissions,
                            ),
                          ],
                        ),
                        CupertinoListSection.insetGrouped(
                          header: Text(l10n.settingsSectionServer),
                          children: [
                            CupertinoListTile.notched(
                              leading: const Tooltip(
                                message: 'Manage server URL and connection.',
                                child: Icon(CupertinoIcons.cloud),
                              ),
                              title: Text(l10n.serverSettings),
                              additionalInfo: Text(
                                widget.isServerConnected
                                    ? l10n.settingsServerConnected
                                    : l10n.settingsServerDisconnected,
                              ),
                              trailing: const CupertinoListTileChevron(),
                              onTap: () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute<void>(
                                    builder: (context) => ServerSettingsScreen(
                                      authService: serviceLocator(),
                                      storage: serviceLocator(),
                                      onLogout: widget.onLogout,
                                      onOpenServerLogin: widget.onOpenServerLogin,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (!widget.isServerConnected)
                              CupertinoListTile.notched(
                                leading: const Icon(CupertinoIcons.info_circle),
                                title: Text(l10n.settingsServerDisconnected),
                                subtitle: Text(l10n.connectUploadMessage),
                              ),
                            if (!widget.isServerConnected)
                              CupertinoListTile.notched(
                                leading: const Icon(
                                  CupertinoIcons.person_crop_circle_badge_plus,
                                ),
                                title: Text(l10n.login),
                                subtitle: Text(l10n.connectUploadAction),
                                trailing: const CupertinoListTileChevron(),
                                onTap: widget.onOpenServerLogin == null
                                    ? null
                                    : () async {
                                        await widget.onOpenServerLogin!.call();
                                      },
                              ),
                          ],
                        ),
                        if (widget.isServerConnected)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: CupertinoButton(
                              color: CupertinoColors.destructiveRed,
                              child: Text(l10n.logout),
                              onPressed: () => _logout(context),
                            ),
                          ),
                        FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox();
                            final versionLine =
                                'Endurain v${snapshot.data!.version} (${snapshot.data!.buildNumber})';
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 24,
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    CupertinoIcons.heart_fill,
                                    size: 18,
                                    color: CupertinoTheme.of(
                                      context,
                                    ).primaryColor,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'build with love',
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .textStyle
                                        .copyWith(fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    versionLine,
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .textStyle
                                        .copyWith(
                                          fontSize: 12,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(l10n.settingsScreen)),
          body: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              Card(
                child: ExpansionTile(
                  backgroundColor: _expandedTracking
                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.26)
                      : null,
                  collapsedBackgroundColor: Colors.transparent,
                  tilePadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  leading: const Icon(Icons.directions_run_rounded),
                  title: Text(
                    l10n.settingsAccordionTrackingTitle,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    l10n.settingsAccordionTrackingSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  initiallyExpanded: _expandedTracking,
                  onExpansionChanged: (value) {
                    setState(() {
                      _expandedTracking = value;
                    });
                  },
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.record_voice_over),
                      title: Text(l10n.settingsVoiceCoachEnabled),
                      subtitle: Text(l10n.settingsVoiceCoachEnabledDescription),
                      value: _controller.audioEnabled,
                      onChanged: (val) {
                        _controller.toggleAudio(val);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.volume_up),
                      title: Text(l10n.settingsVoiceCoachVolume),
                      subtitle: Text(l10n.settingsVoiceCoachVolumeDescription),
                      trailing: Text(
                        l10n.settingsVoiceCoachVolumeValue(
                          (_controller.voiceVolume * 100).round(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Slider(
                        value: _controller.voiceVolume,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        onChanged: _controller.audioEnabled
                            ? (value) async {
                                await _controller.setVoiceVolume(value);
                              }
                            : null,
                      ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.timer_outlined),
                      title: Text(l10n.settingsVoiceCoachStartPrompts),
                      subtitle: Text(
                        l10n.settingsVoiceCoachStartPromptsDescription,
                      ),
                      value: _controller.announceStart,
                      onChanged: _controller.audioEnabled
                          ? (val) async {
                              await _controller.setAnnounceStart(val);
                            }
                          : null,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.speed),
                      title: Text(l10n.settingsVoiceCoachSplitAnnouncements),
                      subtitle: Text(
                        l10n.settingsVoiceCoachSplitAnnouncementsDescription,
                      ),
                      value: _controller.announceSplits,
                      onChanged: _controller.audioEnabled
                          ? (val) async {
                              await _controller.setAnnounceSplits(val);
                            }
                          : null,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.gps_not_fixed),
                      title: Text(l10n.settingsVoiceCoachGpsAnnouncements),
                      subtitle: Text(
                        l10n.settingsVoiceCoachGpsAnnouncementsDescription,
                      ),
                      value: _controller.announceGps,
                      onChanged: _controller.audioEnabled
                          ? (val) async {
                              await _controller.setAnnounceGps(val);
                            }
                          : null,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.battery_saver),
                      title: Text(l10n.settingsEcoMode),
                      subtitle: Text(l10n.settingsEcoModeDescription),
                      value: _controller.ecoModeEnabled,
                      onChanged: (val) async {
                        await _controller.setEcoMode(val);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_searching_outlined),
                      title: Text(l10n.settingsTrackingPermissionsAction),
                      subtitle: Text(l10n.settingsTrackingPermissionsDescription),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _reconfigureTrackingPermissions,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ExpansionTile(
                  backgroundColor: _expandedDisplay
                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.26)
                      : null,
                  collapsedBackgroundColor: Colors.transparent,
                  tilePadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(
                    l10n.settingsAccordionDisplayTitle,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    l10n.settingsAccordionDisplaySubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  initiallyExpanded: _expandedDisplay,
                  onExpansionChanged: (value) {
                    setState(() {
                      _expandedDisplay = value;
                    });
                  },
                  children: [
                    ListTile(
                      leading: const Icon(Icons.brightness_6),
                      title: Text(l10n.settingsThemeMode),
                      subtitle: Text(
                        _themeModeLabel(l10n, _controller.themeMode),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final mode = await _pickThemeMode(l10n);
                        if (mode != null) {
                          await _controller.setThemeMode(mode);
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.palette),
                      title: Text(l10n.settingsThemePreset),
                      subtitle: Text(
                        _themePresetLabel(l10n, _controller.themePreset),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final preset = await _pickThemePreset(l10n);
                        if (preset != null) {
                          await _controller.setThemePreset(preset);
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.map),
                      title: Text(l10n.settingsRouteDisplayModeTitle),
                      subtitle: Text(
                        _routeDisplayModeLabel(
                          l10n,
                          _controller.routeDisplayMode,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final mode = await _pickRouteDisplayMode(l10n);
                        if (mode != null) {
                          await _controller.setRouteDisplayMode(mode);
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.gps_fixed),
                      title: Text(l10n.settingsGpsFilterModeTitle),
                      subtitle: Text(
                        _gpsFilterModeLabel(l10n, _controller.gpsFilterMode),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final mode = await _pickGpsFilterMode(l10n);
                        if (mode != null) {
                          await _controller.setGpsFilterMode(mode);
                        }
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.map_outlined),
                      title: Text(l10n.settingsDynamicMapZoomTitle),
                      subtitle: Text(l10n.settingsDynamicMapZoomDescription),
                      value: _controller.dynamicMapZoomEnabled,
                      onChanged: (val) async {
                        await _controller.setDynamicMapZoomEnabled(val);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.tune),
                      title: Text(l10n.settingsDynamicMapZoomPresetTitle),
                      subtitle: Text(
                        _dynamicMapZoomPresetLabel(
                          l10n,
                          _controller.dynamicMapZoomPreset,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: _controller.dynamicMapZoomEnabled,
                      onTap: _controller.dynamicMapZoomEnabled
                          ? () async {
                              await _pickDynamicMapZoomPreset(l10n);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ExpansionTile(
                  backgroundColor: _expandedDeviceSensors
                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.26)
                      : null,
                  collapsedBackgroundColor: Colors.transparent,
                  tilePadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  leading: const Icon(Icons.devices_outlined),
                  title: Text(
                    l10n.settingsAccordionDeviceTitle,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    l10n.settingsAccordionDeviceSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  initiallyExpanded: _expandedDeviceSensors,
                  onExpansionChanged: (value) {
                    setState(() {
                      _expandedDeviceSensors = value;
                    });
                  },
                  children: [
                    ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: const Text('Sensors & Accessories'),
                      subtitle: const Text('Manage Bluetooth devices'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => SensorSettingsScreen(
                              bluetoothService: widget.bluetoothService,
                            ),
                          ),
                        );
                      },
                    ),
                    AnimatedContainer(
                      key: _batteryTileKey,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      color: _highlightBatteryTile
                          ? Theme.of(context).colorScheme.tertiaryContainer
                                .withValues(alpha: 0.28)
                          : Colors.transparent,
                      child: ListTile(
                        leading: const Icon(Icons.shield_moon),
                        title: const Text('Background tracking reliability'),
                        subtitle: Text(_batteryPolicySubtitle()),
                        trailing: _controller.batteryOptimizationIgnored
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : FilledButton.tonal(
                                onPressed: () =>
                                    _handleBatteryExemptionAction(context),
                                child: const Text('Fix now'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ExpansionTile(
                  backgroundColor: _expandedServerSync
                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.26)
                      : null,
                  collapsedBackgroundColor: Colors.transparent,
                  tilePadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(
                    l10n.settingsAccordionServerTitle,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    l10n.settingsAccordionServerSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  initiallyExpanded: _expandedServerSync,
                  onExpansionChanged: (value) {
                    setState(() {
                      _expandedServerSync = value;
                    });
                  },
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud),
                      title: Text(l10n.serverSettings),
                      subtitle: Text(
                        widget.isServerConnected
                            ? l10n.settingsServerConnected
                            : l10n.settingsServerDisconnected,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => ServerSettingsScreen(
                              authService: serviceLocator(),
                              storage: serviceLocator(),
                              onLogout: widget.onLogout,
                              onOpenServerLogin: widget.onOpenServerLogin,
                            ),
                          ),
                        );
                      },
                    ),
                    if (!widget.isServerConnected)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.connectUploadMessage,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: widget.onOpenServerLogin == null
                                  ? null
                                  : () async {
                                      await widget.onOpenServerLogin!.call();
                                    },
                              icon: const Icon(Icons.login_rounded),
                              label: Text(l10n.login),
                            ),
                          ],
                        ),
                      ),
                    if (widget.isServerConnected)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.errorContainer,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                          onPressed: () => _logout(context),
                          child: Text(l10n.logout),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final versionLine =
                        'Endurain v${snapshot.data!.version} (${snapshot.data!.buildNumber})';
                    return Column(
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'build with love',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          versionLine,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
