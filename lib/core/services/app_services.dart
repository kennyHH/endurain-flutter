import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/core/services/app_links_service.dart';
import 'package:endurain/core/services/auth_session_store.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/diagnostics_service.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/package_info_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/server_settings_service.dart';
import 'package:endurain/core/services/sso_service.dart';
import 'package:endurain/core/services/url_launcher_service.dart';
import 'package:endurain/features/activity/repositories/activity_retention_settings_repository.dart';
import 'package:endurain/features/activity/repositories/local_activity_repository.dart';
import 'package:endurain/features/activity/services/activity_upload_service.dart';
import 'package:endurain/features/activity/services/local_activity_gpx_storage.dart';

class AppServices {
  AppServices._();

  static final AppServices instance = AppServices._();

  final DiagnosticsService diagnostics = DiagnosticsService();
  final SecureStorageService secureStorage = SecureStorageService();
  late final AuthSessionStore authSession = AuthSessionStore(
    storage: secureStorage,
  );
  late final AuthService auth = AuthService(
    storage: secureStorage,
    sessionStore: authSession,
  );
  late final SsoService sso = SsoService(
    storage: secureStorage,
    sessionStore: authSession,
  );
  late final ServerSettingsService serverSettings = ServerSettingsService(
    storage: secureStorage,
  );
  late final ApiClient apiClient = ApiClient(
    storage: secureStorage,
    authService: auth,
  );
  late final ActivityUploadService activityUpload = ActivityUploadService(
    apiClient: apiClient,
    config: const ActivityUploadConfig.endurain(),
  );
  final LocationService location = LocationService();
  late final LocalActivityGpxStorage localActivityGpxStorage =
      LocalActivityGpxStorage();
  late final LocalActivityRepository localActivities = LocalActivityRepository(
    gpxStorage: localActivityGpxStorage,
    diagnostics: diagnostics,
  );
  late final ActivityRetentionSettingsRepository activityRetentionSettings =
      ActivityRetentionSettingsRepository(storage: secureStorage);
  final AppLinksService appLinks = DefaultAppLinksService();
  final UrlLauncherService urlLauncher = const UrlLauncherService();
  final PackageInfoService packageInfo = const PackageInfoService();
}
