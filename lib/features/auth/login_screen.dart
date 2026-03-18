import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/models/identity_provider.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/core/utils/validators.dart';
import 'package:endurain/core/error_handling/error_handler_service.dart';
import 'package:endurain/core/constants/ui_constants.dart';
import 'package:endurain/features/auth/sso_webview_screen.dart';
import 'package:endurain/shared/widgets/brand_logo.dart';
import 'package:endurain/features/auth/controllers/login_controller.dart';
import 'package:endurain/core/di/service_locator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.onLoginSuccess,
    this.loginController, // Allow injection for testing
  });

  final VoidCallback? onLoginSuccess;
  final LoginController? loginController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaCodeController = TextEditingController();

  late final LoginController _controller;
  late final ErrorHandlerService _errorHandler;

  @override
  void initState() {
    super.initState();
    _controller = widget.loginController ?? serviceLocator<LoginController>();
    _errorHandler = serviceLocator<ErrorHandlerService>();
    _controller.addListener(_onControllerStateChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerStateChange);
    if (widget.loginController == null) {
      _controller
          .dispose(); // Only dispose if we created it (via get_it factory)
    }
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _mfaCodeController.dispose();
    super.dispose();
  }

  void _onControllerStateChange() {
    if (!mounted) return;

    if (_controller.error != null) {
      _errorHandler.showError(context: context, error: _controller.error);
      _controller.clearError();
    }

    if (_controller.loginSuccess) {
      widget.onLoginSuccess?.call();
    }
  }

  Future<void> _handleServerUrlNext() async {
    if (!_formKey.currentState!.validate()) return;
    await _controller.checkServerUrl(_serverUrlController.text.trim());
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    await _controller.login(
      _usernameController.text.trim(),
      _passwordController.text,
      _serverUrlController.text.trim(),
    );
  }

  Future<void> _handleMfaVerification() async {
    final l10n = AppLocalizations.of(context)!;
    if (_mfaCodeController.text.trim().isEmpty) {
      _errorHandler.showError(context: context, error: l10n.mfaCodeRequired);
      return;
    }
    await _controller.verifyMfa(_mfaCodeController.text.trim());
  }

  Future<void> _handleSsoLogin(IdentityProvider idp) async {
    final oauthUrl = await _controller.initiateSso(
      idp.slug,
      _serverUrlController.text.trim(),
    );

    if (oauthUrl != null && mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) => SsoWebViewScreen(
            oauthUrl: oauthUrl,
            onSessionIdReceived: (sessionId) async {
              await _controller.completeSso(sessionId);
            },
            onError: (error) {
              _controller.handleSsoError(error);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        // Cupertino style for iOS/macOS
        if (PlatformUtils.isApplePlatform) {
          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text(
                _controller.showMfaInput ? l10n.mfaTitle : l10n.loginTitle,
              ),
              leading: _controller.isStep2 && !_controller.showMfaInput
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _controller.resetStep2,
                      child: const Icon(CupertinoIcons.back),
                    )
                  : null,
            ),
            child: SafeArea(
              child: _controller.isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _buildForm(l10n, isCupertino: true),
            ),
          );
        }

        // Material style for Android
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _controller.showMfaInput ? l10n.mfaTitle : l10n.loginTitle,
            ),
            leading: _controller.isStep2 && !_controller.showMfaInput
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _controller.resetStep2,
                  )
                : null,
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildForm(l10n, isCupertino: false),
        );
      },
    );
  }

  Widget _buildForm(AppLocalizations l10n, {required bool isCupertino}) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(UIConstants.paddingStandard),
        children: [
          const SizedBox(height: 40),
          const Center(child: BrandLogo(size: 120)),
          const SizedBox(height: 40),
          if (!_controller.showMfaInput) ...[
            if (!_controller.isStep2)
              _buildStep1(l10n, isCupertino)
            else
              _buildStep2(l10n, isCupertino),
          ] else
            _buildMfaStep(l10n, isCupertino),
        ],
      ),
    );
  }

  Widget _buildStep1(AppLocalizations l10n, bool isCupertino) {
    if (isCupertino) {
      return Column(
        children: [
          CupertinoListSection.insetGrouped(
            header: Text(l10n.serverUrl.toUpperCase()),
            children: [
              CupertinoTextFormFieldRow(
                controller: _serverUrlController,
                placeholder: l10n.serverUrlHint,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                validator: (value) => Validators.validateServerUrl(value, l10n),
                onFieldSubmitted: (_) => _handleServerUrlNext(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _handleServerUrlNext,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.next),
                    const SizedBox(width: 6),
                    const Icon(
                      CupertinoIcons.arrow_right,
                      size: 16,
                      color: CupertinoColors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        TextFormField(
          controller: _serverUrlController,
          decoration: InputDecoration(
            labelText: l10n.serverUrl,
            hintText: l10n.serverUrlHint,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          validator: (value) => Validators.validateServerUrl(value, l10n),
          onFieldSubmitted: (_) => _handleServerUrlNext(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _handleServerUrlNext,
            label: Text(l10n.next),
            icon: const Icon(Icons.arrow_forward),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(AppLocalizations l10n, bool isCupertino) {
    return Column(
      children: [
        if (_controller.localLoginEnabled) ...[
          if (isCupertino) ...[
            CupertinoListSection.insetGrouped(
              header: Text(l10n.username.toUpperCase()),
              children: [
                CupertinoTextFormFieldRow(
                  controller: _usernameController,
                  placeholder: l10n.usernameHint,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      Validators.validateRequired(value, l10n, l10n.username),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: Text(l10n.password.toUpperCase()),
              children: [
                CupertinoTextFormFieldRow(
                  controller: _passwordController,
                  placeholder: l10n.passwordHint,
                  obscureText: _controller.obscurePassword,
                  textInputAction: TextInputAction.done,
                  validator: (value) =>
                      Validators.validateRequired(value, l10n, l10n.password),
                  onFieldSubmitted: (_) => _handleLogin(),
                ),
                CupertinoListTile(
                  title: Text(l10n.showPassword),
                  trailing: CupertinoSwitch(
                    value: !_controller.obscurePassword,
                    onChanged: (_) => _controller.togglePasswordVisibility(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _handleLogin,
                  child: Text(l10n.login),
                ),
              ),
            ),
          ] else ...[
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: l10n.username,
                hintText: l10n.usernameHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  Validators.validateRequired(value, l10n, l10n.username),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: l10n.password,
                hintText: l10n.passwordHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _controller.obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: _controller.togglePasswordVisibility,
                ),
              ),
              obscureText: _controller.obscurePassword,
              textInputAction: TextInputAction.done,
              validator: (value) =>
                  Validators.validateRequired(value, l10n, l10n.password),
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _handleLogin,
                child: Text(l10n.login),
              ),
            ),
          ],
        ],
        if (_controller.availableIdPs.isNotEmpty) ...[
          if (_controller.localLoginEnabled) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    l10n.ssoOrDivider,
                    style: TextStyle(
                      color: isCupertino
                          ? CupertinoColors.systemGrey
                          : Colors.grey,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ],
          const SizedBox(height: 16),
          for (final idp in _controller.availableIdPs)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              child: SizedBox(
                width: double.infinity,
                child: isCupertino
                    ? CupertinoButton(
                        color: CupertinoColors.systemGrey6,
                        onPressed: () => _handleSsoLogin(idp),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSsoIcon(idp, isCupertino: true),
                            const SizedBox(width: 12),
                            Text(
                              idp.name,
                              style: const TextStyle(
                                color: CupertinoColors.label,
                              ),
                            ),
                          ],
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => _handleSsoLogin(idp),
                        icon: _buildSsoIcon(idp, isCupertino: false),
                        label: Text(idp.name),
                      ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildMfaStep(AppLocalizations l10n, bool isCupertino) {
    if (isCupertino) {
      return Column(
        children: [
          CupertinoListSection.insetGrouped(
            header: Text(l10n.mfaCode.toUpperCase()),
            children: [
              CupertinoTextFormFieldRow(
                controller: _mfaCodeController,
                placeholder: l10n.mfaCodeHint,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleMfaVerification(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _handleMfaVerification,
                child: Text(l10n.verify),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        TextFormField(
          controller: _mfaCodeController,
          decoration: InputDecoration(
            labelText: l10n.mfaCode,
            hintText: l10n.mfaCodeHint,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleMfaVerification(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _handleMfaVerification,
            child: Text(l10n.verify),
          ),
        ),
      ],
    );
  }

  Widget _buildSsoIcon(IdentityProvider idp, {bool isCupertino = false}) {
    if (idp.icon == null || idp.icon!.isEmpty) {
      return Icon(
        isCupertino ? CupertinoIcons.person_circle : Icons.person_outline,
        size: 24,
        color: isCupertino ? CupertinoColors.white : null,
      );
    }

    const localAssets = [
      'authelia',
      'authentik',
      'casdoor',
      'keycloak',
      'pocketid',
    ];
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
        // Fallback
      }
    }

    return Image.network(
      idp.icon!,
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) => Icon(
        isCupertino ? CupertinoIcons.person_circle : Icons.person_outline,
        size: 24,
        color: isCupertino ? CupertinoColors.white : null,
      ),
    );
  }
}
