import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:endurain/core/theme/app_theme.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/resume_token_refresh_coordinator.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/database/app_database.dart';
import 'package:endurain/core/services/storage_migration_service.dart';
import 'package:endurain/core/navigation/app_router.dart';
import 'package:endurain/features/settings/controllers/settings_controller.dart';
import 'package:endurain/core/di/service_locator.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late final AppDatabase _database;
  final _settingsController = serviceLocator<SettingsController>();
  late final ResumeTokenRefreshCoordinator _tokenRefreshCoordinator;
  Timer? _tokenRefreshTimer;

  @override
  void initState() {
    super.initState();
    _database = serviceLocator<AppDatabase>();
    _tokenRefreshCoordinator = ResumeTokenRefreshCoordinator(
      authService: serviceLocator<AuthService>(),
      storage: serviceLocator<SecureStorageService>(),
    );
    _initialize();
    WidgetsBinding.instance.addObserver(this);
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      _tokenRefreshCoordinator.triggerBestEffortRefresh();
    });
    _tokenRefreshCoordinator.triggerBestEffortRefresh();
  }

  Future<void> _initialize() async {
    try {
      final migrationService = StorageMigrationService(
        database: _database,
        storage: serviceLocator<SecureStorageService>(),
      );
      await migrationService.migrateFromLegacyStorage();
    } catch (e) {
      debugPrint('Migration failed: $e');
    }
    await _settingsController.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tokenRefreshCoordinator.triggerBestEffortRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settingsController,
      builder: (context, _) {
        return MaterialApp.router(
          routerConfig: AppRouter.router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('pt')],
          theme: AppTheme.lightTheme(
            highContrast: true,
            preset: _settingsController.themePreset,
          ),
          darkTheme: AppTheme.darkTheme(
            highContrast: true,
            preset: _settingsController.themePreset,
          ),
          themeMode: _settingsController.themeMode,
        );
      },
    );
  }
}
