import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/core/services/secure_storage_service.dart';

class MapSettingsRepository {
  const MapSettingsRepository({required SecureStorageService storage})
    : _storage = storage;

  final SecureStorageService _storage;

  Future<String> getTileServerUrl() async {
    final tileUrl = await _storage.getTileServerUrl();
    if (tileUrl == null || tileUrl.isEmpty) {
      return MapConstants.defaultTileServerUrl;
    }
    return tileUrl;
  }

  Future<void> saveTileServerUrl(String url) {
    return _storage.setTileServerUrl(url);
  }
}
