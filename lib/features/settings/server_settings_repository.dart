import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/features/map/map_settings_repository.dart';

class StoredServerSettings {
  const StoredServerSettings({
    required this.serverUrl,
    required this.username,
    required this.tileServerUrl,
  });

  final String? serverUrl;
  final String? username;
  final String tileServerUrl;
}

class ServerSettingsRepository {
  const ServerSettingsRepository({
    required SecureStorageService storage,
    required AuthService authService,
    required MapSettingsRepository mapSettingsRepository,
  }) : _storage = storage,
       _authService = authService,
       _mapSettingsRepository = mapSettingsRepository;

  final SecureStorageService _storage;
  final AuthService _authService;
  final MapSettingsRepository _mapSettingsRepository;

  Future<StoredServerSettings> loadSettings() async {
    final serverUrl = await _storage.getServerUrl();
    final username = await _storage.getUsername();
    final tileServerUrl = await _mapSettingsRepository.getTileServerUrl();

    return StoredServerSettings(
      serverUrl: serverUrl,
      username: username,
      tileServerUrl: tileServerUrl.isEmpty
          ? MapConstants.defaultTileServerUrl
          : tileServerUrl,
    );
  }

  Future<void> saveTileServerUrl(String url) {
    return _mapSettingsRepository.saveTileServerUrl(url);
  }

  Future<bool> logout() {
    return _authService.logout();
  }
}
