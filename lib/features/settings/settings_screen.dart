import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/features/settings/server_settings_screen.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/core/constants/ui_constants.dart';
import 'package:endurain/core/theme/app_theme.dart';
import 'package:endurain/core/models/gps_filter_mode.dart';
import 'package:endurain/core/models/route_display_mode.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.onLogout,
    required this.selectedThemeMode,
    required this.highContrast,
    required this.routeDisplayMode,
    required this.gpsFilterMode,
    required this.selectedThemePreset,
    this.onThemeModeChanged,
    this.onHighContrastChanged,
    this.onRouteDisplayModeChanged,
    this.onGpsFilterModeChanged,
    this.onThemePresetChanged,
  });

  final VoidCallback? onLogout;
  final ThemeMode selectedThemeMode;
  final bool highContrast;
  final RouteDisplayMode routeDisplayMode;
  final GpsFilterMode gpsFilterMode;
  final AppThemePreset selectedThemePreset;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<bool>? onHighContrastChanged;
  final ValueChanged<RouteDisplayMode>? onRouteDisplayModeChanged;
  final ValueChanged<GpsFilterMode>? onGpsFilterModeChanged;
  final ValueChanged<AppThemePreset>? onThemePresetChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _buildDate = String.fromEnvironment(
    'BUILD_DATE',
    defaultValue: 'local',
  );
  static const String _gitSha = String.fromEnvironment(
    'GIT_SHA',
    defaultValue: 'dev',
  );

  String _version = '';
  String _buildInfo = '';
  String _copyright = '';

  Future<void> _pickThemeMode(AppLocalizations l10n) async {
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
        widget.onThemeModeChanged?.call(selected);
      }
      return;
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
                    trailing: widget.selectedThemeMode == entry.key
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
      widget.onThemeModeChanged?.call(selected);
    }
  }

  Future<void> _pickThemePreset(AppLocalizations l10n) async {
    final options = {
      AppThemePreset.endurain: l10n.settingsThemePresetEndurain,
      AppThemePreset.ocean: l10n.settingsThemePresetOcean,
      AppThemePreset.forest: l10n.settingsThemePresetForest,
    };
    if (PlatformUtils.isApplePlatform) {
      final selected = await showCupertinoModalPopup<AppThemePreset>(
        context: context,
        builder: (context) {
          return CupertinoActionSheet(
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
          );
        },
      );
      if (selected != null) {
        widget.onThemePresetChanged?.call(selected);
      }
      return;
    }
    final selected = await showModalBottomSheet<AppThemePreset>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.entries
                .map(
                  (entry) => ListTile(
                    title: Text(entry.value),
                    trailing: widget.selectedThemePreset == entry.key
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
      widget.onThemePresetChanged?.call(selected);
    }
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
      case AppThemePreset.endurain:
        return l10n.settingsThemePresetEndurain;
      case AppThemePreset.ocean:
        return l10n.settingsThemePresetOcean;
      case AppThemePreset.forest:
        return l10n.settingsThemePresetForest;
    }
  }

  Future<void> _pickRouteDisplayMode(AppLocalizations l10n) async {
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
        widget.onRouteDisplayModeChanged?.call(selected);
      }
      return;
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
                  trailing: widget.routeDisplayMode == entry.key
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
      widget.onRouteDisplayModeChanged?.call(selected);
    }
  }

  String _routeDisplayModeLabel(
    AppLocalizations l10n,
    RouteDisplayMode mode,
  ) {
    switch (mode) {
      case RouteDisplayMode.auto:
        return l10n.settingsRouteDisplayModeAuto;
      case RouteDisplayMode.matched:
        return l10n.settingsRouteDisplayModeMatched;
      case RouteDisplayMode.raw:
        return l10n.settingsRouteDisplayModeRaw;
    }
  }

  Future<void> _pickGpsFilterMode(AppLocalizations l10n) async {
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
        widget.onGpsFilterModeChanged?.call(selected);
      }
      return;
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
                  trailing: widget.gpsFilterMode == entry.key
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
      widget.onGpsFilterModeChanged?.call(selected);
    }
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

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentYear = DateTime.now().year;
    if (mounted) {
      setState(() {
        _version = '${packageInfo.version} (${packageInfo.buildNumber})';
        _buildInfo = 'Build $_buildDate • $_gitSha';
        _copyright =
            '© ${UIConstants.copyrightStartYear} - $currentYear Endurain';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Cupertino style for iOS/macOS
    if (PlatformUtils.isApplePlatform) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(l10n.settingsScreen),
        ),
        child: SafeArea(
          child: Column(
            children: [
              CupertinoListSection.insetGrouped(
                header: Text(l10n.settingsThemeMode),
                children: [
                  CupertinoListTile.notched(
                    leading: const Icon(CupertinoIcons.paintbrush),
                    title: Text(l10n.settingsThemeMode),
                    subtitle: Text(
                      _themeModeLabel(l10n, widget.selectedThemeMode),
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _pickThemeMode(l10n),
                  ),
                  CupertinoListTile.notched(
                    leading: const Icon(CupertinoIcons.drop),
                    title: Text(l10n.settingsThemePreset),
                    subtitle: Text(
                      _themePresetLabel(l10n, widget.selectedThemePreset),
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _pickThemePreset(l10n),
                  ),
                  CupertinoListTile.notched(
                    leading: const Icon(CupertinoIcons.eye),
                    title: Text(l10n.settingsHighContrast),
                    trailing: CupertinoSwitch(
                      value: widget.highContrast,
                      onChanged: widget.onHighContrastChanged,
                    ),
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: Text(l10n.settingsRouteMatchingTitle),
                children: [
                  CupertinoListTile.notched(
                    leading: const Icon(CupertinoIcons.map_pin_ellipse),
                    title: Text(l10n.settingsRouteDisplayModeTitle),
                    additionalInfo: Text(
                      _routeDisplayModeLabel(l10n, widget.routeDisplayMode),
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _pickRouteDisplayMode(l10n),
                  ),
                  CupertinoListTile.notched(
                    leading: const Icon(CupertinoIcons.location_solid),
                    title: Text(l10n.settingsGpsFilterModeTitle),
                    subtitle: Text(
                      _gpsFilterModeDescription(l10n, widget.gpsFilterMode),
                    ),
                    additionalInfo: Text(
                      _gpsFilterModeLabel(l10n, widget.gpsFilterMode),
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _pickGpsFilterMode(l10n),
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: Text(l10n.serverSettings),
                children: [
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.globe),
                    title: Text(l10n.serverSettings),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute<void>(
                          builder: (context) =>
                              ServerSettingsScreen(onLogout: widget.onLogout),
                        ),
                      );
                    },
                  ),
                  CupertinoListTile.notched(
                    leading: const Icon(CupertinoIcons.info_circle),
                    title: const Text('App version'),
                    subtitle: Text(
                      _version.isEmpty ? '-' : '$_version\n$_buildInfo',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: UIConstants.paddingStandard,
                ),
                child: Text(
                  _copyright,
                  style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle
                      .copyWith(color: CupertinoColors.systemGrey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Material style for Android
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsScreen)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  l10n.settingsThemeMode,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: Text(l10n.settingsThemeMode),
                        subtitle: Text(
                          _themeModeLabel(l10n, widget.selectedThemeMode),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickThemeMode(l10n),
                      ),
                      ListTile(
                        leading: const Icon(Icons.color_lens_outlined),
                        title: Text(l10n.settingsThemePreset),
                        subtitle: Text(
                          _themePresetLabel(l10n, widget.selectedThemePreset),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickThemePreset(l10n),
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.contrast),
                        title: Text(l10n.settingsHighContrast),
                        value: widget.highContrast,
                        onChanged: widget.onHighContrastChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.settingsRouteMatchingTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.tune),
                        title: Text(l10n.settingsRouteDisplayModeTitle),
                        subtitle: Text(
                          _routeDisplayModeLabel(l10n, widget.routeDisplayMode),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickRouteDisplayMode(l10n),
                      ),
                      ListTile(
                        leading: const Icon(Icons.gps_fixed),
                        title: Text(l10n.settingsGpsFilterModeTitle),
                        subtitle: Text(
                          '${_gpsFilterModeLabel(l10n, widget.gpsFilterMode)}\n'
                          '${_gpsFilterModeDescription(l10n, widget.gpsFilterMode)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickGpsFilterMode(l10n),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.serverSettings,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.dns),
                    title: Text(l10n.serverSettings),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              ServerSettingsScreen(onLogout: widget.onLogout),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text('App', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('App version'),
                    subtitle: Text(
                      _version.isEmpty ? '-' : '$_version\n$_buildInfo',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: UIConstants.paddingStandard),
            child: Text(
              _copyright,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
