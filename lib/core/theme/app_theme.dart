import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:endurain/core/constants/ui_constants.dart';
import 'package:endurain/core/theme/app_theme_tokens.dart';

class AppTheme {
  // Material themes for Android
  static ThemeData get lightTheme => _materialTheme(
    brightness: Brightness.light,
    surface: AppThemeTokens.lightSurface,
  );

  static ThemeData get darkTheme => _materialTheme(
    brightness: Brightness.dark,
    surface: AppThemeTokens.darkSurface,
  );

  static ThemeData _materialTheme({
    required Brightness brightness,
    required Color surface,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppThemeTokens.primarySeed,
      brightness: brightness,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: UIConstants.elevationNone,
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: AppThemeTokens.focusedBorderWidth,
          ),
        ),
      ),
    );
  }

  // Cupertino themes for iOS/macOS
  static CupertinoThemeData get cupertinoLightTheme {
    return const CupertinoThemeData(
      primaryColor: AppThemeTokens.primarySeed,
      brightness: Brightness.light,
    );
  }

  static CupertinoThemeData get cupertinoDarkTheme {
    return const CupertinoThemeData(
      primaryColor: AppThemeTokens.primarySeed,
      brightness: Brightness.dark,
    );
  }
}
