import 'package:flutter/material.dart';

class EndurainSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class EndurainColors {
  // Base Colors
  static const Color darkPrimary = Color(0xFF1FC8B6);
  static const Color darkOnPrimary = Color(0xFF002824);
  static const Color darkSecondary = Color(0xFF6CB6FF);
  static const Color darkOnSecondary = Color(0xFF002A4A);
  static const Color darkBackground = Color(0xFF0E151C);
  static const Color darkSurface = Color(0xFF16212B);
  static const Color darkOnSurface = Color(0xFFE6EDF5);
  static const Color darkError = Color(0xFFFF6B7D);
  static const Color darkOutline = Color(0xFF506172);

  static const Color lightPrimary = Color(0xFF006A63);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightSecondary = Color(0xFF0D5EA8);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightBackground = Color(0xFFF1F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF15212B);
  static const Color lightError = Color(0xFFB32641);
  static const Color lightOutline = Color(0xFF607587);

  // --- Theme Presets (Light Mode) ---
  
  // Ocean (Blue)
  static const Color oceanLightSurface = Color(0xFFE3F2FD); // Blue 50
  static const Color oceanLightOnSurface = Color(0xFF0D47A1); // Blue 900
  static const Color oceanLightPrimary = Color(0xFF1565C0); // Blue 800

  // Forest (Green)
  static const Color forestLightSurface = Color(0xFFE8F5E9); // Green 50
  static const Color forestLightOnSurface = Color(0xFF1B5E20); // Green 900
  static const Color forestLightPrimary = Color(0xFF2E7D32); // Green 800

  // Slate (Blue-Grey)
  static const Color slateLightSurface = Color(0xFFECEFF1); // BlueGrey 50
  static const Color slateLightOnSurface = Color(0xFF263238); // BlueGrey 900
  static const Color slateLightPrimary = Color(0xFF37474F); // BlueGrey 800

  // Twilight (Indigo)
  static const Color twilightLightSurface = Color(0xFFE8EAF6); // Indigo 50
  static const Color twilightLightOnSurface = Color(0xFF1A237E); // Indigo 900
  static const Color twilightLightPrimary = Color(0xFF283593); // Indigo 800

  // Ember (Deep Orange)
  static const Color emberLightSurface = Color(0xFFFBE9E7); // DeepOrange 50
  static const Color emberLightOnSurface = Color(0xFFBF360C); // DeepOrange 900
  static const Color emberLightPrimary = Color(0xFFD84315); // DeepOrange 800

  // Berry (Pink)
  static const Color berryLightSurface = Color(0xFFFCE4EC); // Pink 50
  static const Color berryLightOnSurface = Color(0xFF880E4F); // Pink 900
  static const Color berryLightPrimary = Color(0xFFAD1457); // Pink 800

  // --- Theme Presets (Dark Mode) ---
  
  // Ocean
  static const Color oceanDarkSurface = Color(0xFF0D47A1); // Blue 900
  static const Color oceanDarkOnSurface = Color(0xFFE3F2FD); // Blue 50
  static const Color oceanDarkPrimary = Color(0xFF90CAF9); // Blue 200

  // Forest
  static const Color forestDarkSurface = Color(0xFF1B5E20); // Green 900
  static const Color forestDarkOnSurface = Color(0xFFE8F5E9); // Green 50
  static const Color forestDarkPrimary = Color(0xFFA5D6A7); // Green 200

  // Slate
  static const Color slateDarkSurface = Color(0xFF263238); // BlueGrey 900
  static const Color slateDarkOnSurface = Color(0xFFECEFF1); // BlueGrey 50
  static const Color slateDarkPrimary = Color(0xFFB0BEC5); // BlueGrey 200

  // Twilight
  static const Color twilightDarkSurface = Color(0xFF1A237E); // Indigo 900
  static const Color twilightDarkOnSurface = Color(0xFFE8EAF6); // Indigo 50
  static const Color twilightDarkPrimary = Color(0xFF9FA8DA); // Indigo 200

  // Ember
  static const Color emberDarkSurface = Color(0xFFBF360C); // DeepOrange 900
  static const Color emberDarkOnSurface = Color(0xFFFBE9E7); // DeepOrange 50
  static const Color emberDarkPrimary = Color(0xFFFFAB91); // DeepOrange 200

  // Berry
  static const Color berryDarkSurface = Color(0xFF880E4F); // Pink 900
  static const Color berryDarkOnSurface = Color(0xFFFCE4EC); // Pink 50
  static const Color berryDarkPrimary = Color(0xFFF48FB1); // Pink 200

  // Legacy/Fallback
  static const Color highContrastSurface = Color(0xFF000000); 
  static const Color highContrastOnSurface = Color(0xFFFFFFFF);
  static const Color highContrastBorder = Color(0x61FFFFFF); 
}

class EndurainTypography {
  static TextStyle headline(ColorScheme colorScheme) {
    return TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: colorScheme.onSurface,
      letterSpacing: 0.2,
    );
  }

  static TextStyle metricValue(ColorScheme colorScheme) {
    return TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.1,
      color: colorScheme.onSurface,
      letterSpacing: -0.2,
    );
  }

  static TextStyle metricLabel(ColorScheme colorScheme) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: colorScheme.onSurfaceVariant,
      letterSpacing: 0.2,
    );
  }

  static TextStyle helper(ColorScheme colorScheme) {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.35,
      color: colorScheme.onSurfaceVariant,
      letterSpacing: 0.15,
    );
  }

  static TextTheme textTheme(ColorScheme colorScheme) {
    final headlineStyle = headline(colorScheme);
    final metricValueStyle = metricValue(colorScheme);
    final metricLabelStyle = metricLabel(colorScheme);
    final helperStyle = helper(colorScheme);
    return TextTheme(
      headlineLarge: headlineStyle.copyWith(fontSize: 28),
      headlineMedium: headlineStyle.copyWith(fontSize: 24),
      headlineSmall: headlineStyle,
      titleLarge: metricValueStyle.copyWith(fontSize: 22),
      titleMedium: metricValueStyle.copyWith(fontSize: 18),
      titleSmall: metricValueStyle.copyWith(fontSize: 16),
      labelLarge: metricLabelStyle.copyWith(fontSize: 13),
      labelMedium: metricLabelStyle,
      labelSmall: helperStyle,
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
