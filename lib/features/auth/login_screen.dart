import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/sso_service.dart';
import 'package:endurain/core/services/server_settings_service.dart';
import 'package:endurain/core/models/identity_provider.dart';
import 'package:endurain/core/models/server_settings.dart';
import 'package:endurain/core/utils/validators.dart';
import 'package:endurain/core/utils/dialog_utils.dart';
import 'package:endurain/core/constants/ui_constants.dart';
import 'package:endurain/shared/adaptive/adaptive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaCodeController = TextEditingController();
  final _authService = AuthService();
  final _ssoService = SsoService();
  final _serverSettingsService = ServerSettingsService();
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showMfaInput = false;
  bool _isStep2 =
      false; // Two-step flow: Step 1 = server URL, Step 2 = login/SSO
  String? _mfaUsername;
  List<IdentityProvider> _availableIdPs = [];
  ServerSettings? _serverSettings;

  @override
  void initState() {
    super.initState();
    _initializeSsoCallbackListener();
  }

  /// Whether local login (username/password) is enabled
  bool get _localLoginEnabled => _serverSettings?.localLoginEnabled ?? true;

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _mfaCodeController.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initializeSsoCallbackListener() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleSsoCallbackUri,
      onError: (Object error) {
        if (mounted) {
          _showError(error);
        }
      },
    );
  }

  Future<void> _handleSsoCallbackUri(Uri uri) async {
    if (uri.scheme != 'endurain' ||
        uri.host != 'auth' ||
        uri.path != '/sso/callback') {
      return;
    }

    final sessionId = uri.queryParameters['session_id'];
    final error =
        uri.queryParameters['message'] ?? uri.queryParameters['error'];

    if (error != null && error.isNotEmpty) {
      _ssoService.clearPkce();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError(error);
      }
      return;
    }

    if (sessionId == null || sessionId.isEmpty) {
      _ssoService.clearPkce();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _isLoading = false;
        });
        _showError(l10n.ssoMissingSessionId);
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await _ssoService.exchangeSessionForTokens(sessionId);
      if (mounted) {
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError(e);
      }
    }
  }

  /// Step 1: Validate server URL, fetch server settings and available IdPs
  Future<void> _handleServerUrlNext() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final serverUrl = _serverUrlController.text.trim();

      // First, fetch server settings
      final settings = await _serverSettingsService.getServerSettings(
        serverUrl: serverUrl,
      );

      // Store settings
      _serverSettings = settings;

      // Only fetch SSO providers if SSO is enabled
      List<IdentityProvider> idps = [];
      if (settings.ssoEnabled) {
        try {
          idps = await _ssoService.getEnabledProviders(serverUrl: serverUrl);
        } catch (e) {
          // If SSO fetch fails, continue with empty list
          idps = [];
        }
      }

      if (mounted) {
        setState(() {
          _availableIdPs = idps;
          _isStep2 = true;
          _isLoading = false;
        });

        // Auto-redirect to SSO if:
        // - SSO is enabled
        // - Only one provider available
        // - sso_auto_redirect is true
        if (settings.ssoEnabled &&
            settings.ssoAutoRedirect &&
            idps.length == 1) {
          // Slight delay to show the step 2 briefly before redirecting
          await Future<void>.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            await _handleSsoLogin(idps.first);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // If server settings fetch fails, show error
        _showError(e);
      }
    }
  }

  /// Handle SSO provider selection
  Future<void> _handleSsoLogin(IdentityProvider idp) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final oauthUrl = await _ssoService.initiateOAuth(
        idp.slug,
        serverUrl: _serverUrlController.text.trim(),
      );

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;

        setState(() {
          _isLoading = false;
        });

        final launched = await launchUrl(
          Uri.parse(oauthUrl),
          mode: LaunchMode.externalApplication,
        );

        if (!launched && mounted) {
          _ssoService.clearPkce();
          _showError(l10n.ssoBrowserLaunchFailed);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError(e);
      }
    }
  }

  /// Step 2: Traditional username/password login
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
        serverUrl: _serverUrlController.text.trim(),
      );

      if (mounted) {
        if (result.mfaRequired) {
          // Show MFA input
          setState(() {
            _showMfaInput = true;
            _mfaUsername = result.username;
            _isLoading = false;
          });
        } else {
          // Login successful, notify parent or navigate
          widget.onLoginSuccess?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError(e);
      }
    }
  }

  Future<void> _handleMfaVerification() async {
    final l10n = AppLocalizations.of(context)!;
    if (_mfaCodeController.text.trim().isEmpty) {
      _showError(l10n.mfaCodeRequired);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.verifyMfa(
        _mfaUsername!,
        _mfaCodeController.text.trim(),
      );

      if (mounted) {
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError(e);
      }
    }
  }

  void _showError(Object message) {
    DialogUtils.showErrorDialog(context, message);
  }

  void _goBackToServerStep() {
    setState(() {
      _isStep2 = false;
      _availableIdPs = [];
      _serverSettings = null;
    });
  }

  void _goBackFromMfa() {
    setState(() {
      _showMfaInput = false;
      _mfaCodeController.clear();
    });
  }

  /// Build SSO provider icon widget
  /// Checks for local asset first, then tries URL, with fallback icon
  Widget _buildSsoIcon(IdentityProvider idp) {
    if (idp.icon == null || idp.icon!.isEmpty) {
      return const AdaptiveIcon(
        materialIcon: Icons.person_outline,
        cupertinoIcon: CupertinoIcons.person_circle,
        size: 24,
      );
    }

    // List of available local assets
    const localAssets = [
      'authelia',
      'authentik',
      'casdoor',
      'keycloak',
      'pocketid',
    ];

    // Check if icon matches a local asset (case-insensitive)
    final iconLower = idp.icon!.toLowerCase();

    if (localAssets.contains(iconLower)) {
      final assetPath = 'assets/sso/$iconLower.svg';
      try {
        return SvgPicture.asset(
          assetPath,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
        );
      } catch (e) {
        return const AdaptiveIcon(
          materialIcon: Icons.person_outline,
          cupertinoIcon: CupertinoIcons.person_circle,
          size: 24,
        );
      }
    }

    // Try to load from URL
    return Image.network(
      idp.icon!,
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) => const AdaptiveIcon(
        materialIcon: Icons.person_outline,
        cupertinoIcon: CupertinoIcons.person_circle,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AdaptiveScaffold(
      title: _showMfaInput ? l10n.mfaTitle : l10n.loginTitle,
      leading: _isStep2 && !_showMfaInput
          ? AdaptiveBackButton(onPressed: _goBackToServerStep)
          : null,
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(UIConstants.paddingStandard),
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Image.asset(
                      'assets/logo/logo.png',
                      width: 120,
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_showMfaInput)
                    ..._buildMfaFields(l10n)
                  else if (_isStep2)
                    ..._buildLoginFields(l10n)
                  else
                    ..._buildServerUrlFields(l10n),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildServerUrlFields(AppLocalizations l10n) {
    return [
      AdaptiveTextFormField(
        label: l10n.serverUrl,
        placeholder: l10n.serverUrlHint,
        controller: _serverUrlController,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        prefixIcon: const Icon(Icons.dns),
        validator: (value) => Validators.validateUrl(value, l10n),
        onFieldSubmitted: (_) => _handleServerUrlNext(),
      ),
      const SizedBox(height: UIConstants.paddingLarge),
      AdaptiveButton(
        label: l10n.next,
        onPressed: _handleServerUrlNext,
        expand: true,
      ),
    ];
  }

  List<Widget> _buildLoginFields(AppLocalizations l10n) {
    return [
      if (_localLoginEnabled) ...[
        AdaptiveTextFormField(
          label: l10n.username,
          placeholder: l10n.usernameHint,
          controller: _usernameController,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.person),
          validator: (value) =>
              Validators.validateRequired(value, l10n, l10n.username),
        ),
        const SizedBox(height: UIConstants.paddingStandard),
        AdaptiveTextFormField(
          label: l10n.password,
          placeholder: l10n.passwordHint,
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          prefixIcon: const Icon(Icons.lock),
          validator: (value) =>
              Validators.validateRequired(value, l10n, l10n.password),
          onFieldSubmitted: (_) => _handleLogin(),
        ),
        AdaptiveSwitchListTile(
          title: l10n.showPassword,
          value: !_obscurePassword,
          onChanged: (value) {
            setState(() {
              _obscurePassword = !value;
            });
          },
        ),
        const SizedBox(height: UIConstants.paddingLarge),
        AdaptiveButton(
          label: l10n.login,
          onPressed: _handleLogin,
          expand: true,
        ),
      ],
      if (_availableIdPs.isNotEmpty) ...[
        if (_localLoginEnabled) ...[
          const SizedBox(height: UIConstants.paddingLarge),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UIConstants.paddingStandard,
                ),
                child: Text(l10n.ssoOrDivider),
              ),
              const Expanded(child: Divider()),
            ],
          ),
        ],
        const SizedBox(height: UIConstants.paddingStandard),
        for (final idp in _availableIdPs) ...[
          AdaptiveButton(
            label: l10n.ssoSignInWith(idp.name),
            icon: _buildSsoIcon(idp),
            onPressed: () => _handleSsoLogin(idp),
            expand: true,
          ),
          const SizedBox(height: UIConstants.paddingMedium),
        ],
      ],
    ];
  }

  List<Widget> _buildMfaFields(AppLocalizations l10n) {
    return [
      AdaptiveTextFormField(
        label: l10n.mfaCode,
        placeholder: l10n.mfaCodeHint,
        controller: _mfaCodeController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        prefixIcon: const Icon(Icons.security),
        validator: (value) =>
            Validators.validateRequired(value, l10n, l10n.mfaCode),
        onFieldSubmitted: (_) => _handleMfaVerification(),
      ),
      const SizedBox(height: UIConstants.paddingLarge),
      AdaptiveButton(
        label: l10n.verify,
        onPressed: _handleMfaVerification,
        expand: true,
      ),
      const SizedBox(height: UIConstants.paddingStandard),
      AdaptiveButton(
        label: l10n.back,
        onPressed: _goBackFromMfa,
        variant: AdaptiveButtonVariant.secondary,
        expand: true,
      ),
    ];
  }
}
