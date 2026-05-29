import 'package:flutter/material.dart';
import 'package:endurain/core/navigation/app_routes.dart';
import 'package:endurain/core/services/app_services.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/features/auth/login_screen.dart';
import 'package:endurain/shared/adaptive/adaptive.dart';
import 'package:endurain/shared/widgets/app_bottom_nav.dart';

class App extends StatefulWidget {
  const App({super.key, this.authService});

  final AuthService? authService;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthService _authService;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AppServices.instance.auth;
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final isAuth = await _authService.isAuthenticated();
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
        _isLoading = false;
      });
    }
  }

  void _onLoginSuccess() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  void _onLogout() {
    setState(() {
      _isAuthenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = _isLoading
        ? AppRoutes.loading
        : _isAuthenticated
        ? AppRoutes.home
        : AppRoutes.login;

    return AdaptiveApp(title: 'Endurain', home: _buildRoute(route));
  }

  Widget _buildRoute(String route) {
    return switch (route) {
      AppRoutes.loading => const Center(child: AdaptiveLoadingIndicator()),
      AppRoutes.home => AppBottomNav(onLogout: _onLogout),
      AppRoutes.login => LoginScreen(onLoginSuccess: _onLoginSuccess),
      _ => const Center(child: AdaptiveLoadingIndicator()),
    };
  }
}
