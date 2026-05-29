import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/features/map/map_screen.dart';
import 'package:endurain/features/settings/settings_screen.dart';
import 'package:endurain/shared/adaptive/adaptive.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AdaptiveBottomNavigation(
      tabs: [
        AdaptiveTab(
          label: l10n.mapTab,
          materialIcon: Icons.map,
          cupertinoIcon: CupertinoIcons.map,
          builder: (context) => const MapScreen(),
        ),
        AdaptiveTab(
          label: l10n.settingsTab,
          materialIcon: Icons.settings,
          cupertinoIcon: CupertinoIcons.settings,
          builder: (context) => SettingsScreen(onLogout: onLogout),
        ),
      ],
    );
  }
}
