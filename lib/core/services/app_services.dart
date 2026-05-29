import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/location_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/server_settings_service.dart';
import 'package:endurain/core/services/sso_service.dart';

class AppServices {
  AppServices._();

  static final AppServices instance = AppServices._();

  final SecureStorageService secureStorage = SecureStorageService();
  late final AuthService auth = AuthService(storage: secureStorage);
  late final SsoService sso = SsoService(storage: secureStorage);
  late final ServerSettingsService serverSettings = ServerSettingsService(
    storage: secureStorage,
  );
  late final ApiClient apiClient = ApiClient(
    storage: secureStorage,
    authService: auth,
  );
  final LocationService location = LocationService();
}
