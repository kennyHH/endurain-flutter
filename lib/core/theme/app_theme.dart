import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:endurain/core/constants/ui_constants.dart';
import 'package:endurain/core/theme/endurain_design_system.dart';

enum AppThemePreset { ocean, forest, slate, twilight, ember, berry }

class AppTheme {
  static ColorScheme _darkColorScheme(
    AppThemePreset preset,
    bool highContrast,
  ) {
    final primary = switch (preset) {
      AppThemePreset.ocean => highContrast ? EndurainColors.oceanDarkPrimary : const Color(0xFF33C4E6),
      AppThemePreset.forest => highContrast ? EndurainColors.forestDarkPrimary : const Color(0xFF21BFA3),
      AppThemePreset.slate => highContrast ? EndurainColors.slateDarkPrimary : const Color(0xFF90A4AE),
      AppThemePreset.twilight => highContrast ? EndurainColors.twilightDarkPrimary : const Color(0xFF7986CB),
      AppThemePreset.ember => highContrast ? EndurainColors.emberDarkPrimary : const Color(0xFFFF8A65),
      AppThemePreset.berry => highContrast ? EndurainColors.berryDarkPrimary : const Color(0xFFF06292),
    };
    final secondary = switch (preset) {
      AppThemePreset.ocean => const Color(0xFF7DB4FF),
      AppThemePreset.forest => const Color(0xFF7AC9FF),
      AppThemePreset.slate => const Color(0xFFB0BEC5), // BlueGrey 200
      AppThemePreset.twilight => const Color(0xFF9FA8DA), // Indigo 200
      AppThemePreset.ember => const Color(0xFFFFAB91), // DeepOrange 200
      AppThemePreset.berry => const Color(0xFFF48FB1), // Pink 200
    };
    
    final surface = highContrast ? switch (preset) {
      AppThemePreset.ocean => EndurainColors.oceanDarkSurface,
      AppThemePreset.forest => EndurainColors.forestDarkSurface,
      AppThemePreset.slate => EndurainColors.slateDarkSurface,
      AppThemePreset.twilight => EndurainColors.twilightDarkSurface,
      AppThemePreset.ember => EndurainColors.emberDarkSurface,
      AppThemePreset.berry => EndurainColors.berryDarkSurface,
    } : EndurainColors.darkSurface;

    final onSurface = highContrast ? switch (preset) {
      AppThemePreset.ocean => EndurainColors.oceanDarkOnSurface,
      AppThemePreset.forest => EndurainColors.forestDarkOnSurface,
      AppThemePreset.slate => EndurainColors.slateDarkOnSurface,
      AppThemePreset.twilight => EndurainColors.twilightDarkOnSurface,
      AppThemePreset.ember => EndurainColors.emberDarkOnSurface,
      AppThemePreset.berry => EndurainColors.berryDarkOnSurface,
    } : EndurainColors.darkOnSurface;

    return ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: EndurainColors.darkOnPrimary,
      secondary: secondary,
      onSecondary: EndurainColors.darkOnSecondary,
      error: EndurainColors.darkError,
      onError: const Color(0xFF2E0006),
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: highContrast
          ? onSurface.withValues(alpha: 0.9)
          : const Color(0xFFB7C8D8),
      outline: highContrast
          ? onSurface.withValues(alpha: 0.6)
          : EndurainColors.darkOutline,
      outlineVariant: highContrast
          ? onSurface.withValues(alpha: 0.4)
          : const Color(0xFF3F4E5D),
      shadow: Colors.black,
      scrim: const Color(0xCC000000),
      inverseSurface: const Color(0xFFE1E8F0),
      onInverseSurface: const Color(0xFF16212B),
      inversePrimary: primary.withValues(alpha: 0.78),
      surfaceTint: primary,
      primaryContainer: primary.withValues(alpha: 0.2),
      onPrimaryContainer: const Color(0xFFD8FFF8),
      secondaryContainer: secondary.withValues(alpha: 0.2),
      onSecondaryContainer: const Color(0xFFD7EBFF),
      tertiary: const Color(0xFF79B3FF),
      onTertiary: const Color(0xFF032547),
      tertiaryContainer: const Color(0xFF12324F),
      onTertiaryContainer: const Color(0xFFD0E8FF),
      errorContainer: const Color(0xFF5A1F2B),
      onErrorContainer: const Color(0xFFFFD9DE),
      surfaceDim: const Color(0xFF0B1218),
      surfaceBright: const Color(0xFF28323D),
      surfaceContainerLowest: const Color(0xFF060B10),
      surfaceContainerLow: const Color(0xFF101922),
      surfaceContainer: const Color(0xFF15202A),
      surfaceContainerHigh: const Color(0xFF1B2733),
      surfaceContainerHighest: const Color(0xFF22303E),
    );
  }

  static ColorScheme _lightColorScheme(
    AppThemePreset preset,
    bool highContrast,
  ) {
    final primary = switch (preset) {
      AppThemePreset.ocean => highContrast ? EndurainColors.oceanLightPrimary : const Color(0xFF006B8A),
      AppThemePreset.forest => highContrast ? EndurainColors.forestLightPrimary : const Color(0xFF006A63),
      AppThemePreset.slate => highContrast ? EndurainColors.slateLightPrimary : const Color(0xFF455A64),
      AppThemePreset.twilight => highContrast ? EndurainColors.twilightLightPrimary : const Color(0xFF283593),
      AppThemePreset.ember => highContrast ? EndurainColors.emberLightPrimary : const Color(0xFFD84315),
      AppThemePreset.berry => highContrast ? EndurainColors.berryLightPrimary : const Color(0xFFAD1457),
    };
    final secondary = switch (preset) {
      AppThemePreset.ocean => const Color(0xFF1E5FA5),
      AppThemePreset.forest => const Color(0xFF2D5EA0),
      AppThemePreset.slate => const Color(0xFF546E7A), // BlueGrey 600
      AppThemePreset.twilight => const Color(0xFF3949AB), // Indigo 600
      AppThemePreset.ember => const Color(0xFFF4511E), // DeepOrange 600
      AppThemePreset.berry => const Color(0xFFD81B60), // Pink 600
    };

    final surface = highContrast ? switch (preset) {
      AppThemePreset.ocean => EndurainColors.oceanLightSurface,
      AppThemePreset.forest => EndurainColors.forestLightSurface,
      AppThemePreset.slate => EndurainColors.slateLightSurface,
      AppThemePreset.twilight => EndurainColors.twilightLightSurface,
      AppThemePreset.ember => EndurainColors.emberLightSurface,
      AppThemePreset.berry => EndurainColors.berryLightSurface,
    } : EndurainColors.lightSurface;

    final onSurface = highContrast ? switch (preset) {
      AppThemePreset.ocean => EndurainColors.oceanLightOnSurface,
      AppThemePreset.forest => EndurainColors.forestLightOnSurface,
      AppThemePreset.slate => EndurainColors.slateLightOnSurface,
      AppThemePreset.twilight => EndurainColors.twilightLightOnSurface,
      AppThemePreset.ember => EndurainColors.emberLightOnSurface,
      AppThemePreset.berry => EndurainColors.berryLightOnSurface,
    } : EndurainColors.lightOnSurface;

    return ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: EndurainColors.lightOnPrimary,
      secondary: secondary,
      onSecondary: EndurainColors.lightOnSecondary,
      error: EndurainColors.lightError,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: highContrast
          ? onSurface.withValues(alpha: 0.9)
          : const Color(0xFF4E6577),
      outline: highContrast
          ? onSurface.withValues(alpha: 0.6)
          : EndurainColors.lightOutline,
      outlineVariant: highContrast
          ? onSurface.withValues(alpha: 0.4)
          : const Color(0xFFC2D0DB),
      shadow: const Color(0x33000000),
      scrim: const Color(0x66000000),
      inverseSurface: const Color(0xFF1F2A35),
      onInverseSurface: const Color(0xFFE5ECF3),
      inversePrimary: primary.withValues(alpha: 0.75),
      surfaceTint: primary,
      primaryContainer: const Color(0xFFB8F4EC),
      onPrimaryContainer: const Color(0xFF00201D),
      secondaryContainer: const Color(0xFFD2E4FF),
      onSecondaryContainer: const Color(0xFF001C38),
      tertiary: const Color(0xFF315FAE),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFD9E2FF),
      onTertiaryContainer: const Color(0xFF001A41),
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surfaceDim: const Color(0xFFD3DDE6),
      surfaceBright: const Color(0xFFF7FAFD),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF0F5F9),
      surfaceContainer: const Color(0xFFEAF1F7),
      surfaceContainerHigh: const Color(0xFFE2EBF3),
      surfaceContainerHighest: const Color(0xFFDBE6F0),
    );
  }

  static ThemeData lightTheme({
    bool highContrast = false,
    AppThemePreset preset = AppThemePreset.ocean,
  }) {
    final colorScheme = _lightColorScheme(preset, highContrast);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: EndurainTypography.textTheme(colorScheme),
      scaffoldBackgroundColor: EndurainColors.lightBackground,
      listTileTheme: ListTileThemeData(
        textColor: colorScheme.onSurface,
        iconColor: highContrast
            ? colorScheme.onSurface
            : colorScheme.onSurfaceVariant,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: highContrast
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
          fontWeight: highContrast ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1.2,
        margin: EdgeInsets.zero,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: UIConstants.elevationNone,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: EndurainTypography.headline(colorScheme),
      ),
    );
  }

  static ThemeData darkTheme({
    bool highContrast = false,
    AppThemePreset preset = AppThemePreset.ocean,
  }) {
    final colorScheme = _darkColorScheme(preset, highContrast);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: EndurainTypography.textTheme(colorScheme),
      scaffoldBackgroundColor: EndurainColors.darkBackground,
      cardColor: colorScheme.surface,
      listTileTheme: ListTileThemeData(
        textColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: highContrast
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
          fontWeight: highContrast ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1.6,
        margin: EdgeInsets.zero,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: UIConstants.elevationNone,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: EndurainTypography.headline(colorScheme),
      ),
    );
  }

  static CupertinoThemeData cupertinoLightTheme({
    bool highContrast = false,
    AppThemePreset preset = AppThemePreset.ocean,
  }) {
    final colorScheme = _lightColorScheme(preset, highContrast);
    return CupertinoThemeData(
      primaryColor: colorScheme.primary,
      scaffoldBackgroundColor: EndurainColors.lightBackground,
      brightness: Brightness.light,
      textTheme: CupertinoTextThemeData(
        textStyle: EndurainTypography.textTheme(colorScheme).bodyMedium,
        navTitleTextStyle: EndurainTypography.headline(colorScheme),
      ),
    );
  }

  static CupertinoThemeData cupertinoDarkTheme({
    bool highContrast = false,
    AppThemePreset preset = AppThemePreset.ocean,
  }) {
    final colorScheme = _darkColorScheme(preset, highContrast);
    return CupertinoThemeData(
      primaryColor: colorScheme.primary,
      scaffoldBackgroundColor: EndurainColors.darkBackground,
      brightness: Brightness.dark,
      textTheme: CupertinoTextThemeData(
        textStyle: EndurainTypography.textTheme(colorScheme).bodyMedium,
        navTitleTextStyle: EndurainTypography.headline(colorScheme),
      ),
    );
  }
}
