import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/utils/validators.dart';
import 'package:endurain/core/utils/dialog_utils.dart';
import 'package:endurain/core/constants/ui_constants.dart';
import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/shared/adaptive/adaptive.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tileServerUrlController = TextEditingController();
  final _storage = SecureStorageService();
  final _authService = AuthService();
  bool _isLoading = true;
  String _serverUrl = '';
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _tileServerUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final serverUrl = await _storage.getServerUrl();
    final username = await _storage.getUsername();
    final tileServerUrl = await _storage.getTileServerUrl();

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;

      setState(() {
        _serverUrl = serverUrl ?? l10n.notConfigured;
        _username = username ?? l10n.notLoggedIn;
        _tileServerUrlController.text =
            tileServerUrl ?? MapConstants.defaultTileServerUrl;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    try {
      await _storage.setTileServerUrl(_tileServerUrlController.text.trim());

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          l10n.savedSuccessfully,
          onDismiss: () => Navigator.pop(context),
        );
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showErrorDialog(context, e);
      }
    }
  }

  Future<void> _handleLogout() async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await DialogUtils.showConfirmDialog(
      context,
      title: l10n.logoutConfirmTitle,
      message: l10n.logoutConfirmMessage,
      confirmText: l10n.logout,
      isDestructive: true,
    );

    if (confirmed && mounted) {
      final serverLogoutSuccess = await _authService.logout();
      if (mounted) {
        if (!serverLogoutSuccess) {
          await DialogUtils.showMessage(
            context,
            l10n.logoutServerFailedWarning,
          );

          if (!mounted) {
            return;
          }
        }
        // Pop back to settings screen and trigger logout
        Navigator.pop(context);
        widget.onLogout?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AdaptiveScaffold(
      title: l10n.serverSettingsTitle,
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(UIConstants.paddingStandard),
                children: [
                  AdaptiveListSection(
                    header: l10n.loggedIn,
                    children: [
                      AdaptiveListTile(
                        title: l10n.serverUrl,
                        subtitle: _serverUrl,
                      ),
                      AdaptiveListTile(
                        title: l10n.username,
                        subtitle: _username,
                      ),
                      AdaptiveListTile(
                        leading: const AdaptiveIcon(
                          materialIcon: Icons.logout,
                          cupertinoIcon: CupertinoIcons.square_arrow_right,
                          color: Colors.red,
                        ),
                        title: l10n.logout,
                        destructive: true,
                        onTap: _handleLogout,
                      ),
                    ],
                  ),
                  const SizedBox(height: UIConstants.paddingStandard),
                  AdaptiveTextFormField(
                    label: l10n.tileServerUrl,
                    placeholder: l10n.tileServerUrlHint,
                    controller: _tileServerUrlController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    validator: (value) => Validators.validateUrl(value, l10n),
                    onFieldSubmitted: (_) => _saveSettings(),
                  ),
                  const SizedBox(height: UIConstants.paddingLarge),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UIConstants.paddingStandard,
                    ),
                    child: AdaptiveButton(
                      label: l10n.save,
                      onPressed: _saveSettings,
                      expand: true,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
