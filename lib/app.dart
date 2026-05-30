import 'package:flutter/material.dart';
import 'package:endurain/core/navigation/app_routes.dart';
import 'package:endurain/core/services/app_scope.dart';
import 'package:endurain/core/services/app_services.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/features/auth/auth_session_controller.dart';
import 'package:endurain/features/auth/login_screen.dart';
import 'package:endurain/shared/adaptive/adaptive.dart';
import 'package:endurain/shared/widgets/app_bottom_nav.dart';

class App extends StatefulWidget {
  const App({super.key, this.authService, this.sessionController});

  final AuthService? authService;
  final AuthSessionController? sessionController;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AppServices _services;
  late final AuthSessionController _sessionController;
  late final bool _ownsSessionController;

  @override
  void initState() {
    super.initState();
    _services = AppServices.instance;
    _ownsSessionController = widget.sessionController == null;
    _sessionController =
        widget.sessionController ??
        AuthSessionController(
          authService: widget.authService ?? _services.auth,
        );
    _sessionController.addListener(_handleSessionChanged);
    _sessionController.initialize();
  }

  @override
  void dispose() {
    _sessionController.removeListener(_handleSessionChanged);
    if (_ownsSessionController) {
      _sessionController.dispose();
    }
    super.dispose();
  }

  void _handleSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onLoginSuccess() {
    _sessionController.markAuthenticated();
  }

  void _onLogout() {
    _sessionController.markUnauthenticated();
  }

  @override
  Widget build(BuildContext context) {
    final route = _sessionController.isLoading
        ? AppRoutes.loading
        : _sessionController.isAuthenticated
        ? AppRoutes.home
        : AppRoutes.login;

    return AppScope(
      services: _services,
      child: AdaptiveApp(title: 'Endurain', home: _buildRoute(route)),
    );
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
