import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/core/utils/validators.dart';
import 'package:endurain/core/utils/dialog_utils.dart';
import 'package:endurain/core/utils/error_mapper.dart';
import 'package:endurain/core/constants/ui_constants.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({
    super.key,
    this.onLogout,
    this.storage,
    this.authService,
  });

  final VoidCallback? onLogout;
  final SecureStorageService? storage;
  final AuthService? authService;

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tileServerUrlController = TextEditingController();
  final _defaultStorage = SecureStorageService();
  final _defaultAuthService = AuthService();
  bool _isLoading = true;
  String _serverUrl = '';
  String _username = '';

  SecureStorageService get _storage => widget.storage ?? _defaultStorage;
  AuthService get _authService => widget.authService ?? _defaultAuthService;

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
      setState(() {
        _serverUrl = serverUrl ?? 'Not configured';
        _username = username ?? 'Not logged in';
        _tileServerUrlController.text =
            tileServerUrl ?? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
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

      if (!mounted) return;
      await DialogUtils.showSuccessDialog(
        context,
        l10n.savedSuccessfully,
        onDismiss: () => Navigator.pop(context),
      );
    } catch (e) {
      if (!mounted) return;
      await DialogUtils.showErrorDialog(
        context,
        AppErrorMapper.toUserMessage(e, l10n),
      );
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

    if (!mounted || !confirmed) return;

    final serverLogoutSuccess = await _authService.logout();
    if (!mounted) return;

    // Show warning if server logout failed
    if (!serverLogoutSuccess) {
      if (PlatformUtils.isApplePlatform) {
        // iOS/macOS: Show banner
        await showCupertinoDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (context) => CupertinoAlertDialog(
            content: Text(l10n.logoutServerFailedWarning),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.ok),
              ),
            ],
          ),
        );
        if (!mounted) return;
      } else {
        // Android: Show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.logoutServerFailedWarning),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    // Pop back to settings screen and trigger logout
    Navigator.pop(context);
    widget.onLogout?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Cupertino style for iOS/macOS
    if (PlatformUtils.isApplePlatform) {
      if (_isLoading) {
        return const CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(),
          child: Center(child: CupertinoActivityIndicator()),
        );
      }

      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(l10n.serverSettingsTitle),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(UIConstants.paddingStandard),
              children: [
                CupertinoListSection.insetGrouped(
                  header: Text(l10n.loggedIn),
                  children: [
                    CupertinoListTile(
                      title: Text(l10n.serverUrl),
                      subtitle: Text(_serverUrl),
                    ),
                    CupertinoListTile(
                      title: Text(l10n.username),
                      subtitle: Text(_username),
                    ),
                    CupertinoListTile(
                      leading: const Icon(
                        CupertinoIcons.square_arrow_right,
                        color: CupertinoColors.systemRed,
                      ),
                      title: Text(
                        l10n.logout,
                        style: const TextStyle(
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                      onTap: _handleLogout,
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: Text(l10n.tileServerUrl),
                  children: [
                    CupertinoTextFormFieldRow(
                      controller: _tileServerUrlController,
                      placeholder: l10n.tileServerUrlHint,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      validator: (value) => Validators.validateUrl(value, l10n),
                      onFieldSubmitted: (_) => _saveSettings(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConstants.paddingStandard,
                  ),
                  child: CupertinoButton.filled(
                    onPressed: _saveSettings,
                    child: Text(l10n.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Material style for Android
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.serverSettingsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.serverSettingsTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsSectionHeader(title: l10n.loggedIn),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.dns_outlined),
                    title: Text(l10n.serverUrl),
                    subtitle: Text(
                      _serverUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(l10n.username),
                    subtitle: Text(
                      _username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SettingsSectionHeader(title: l10n.tileServerUrl),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextFormField(
                  controller: _tileServerUrlController,
                  decoration: InputDecoration(
                    hintText: l10n.tileServerUrlHint,
                    border: InputBorder.none,
                    icon: const Icon(Icons.map_outlined),
                    labelText: l10n.tileServerUrl,
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  validator: (value) => Validators.validateUrl(value, l10n),
                  onFieldSubmitted: (_) => _saveSettings(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: Text(l10n.save),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 40),
            OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout),
              label: Text(l10n.logout),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
