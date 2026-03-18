import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:endurain/core/theme/app_theme.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
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

class _AppState extends State<App> {
  late final AppDatabase _database;
  final _settingsController = serviceLocator<SettingsController>();

  @override
  void initState() {
    super.initState();
    _database = serviceLocator<AppDatabase>();
    _initialize();
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
