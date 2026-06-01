import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/services/app_scope.dart';
import 'package:endurain/core/services/diagnostics_service.dart';
import 'package:endurain/core/services/package_info_service.dart';
import 'package:endurain/features/settings/diagnostics_screen.dart';
import 'package:endurain/features/settings/server_settings_screen.dart';
import 'package:endurain/core/constants/ui_constants.dart';
import 'package:endurain/shared/adaptive/adaptive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.onLogout,
    this.packageInfoService,
    this.diagnostics,
  });

  final VoidCallback? onLogout;
  final PackageInfoService? packageInfoService;
  final DiagnosticsStore? diagnostics;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  late final PackageInfoService _packageInfoService;

  @override
  void initState() {
    super.initState();
    _packageInfoService =
        widget.packageInfoService ??
        AppScope.servicesOf(context, listen: false).packageInfo;
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await _packageInfoService.fromPlatform();
    final currentYear = DateTime.now().year;
    if (mounted) {
      setState(() {
        _version =
            '© ${UIConstants.copyrightStartYear} - $currentYear Endurain • ${packageInfo.version}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AdaptiveScaffold(
      title: l10n.settingsScreen,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(UIConstants.paddingStandard),
              children: [
                AdaptiveListSection(
                  children: [
                    AdaptiveListTile(
                      leading: const AdaptiveIcon(
                        materialIcon: Icons.dns,
                        cupertinoIcon: CupertinoIcons.globe,
                      ),
                      title: l10n.serverSettings,
                      onTap: () {
                        adaptivePush<void>(
                          context,
                          (context) =>
                              ServerSettingsScreen(onLogout: widget.onLogout),
                        );
                      },
                    ),
                    AdaptiveListTile(
                      leading: const AdaptiveIcon(
                        materialIcon: Icons.bug_report,
                        cupertinoIcon: CupertinoIcons.waveform_path_ecg,
                      ),
                      title: l10n.diagnostics,
                      subtitle: l10n.diagnosticsSubtitle,
                      onTap: () {
                        adaptivePush<void>(
                          context,
                          (context) => DiagnosticsScreen(
                            diagnostics:
                                widget.diagnostics ??
                                AppScope.servicesOf(
                                  context,
                                  listen: false,
                                ).diagnostics,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: UIConstants.paddingStandard),
            child: Text(
              _version,
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
