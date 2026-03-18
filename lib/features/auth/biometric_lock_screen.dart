import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:endurain/core/theme/endurain_design_system.dart';

typedef BiometricAuthenticate = Future<bool> Function();

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({
    super.key,
    required this.onAuthenticated,
    this.authenticate,
  });

  final VoidCallback onAuthenticated;
  final BiometricAuthenticate? authenticate;

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  static bool _globalAuthInProgress = false;
  bool _isAuthenticating = false;
  String _authorized = 'Not Authorized';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating || _globalAuthInProgress) {
      return;
    }
    bool authenticated = false;
    try {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = true;
        _authorized = 'Authenticating';
      });
      _globalAuthInProgress = true;
      if (widget.authenticate != null) {
        authenticated = await widget.authenticate!();
      } else {
        authenticated = await auth.authenticate(
          localizedReason: 'Unlock Endurain to access your data',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _authorized = authenticated ? 'Authenticated' : 'Not Authorized';
      });
    } on PlatformException catch (e) {
      if (e.code == 'auth_in_progress') {
        if (!mounted) return;
        setState(() {
          _isAuthenticating = false;
          _authorized = 'Authenticating';
        });
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          _authenticate();
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _authorized = 'Authentication failed. Please try again.';
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _authorized = 'Authentication failed. Please try again.';
      });
      return;
    } finally {
      _globalAuthInProgress = false;
    }
    if (!mounted) {
      return;
    }

    if (authenticated) {
      widget.onAuthenticated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Replaced generic icon with Endurain branding
            Image.asset(
              'assets/images/endurain_logo.png', // Assuming logo exists, falling back to icon if not handled
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: EndurainColors.darkPrimary,
                );
              },
            ),
            const SizedBox(height: EndurainSpacing.lg),
            Text('Endurain Locked', style: theme.textTheme.headlineMedium),
            const SizedBox(height: EndurainSpacing.sm),
            if (_isAuthenticating)
              const CircularProgressIndicator()
            else
              Text(_authorized, style: theme.textTheme.bodyMedium),
            const SizedBox(height: EndurainSpacing.md),
            FilledButton.icon(
              onPressed: _authenticate,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
