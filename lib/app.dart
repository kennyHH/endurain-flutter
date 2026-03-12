import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:endurain/core/network/endurain_http_overrides.dart';
import 'package:endurain/core/models/gps_filter_mode.dart';
import 'package:endurain/core/models/route_display_mode.dart';
import 'package:endurain/core/theme/app_theme.dart';
import 'package:endurain/shared/widgets/app_bottom_nav.dart';
import 'package:endurain/features/auth/login_screen.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/utils/platform_utils.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _storage = SecureStorageService();
  bool _isLoading = true;
  bool _isAuthenticated = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _highContrast = true;
  RouteDisplayMode _routeDisplayMode = RouteDisplayMode.auto;
  GpsFilterMode _gpsFilterMode = GpsFilterMode.auto;
  bool _allowInsecureTls = false;
  AppThemePreset _themePreset = AppThemePreset.slate;
  

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    bool isAuth = false;
    ThemeMode nextThemeMode = ThemeMode.system;
    var nextHighContrast = true;
    var nextRouteDisplayMode = RouteDisplayMode.auto;
    var nextGpsFilterMode = GpsFilterMode.auto;
    var nextAllowInsecureTls = false;
    var nextThemePreset = AppThemePreset.slate;
    try {
      isAuth = await _storage.isAuthenticated();
      final savedThemeMode = await _storage.getThemeMode();
      nextThemeMode = _themeModeFromStorage(savedThemeMode);
      nextHighContrast = true;
      final storedRouteMode = await _storage.getRouteDisplayMode();
      if (storedRouteMode == null || storedRouteMode.isEmpty) {
        final legacyMapMatching = await _storage.getMapMatchingPreviewEnabled();
        nextRouteDisplayMode = legacyMapMatching
            ? RouteDisplayMode.auto
            : RouteDisplayMode.raw;
      } else {
        nextRouteDisplayMode = routeDisplayModeFromStorage(storedRouteMode);
      }
      nextGpsFilterMode = gpsFilterModeFromStorage(
        await _storage.getGpsFilterMode(),
      );
      nextAllowInsecureTls = await _storage.getAllowInsecureTls();
      nextThemePreset = _themePresetFromStorage(
        await _storage.getThemePreset(),
      );

    } catch (_) {
      // Fall back to unauthenticated when secure storage is unavailable.
      isAuth = false;
    }
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
        _themeMode = nextThemeMode;
        _highContrast = nextHighContrast;
        _routeDisplayMode = nextRouteDisplayMode;
        _gpsFilterMode = nextGpsFilterMode;
        _allowInsecureTls = nextAllowInsecureTls;
        _themePreset = nextThemePreset;
        _isLoading = false;
      });
      EndurainHttpOverrides.allowInsecureTls = nextAllowInsecureTls;
    }
  }

  ThemeMode _themeModeFromStorage(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
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

  void _onLoginSuccess() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  void _onLogout() {
    setState(() {
      _isAuthenticated = false;
    });
  }

  Future<void> _onThemeModeChanged(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    await _storage.setThemeMode(_themeModeToStorage(mode));
  }

  Future<void> _onHighContrastChanged(bool enabled) async {
    setState(() {
      _highContrast = enabled;
    });
    await _storage.setHighContrast(enabled);
  }

  Future<void> _onRouteDisplayModeChanged(RouteDisplayMode mode) async {
    setState(() {
      _routeDisplayMode = mode;
    });
    await _storage.setRouteDisplayMode(routeDisplayModeToStorage(mode));
  }

  Future<void> _onAllowInsecureTlsChanged(bool enabled) async {
    setState(() {
      _allowInsecureTls = enabled;
    });
    EndurainHttpOverrides.allowInsecureTls = enabled;
    await _storage.setAllowInsecureTls(enabled);
  }

  Future<void> _onGpsFilterModeChanged(GpsFilterMode mode) async {
    setState(() {
      _gpsFilterMode = mode;
    });
    await _storage.setGpsFilterMode(gpsFilterModeToStorage(mode));
  }

    Future<void> _onThemePresetChanged(AppThemePreset preset) async {
    setState(() {
      _themePreset = preset;
    });
    await _storage.setThemePreset(_themePresetToStorage(preset));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Show loading screen while checking authentication
      return PlatformUtils.isApplePlatform
          ? const CupertinoApp(
              home: Center(child: CupertinoActivityIndicator()),
            )
          : const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            );
    }

    // Use Cupertino on iOS/macOS, Material on Android
    if (PlatformUtils.isApplePlatform) {
      return CupertinoApp(
        title: 'Endurain',
        theme: AppTheme.cupertinoLightTheme(
          highContrast: _highContrast,
          preset: _themePreset,
        ),
        // Cupertino automatically switches to dark theme based on system settings
        // when we provide a dark theme with matching brightness
        builder: (context, child) {
          final systemBrightness = MediaQuery.platformBrightnessOf(context);
          final brightness = switch (_themeMode) {
            ThemeMode.light => Brightness.light,
            ThemeMode.dark => Brightness.dark,
            ThemeMode.system => systemBrightness,
          };
          return CupertinoTheme(
            data: brightness == Brightness.dark
                ? AppTheme.cupertinoDarkTheme(
                    highContrast: _highContrast,
                    preset: _themePreset,
                  )
                : AppTheme.cupertinoLightTheme(
                    
                    highContrast: _highContrast,
                    preset: _themePreset,
                  ),
            child: child!,
          );
        },
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('pt')],
        home: _isAuthenticated
            ? AppBottomNav(
                onLogout: _onLogout,
                themeMode: _themeMode,
                highContrast: _highContrast,
                onThemeModeChanged: _onThemeModeChanged,
                onHighContrastChanged: _onHighContrastChanged,
                routeDisplayMode: _routeDisplayMode,
                onRouteDisplayModeChanged: _onRouteDisplayModeChanged,
                gpsFilterMode: _gpsFilterMode,
                onGpsFilterModeChanged: _onGpsFilterModeChanged,
                allowInsecureTls: _allowInsecureTls,
                onAllowInsecureTlsChanged: _onAllowInsecureTlsChanged,
                selectedThemePreset: _themePreset,
                onThemePresetChanged: _onThemePresetChanged,
                
                
              )
            : LoginScreen(onLoginSuccess: _onLoginSuccess),
      );
    } else {
      return MaterialApp(
        title: 'Endurain',
        theme: AppTheme.lightTheme(
          highContrast: _highContrast,
          preset: _themePreset,
        ),
        darkTheme: AppTheme.darkTheme(
          highContrast: _highContrast,
          preset: _themePreset,
        ),
        themeMode: _themeMode,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('pt')],
        home: _isAuthenticated
            ? AppBottomNav(
                onLogout: _onLogout,
                themeMode: _themeMode,
                highContrast: _highContrast,
                onThemeModeChanged: _onThemeModeChanged,
                onHighContrastChanged: _onHighContrastChanged,
                routeDisplayMode: _routeDisplayMode,
                onRouteDisplayModeChanged: _onRouteDisplayModeChanged,
                gpsFilterMode: _gpsFilterMode,
                onGpsFilterModeChanged: _onGpsFilterModeChanged,
                allowInsecureTls: _allowInsecureTls,
                onAllowInsecureTlsChanged: _onAllowInsecureTlsChanged,
                selectedThemePreset: _themePreset,
                onThemePresetChanged: _onThemePresetChanged,
                
                
              )
            : LoginScreen(onLoginSuccess: _onLoginSuccess),
      );
    }
  }
}
