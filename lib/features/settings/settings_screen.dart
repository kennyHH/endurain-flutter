import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/features/settings/server_settings_screen.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/core/constants/ui_constants.dart';
import 'package:endurain/core/theme/app_theme.dart';
import 'package:endurain/core/theme/endurain_design_system.dart';
import 'package:endurain/core/models/gps_filter_mode.dart';
import 'package:endurain/core/models/route_display_mode.dart';
import 'package:endurain/core/services/audio_feedback_service.dart';

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
  
  // Audio Settings
  bool _audioEnabled = true;
  
  

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
      AppThemePreset.ocean: l10n.settingsThemePresetOcean,
      AppThemePreset.forest: l10n.settingsThemePresetForest,
      AppThemePreset.slate: "Slate", // TODO: Localize
      AppThemePreset.twilight: "Twilight", // TODO: Localize
      AppThemePreset.ember: "Ember", // TODO: Localize
      AppThemePreset.berry: "Berry", // TODO: Localize
    };
    
    AppThemePreset? selected;
    
    if (PlatformUtils.isApplePlatform) {
      selected = await showCupertinoModalPopup<AppThemePreset>(
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
    } else {
      selected = await showModalBottomSheet<AppThemePreset>(
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
    }

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
      case AppThemePreset.ocean:
        return l10n.settingsThemePresetOcean;
      case AppThemePreset.forest:
        return l10n.settingsThemePresetForest;
      case AppThemePreset.slate:
        return "Slate";
      case AppThemePreset.twilight:
        return "Twilight";
      case AppThemePreset.ember:
        return "Ember";
      case AppThemePreset.berry:
        return "Berry";
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

  Color _presetPrimary(AppThemePreset preset, bool dark) {
    switch (preset) {
      case AppThemePreset.ocean:
        return dark ? const Color(0xFF33C4E6) : const Color(0xFF006B8A);
      case AppThemePreset.forest:
        return dark ? const Color(0xFF21BFA3) : const Color(0xFF006A63);
      case AppThemePreset.slate:
        return dark ? const Color(0xFF90A4AE) : const Color(0xFF455A64);
      case AppThemePreset.twilight:
        return dark ? const Color(0xFF7986CB) : const Color(0xFF283593);
      case AppThemePreset.ember:
        return dark ? const Color(0xFFFF8A65) : const Color(0xFFD84315);
      case AppThemePreset.berry:
        return dark ? const Color(0xFFF06292) : const Color(0xFFAD1457);
    }
  }

  Color _presetSecondary(AppThemePreset preset, bool dark) {
    switch (preset) {
      case AppThemePreset.ocean:
        return dark ? const Color(0xFF7DB4FF) : const Color(0xFF1E5FA5);
      case AppThemePreset.forest:
        return dark ? const Color(0xFF7AC9FF) : const Color(0xFF2D5EA0);
      case AppThemePreset.slate:
        return const Color(0xFFB0BEC5);
      case AppThemePreset.twilight:
        return const Color(0xFF9FA8DA);
      case AppThemePreset.ember:
        return const Color(0xFFFFAB91);
      case AppThemePreset.berry:
        return const Color(0xFFF48FB1);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAudioSettings();
    _loadVersion();
  }

    void _loadAudioSettings() {
    final service = AudioFeedbackService();
    setState(() {
      _audioEnabled = service.isEnabled;
    });
  }

  void _toggleAudio(bool value) {
    setState(() => _audioEnabled = value);
    AudioFeedbackService().toggleEnabled(value);
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

  
  void _showInfoDialog(String title, String message) {
    if (PlatformUtils.isApplePlatform) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final effectiveBrightness = switch (widget.selectedThemeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => systemBrightness,
    };
    final previewIsDark = effectiveBrightness == Brightness.dark;
    final previewPrimary = _presetPrimary(
      widget.selectedThemePreset,
      previewIsDark,
    );
    final previewSecondary = _presetSecondary(
      widget.selectedThemePreset,
      previewIsDark,
    );
    final previewBackground = previewIsDark
        ? EndurainColors.darkBackground
        : EndurainColors.lightBackground;
    final previewSurface = previewIsDark
        ? EndurainColors.darkSurface
        : EndurainColors.lightSurface;
    final previewOnSurface = previewIsDark
        ? EndurainColors.darkOnSurface
        : EndurainColors.lightOnSurface;
    final previewOutline = widget.highContrast
        ? (previewIsDark ? const Color(0xFF8FA6B8) : const Color(0xFF456173))
        : (previewIsDark
              ? EndurainColors.darkOutline
              : EndurainColors.lightOutline);

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
                  children: [
                    CupertinoListSection.insetGrouped(
                      header: Text(l10n.settingsSectionTheme),
                      children: [
                        
                        CupertinoListTile.notched(
                          leading: const Tooltip(message: "Choose between Light, Dark, or System theme.", child: Icon(CupertinoIcons.brightness)),
                          title: Text(l10n.settingsThemeMode),
                          subtitle: Text(
                            _themeModeLabel(l10n, widget.selectedThemeMode),
                          ),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () => _pickThemeMode(l10n),
                        ),
                        CupertinoListTile.notched(
                          leading: const Tooltip(message: "Select a color scheme for the app UI.", child: Icon(CupertinoIcons.drop)),
                          title: Text(l10n.settingsThemePreset),
                          subtitle: Text(
                            _themePresetLabel(l10n, widget.selectedThemePreset),
                          ),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () => _pickThemePreset(l10n),
                        ),
                      ],
                    ),
                    CupertinoListSection.insetGrouped(
                      header: Text(l10n.settingsSectionRouteDisplay),
                      children: [
                        CupertinoListTile.notched(
                          leading: const Tooltip(message: "Choose how the route is drawn on the map.", child: Icon(CupertinoIcons.map_pin_ellipse)),
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
                          leading: const Tooltip(message: "Configure GPS filtering strength.", child: Icon(CupertinoIcons.location_solid)),
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
                      ],
                    ),
                    CupertinoListSection.insetGrouped(
                      header: const Text("Audio Feedback"), // TODO: Localize
                      children: [
                        CupertinoListTile.notched(
                          leading: const Tooltip(message: "Enable audio feedback.", child: Icon(CupertinoIcons.volume_up)),
                          title: const Text("Voice Coach"), // TODO: Localize
                          trailing: CupertinoSwitch(
                            value: _audioEnabled,
                            onChanged: _toggleAudio,
                          ),
                        ),
                      ],
                    ),
                    CupertinoListSection.insetGrouped(
                      header: Text(l10n.settingsSectionServer),
                      children: [
                        CupertinoListTile.notched(
                          leading: const Tooltip(message: "Configure server connection.", child: Icon(CupertinoIcons.globe)),
                          title: Text(l10n.serverSettings),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute<void>(
                                builder: (context) => ServerSettingsScreen(
                                  onLogout: widget.onLogout,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    CupertinoListSection.insetGrouped(
                      header: Text(l10n.settingsSectionAboutApp),
                      children: [
                        CupertinoListTile.notched(
                          leading: const Tooltip(message: "App version and build information.", child: Icon(CupertinoIcons.info_circle)),
                          title: Text(l10n.settingsAppVersionTitle),
                          subtitle: Text(
                            _version.isEmpty ? '-' : '$_version\n$_buildInfo',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: EndurainSpacing.md),
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsScreen)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(EndurainSpacing.md),
              children: [
                _SettingsSectionHeader(title: l10n.settingsSectionTheme),
                Card(
                  child: Column(
                    children: [
                      
                      ListTile(
                        leading: const Icon(Icons.brightness_6_outlined),
                        title: Text(l10n.settingsThemeMode),
                        subtitle: Text(
                          _themeModeLabel(l10n, widget.selectedThemeMode),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () => _showInfoDialog(l10n.settingsThemeMode, "Choose between Light, Dark, or System theme."),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _pickThemeMode(l10n),
                      ),
                      ListTile(
                        leading: const Icon(Icons.color_lens_outlined),
                        title: Text(l10n.settingsThemePreset),
                        subtitle: Text(
                          _themePresetLabel(l10n, widget.selectedThemePreset),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () => _showInfoDialog(l10n.settingsThemePreset, "Select a color scheme for the app UI."), // TODO: Localize description
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _pickThemePreset(l10n),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: EndurainSpacing.md),
                _SettingsSectionHeader(title: l10n.settingsSectionRouteDisplay),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.route_outlined),
                        title: Text(l10n.settingsRouteDisplayModeTitle),
                        subtitle: Text(
                          _routeDisplayModeLabel(l10n, widget.routeDisplayMode),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () => _showInfoDialog(l10n.settingsRouteDisplayModeTitle, "Choose how the route is drawn on the map (Raw GPS or Matched to roads)."), // TODO: Localize description
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _pickRouteDisplayMode(l10n),
                      ),
                      ListTile(
                        leading: const Icon(Icons.gps_fixed),
                        title: Text(l10n.settingsGpsFilterModeTitle),
                        subtitle: Text(
                          '${_gpsFilterModeLabel(l10n, widget.gpsFilterMode)}\n'
                          '${_gpsFilterModeDescription(l10n, widget.gpsFilterMode)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () => _showInfoDialog(l10n.settingsGpsFilterModeTitle, _gpsFilterModeDescription(l10n, widget.gpsFilterMode)),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _pickGpsFilterMode(l10n),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: EndurainSpacing.md),
                                _SettingsSectionHeader(title: "Audio Feedback"), // TODO: Localize
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Tooltip(message: "Enable audio feedback during activities.", child: Icon(Icons.volume_up)),
                        title: const Text("Voice Coach"), // TODO: Localize
                        value: _audioEnabled,
                        onChanged: _toggleAudio,
                      ),
                      // More granular settings later
                    ],
                  ),
                ),
                const SizedBox(height: EndurainSpacing.md),
_SettingsSectionHeader(title: l10n.settingsSectionServer),
                Card(
                  child: ListTile(
                    leading: const Tooltip(message: "Configure server connection.", child: Icon(Icons.dns)),
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
                const SizedBox(height: EndurainSpacing.md),
                _SettingsSectionHeader(title: l10n.settingsSectionAboutApp),
                Card(
                  child: ListTile(
                    leading: const Tooltip(message: "App version and build information.", child: Icon(Icons.info_outline)),
                    title: Text(l10n.settingsAppVersionTitle),
                    subtitle: Text(
                      _version.isEmpty ? '-' : '$_version\n$_buildInfo',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: EndurainSpacing.md),
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

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EndurainSpacing.xs),
      child: Text(
        title,
        style: EndurainTypography.metricLabel(Theme.of(context).colorScheme)
            .copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
