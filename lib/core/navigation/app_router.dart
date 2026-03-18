import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:endurain/features/auth/biometric_lock_screen.dart';
import 'package:endurain/features/auth/login_screen.dart';
import 'package:endurain/shared/widgets/app_bottom_nav.dart';
import 'package:endurain/core/di/service_locator.dart';
import 'package:endurain/features/settings/controllers/settings_controller.dart';
import 'package:endurain/core/database/app_database.dart' hide Activity;
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/features/history/activity_detail_screen.dart';

// Keys for navigation
final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static const String login = '/login';
  static const String map = '/map';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String activityDetail = '/activity/:id';
  static const String lock = '/lock';

  static GoRouter get router => _router;

  static final _router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: map,
    refreshListenable: serviceLocator<SettingsController>(),
    redirect: _authRedirect,
    routes: [
      GoRoute(
        path: lock,
        name: 'lock',
        builder: (context, state) => BiometricLockScreen(
          onAuthenticated: () {
            serviceLocator<SettingsController>().unlock();
            context.go(map);
          },
        ),
      ),
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) =>
            LoginScreen(onLoginSuccess: () => context.go(map)),
      ),

      // Temporary: Simple route to AppBottomNav wrapper
      // In a real migration, we'd break down AppBottomNav into ShellRoute.
      // For this task "Replace Navigator.push", let's focus on screen-to-screen.
      GoRoute(
        path: map, // Acts as Home
        name: 'home',
        builder: (context, state) {
          // This is a temporary wrapper to satisfy GoRouter while we use AppBottomNav
          // In a full refactor, AppBottomNav logic would move here.
          // Since we can't easily inject the huge list of callbacks AppBottomNav needs without refactoring App.dart completely,
          // we will use a specialized wrapper widget that gets its dependencies from ServiceLocator or Providers.

          // But wait, App.dart is the parent of MaterialApp.router.
          // App.dart holds the state.
          // If we use GoRouter, App.dart's state is ABOVE the router.
          // So we can pass arguments to the router? No, router is declarative.

          // We must refactor AppBottomNav to not rely on App.dart state callbacks,
          // OR we wrap AppBottomNav in a widget that connects to the same state source.
          // Since we haven't implemented global state management (Bloc/Riverpod) yet,
          // we are in a tricky spot.

          // Solution for this task:
          // We will create a `MainScreen` widget that uses `AppBottomNav`.
          // We will move the state logic from `App.dart` (theme, settings) into `MainScreen` or a Controller.
          // Actually, we just refactored SettingsScreen to use a Controller!
          // So `AppBottomNav` doesn't need to pass theme callbacks anymore if SettingsScreen uses Controller.

          // Let's check AppBottomNav props.

          return const _MainScreenWrapper();
        },
      ),

      GoRoute(
        path: '/activity/:id',
        name: 'activity_detail',
        builder: (context, state) {
          final activity = state.extra as Activity?;
          final id = state.pathParameters['id']!;
          // If extra is null (deep link), we might need to fetch by ID.
          // ActivityDetailScreen expects an Activity object.
          // We should update ActivityDetailScreen to handle ID fetch or require object.
          if (activity != null) {
            return ActivityDetailScreen(activity: activity);
          }
          return Scaffold(
            body: Center(
              child: Text('Activity $id not found (Deep link unimplemented)'),
            ),
          );
        },
      ),
    ],
  );

  static Future<String?> _authRedirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    final settings = serviceLocator<SettingsController>();
    final isLocked = !settings.isUnlocked;
    final isLockScreen = state.uri.toString() == lock;

    if (isLocked && !isLockScreen) return lock;
    if (!isLocked && isLockScreen) return map;

    return null;
  }
}

class _MainScreenWrapper extends StatefulWidget {
  const _MainScreenWrapper();

  @override
  State<_MainScreenWrapper> createState() => _MainScreenWrapperState();
}

class _MainScreenWrapperState extends State<_MainScreenWrapper> {
  // Temporary: Re-implement necessary state logic or use service locator
  // Since we don't have a global state manager yet, and App.dart state is now above router
  // but we can't easily pass it down without InheritedWidget or Provider.

  // For this refactor, we rely on the fact that SettingsScreen now uses SettingsController.
  // So AppBottomNav just needs to be instantiated.
  // However, AppBottomNav constructor still requires parameters.
  // We need to update AppBottomNav to be more independent or provide default values/controllers.

  // Let's create a simplified AppBottomNav wrapper that uses SettingsController internally?
  // Or better, let's just instantiate AppBottomNav with dummy callbacks where possible,
  // relying on the Controller for actual logic.

  @override
  Widget build(BuildContext context) {
    // We need to fetch current theme/settings to pass to AppBottomNav if it still requires them.
    // Let's check AppBottomNav definition.
    // It requires 'themeMode', 'highContrast', etc.

    // We can get these from SettingsController!
    final settingsController = serviceLocator<SettingsController>();

    return ListenableBuilder(
      listenable: settingsController,
      builder: (context, _) {
        return AppBottomNav(
          database: serviceLocator<AppDatabase>(),
          themeMode: settingsController.themeMode,
          ecoModeEnabled: settingsController.ecoModeEnabled,
          routeDisplayMode: settingsController.routeDisplayMode,
          gpsFilterMode: settingsController.gpsFilterMode,
          allowInsecureTls: settingsController.allowInsecureTls,
          selectedThemePreset: settingsController.themePreset,
        );
      },
    );
  }
}
