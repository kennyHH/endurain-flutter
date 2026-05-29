import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:endurain/core/theme/app_theme.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/l10n/app_localizations.dart';

class AdaptiveApp extends StatelessWidget {
  const AdaptiveApp({super.key, required this.title, required this.home});

  final String title;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isApplePlatform) {
      return CupertinoApp(
        title: title,
        theme: AppTheme.cupertinoLightTheme,
        builder: (context, child) {
          final brightness = MediaQuery.platformBrightnessOf(context);
          return CupertinoTheme(
            data: brightness == Brightness.dark
                ? AppTheme.cupertinoDarkTheme
                : AppTheme.cupertinoLightTheme,
            child: child!,
          );
        },
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      );
    }

    return MaterialApp(
      title: title,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }
}
