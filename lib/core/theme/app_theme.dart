import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:endurain/core/constants/ui_constants.dart';

enum AppThemePreset { endurain, ocean, forest }

class AppTheme {
  // Endurain-inspired palette: warm orange primary + deep blue support.
  static const Color _endurainPrimary = Color(0xFFF59E6A);
  static const Color _endurainSecondary = Color(0xFF2E6EA6);
  static const Color _oceanPrimary = Color(0xFF35A8D8);
  static const Color _oceanSecondary = Color(0xFF4A6FE3);
  static const Color _forestPrimary = Color(0xFF4AA870);
  static const Color _forestSecondary = Color(0xFF2C7A50);
  static const Color _highContrastAccent = Color(0xFFE57D45);
  static const Color _highContrastDarkAccent = Color(0xFFFFB489);

  static Color _seedForPreset(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.endurain:
        return _endurainPrimary;
      case AppThemePreset.ocean:
        return _oceanPrimary;
      case AppThemePreset.forest:
        return _forestPrimary;
    }
  }

  static Color _cupertinoPrimaryForPreset(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.endurain:
        return _endurainSecondary;
      case AppThemePreset.ocean:
        return _oceanSecondary;
      case AppThemePreset.forest:
        return _forestSecondary;
    }
  }

  // Material themes for Android
  static ThemeData lightTheme({
    bool highContrast = false,
    AppThemePreset preset = AppThemePreset.endurain,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: highContrast ? _highContrastAccent : _seedForPreset(preset),
      brightness: Brightness.light,
      contrastLevel: highContrast ? 1.0 : 0.2,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: highContrast
          ? const Color(0xFFFDFEFD)
          : const Color(0xFFF5F7F6),
      listTileTheme: ListTileThemeData(
        textColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurfaceVariant,
      ),
      cardTheme: const CardThemeData(elevation: 2, margin: EdgeInsets.zero),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: UIConstants.elevationNone,
      ),
    );
  }

  static ThemeData darkTheme({
    bool highContrast = false,
    AppThemePreset preset = AppThemePreset.endurain,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: highContrast
          ? _highContrastDarkAccent
          : _seedForPreset(preset),
      brightness: Brightness.dark,
      contrastLevel: highContrast ? 1.0 : 0.55,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: highContrast
          ? const Color(0xFF080E0A)
          : const Color(0xFF0D1218),
      cardColor: const Color(0xFF17202A),
      listTileTheme: ListTileThemeData(
        textColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurface,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: UIConstants.elevationNone,
      ),
    );
  }

  // Cupertino themes for iOS/macOS
  static CupertinoThemeData cupertinoLightTheme({
    bool highContrast = false,
    AppThemePreset preset = AppThemePreset.endurain,
  }) {
    return CupertinoThemeData(
      primaryColor: highContrast
          ? _highContrastAccent
          : _cupertinoPrimaryForPreset(preset),
      brightness: Brightness.light,
    );
  }

  static CupertinoThemeData cupertinoDarkTheme({
    bool highContrast = false,
    AppThemePreset preset = AppThemePreset.endurain,
  }) {
    return CupertinoThemeData(
      primaryColor: highContrast
          ? _highContrastDarkAccent
          : _cupertinoPrimaryForPreset(preset),
      brightness: Brightness.dark,
    );
  }
}
