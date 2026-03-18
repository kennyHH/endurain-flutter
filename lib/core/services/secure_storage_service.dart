// ignore_for_file: deprecated_member_use

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

@singleton
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Keys for stored values
  static const _serverUrlKey = 'server_url';
  static const _usernameKey = 'username';
  static const _passwordKey = 'password';
  static const _tileServerUrlKey = 'tile_server_url';
  static const _tileServerAttributionKey = 'tile_server_attribution';
  static const _mapBackgroundColorKey = 'map_background_color';
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _sessionIdKey = 'session_id';
  static const _themeModeKey = 'theme_mode';
  static const _themePresetKey = 'theme_preset';
  static const _highContrastKey = 'high_contrast';
  static const _routeDisplayModeKey = 'route_display_mode';
  static const _gpsFilterModeKey = 'gps_filter_mode';
  static const _mapMatchingPreviewEnabledKey = 'map_matching_preview_enabled';
  static const _allowInsecureTlsKey = 'allow_insecure_tls';
  static const _metricConfigKey = 'metric_config';
  static const _lastLatitudeKey = 'last_known_latitude';
  static const _lastLongitudeKey = 'last_known_longitude';
  static const _lastLocationTimeKey = 'last_known_location_time';
  static const _ecoModeKey = 'eco_mode_enabled';
  static const _audioEnabledKey = 'audio_enabled';
  static const _audioVolumeKey = 'audio_volume';
  static const _permissionsOnboardingCompletedKey =
      'permissions_onboarding_completed';

  // Read a value
  Future<String?> read({required String key}) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      return null;
    }
  }

  // Write a value
  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      rethrow;
    }
  }

  // Delete a value
  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      rethrow;
    }
  }

  // Delete all values
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      rethrow;
    }
  }

  // Server-specific methods
  Future<String?> getServerUrl() => read(key: _serverUrlKey);
  Future<void> setServerUrl(String url) =>
      write(key: _serverUrlKey, value: url);
  Future<void> deleteServerUrl() => delete(key: _serverUrlKey);

  Future<String?> getUsername() => read(key: _usernameKey);
  Future<void> setUsername(String username) =>
      write(key: _usernameKey, value: username);
  Future<void> deleteUsername() => delete(key: _usernameKey);

  Future<String?> getPassword() => read(key: _passwordKey);
  Future<void> setPassword(String password) =>
      write(key: _passwordKey, value: password);
  Future<void> deletePassword() => delete(key: _passwordKey);

  Future<String?> getTileServerUrl() => read(key: _tileServerUrlKey);
  Future<void> setTileServerUrl(String url) =>
      write(key: _tileServerUrlKey, value: url);
  Future<void> deleteTileServerUrl() => delete(key: _tileServerUrlKey);

  Future<String?> getTileServerAttribution() =>
      read(key: _tileServerAttributionKey);
  Future<void> setTileServerAttribution(String attribution) =>
      write(key: _tileServerAttributionKey, value: attribution);
  Future<void> deleteTileServerAttribution() =>
      delete(key: _tileServerAttributionKey);

  Future<String?> getMapBackgroundColor() => read(key: _mapBackgroundColorKey);
  Future<void> setMapBackgroundColor(String color) =>
      write(key: _mapBackgroundColorKey, value: color);

  Future<bool> getEcoModeEnabled() async {
    final value = await read(key: _ecoModeKey);
    return value == 'true';
  }

  Future<void> setEcoModeEnabled(bool enabled) =>
      write(key: _ecoModeKey, value: enabled.toString());
  Future<void> deleteMapBackgroundColor() =>
      delete(key: _mapBackgroundColorKey);

  Future<bool> getAudioEnabled() async {
    final raw = await read(key: _audioEnabledKey);
    if (raw == null) return true;
    return raw == 'true';
  }

  Future<void> setAudioEnabled(bool enabled) =>
      write(key: _audioEnabledKey, value: enabled.toString());

  Future<double?> getAudioVolume() async {
    final raw = await read(key: _audioVolumeKey);
    if (raw == null) return null;
    return double.tryParse(raw);
  }

  Future<void> setAudioVolume(double volume) =>
      write(key: _audioVolumeKey, value: volume.toString());

  // Location caching
  Future<void> setLastLocation(double lat, double lng) async {
    await write(key: _lastLatitudeKey, value: lat.toString());
    await write(key: _lastLongitudeKey, value: lng.toString());
    await write(
      key: _lastLocationTimeKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<(double, double)?> getLastLocation() async {
    final latStr = await read(key: _lastLatitudeKey);
    final lngStr = await read(key: _lastLongitudeKey);
    final timeStr = await read(key: _lastLocationTimeKey);

    if (latStr == null || lngStr == null || timeStr == null) return null;

    try {
      final lat = double.parse(latStr);
      final lng = double.parse(lngStr);
      final time = DateTime.parse(timeStr);

      // If location is older than 24 hours, discard it
      if (DateTime.now().difference(time).inHours > 24) return null;

      return (lat, lng);
    } catch (_) {
      return null;
    }
  }

  // Token-specific methods
  Future<String?> getAccessToken() => read(key: _accessTokenKey);

  Future<String?> getMetricConfig() => read(key: _metricConfigKey);
  Future<void> setMetricConfig(String config) =>
      write(key: _metricConfigKey, value: config);
  Future<void> setAccessToken(String token) =>
      write(key: _accessTokenKey, value: token);
  Future<void> deleteAccessToken() => delete(key: _accessTokenKey);

  Future<String?> getRefreshToken() => read(key: _refreshTokenKey);
  Future<void> setRefreshToken(String token) =>
      write(key: _refreshTokenKey, value: token);
  Future<void> deleteRefreshToken() => delete(key: _refreshTokenKey);

  Future<String?> getSessionId() => read(key: _sessionIdKey);
  Future<void> setSessionId(String sessionId) =>
      write(key: _sessionIdKey, value: sessionId);
  Future<void> deleteSessionId() => delete(key: _sessionIdKey);

  // Appearance-specific methods
  Future<String?> getThemeMode() => read(key: _themeModeKey);
  Future<void> setThemeMode(String mode) =>
      write(key: _themeModeKey, value: mode);
  Future<void> deleteThemeMode() => delete(key: _themeModeKey);

  Future<String?> getThemePreset() => read(key: _themePresetKey);
  Future<void> setThemePreset(String preset) =>
      write(key: _themePresetKey, value: preset);
  Future<void> deleteThemePreset() => delete(key: _themePresetKey);

  Future<bool> getHighContrast() async {
    final raw = await read(key: _highContrastKey);
    return raw == 'true';
  }

  Future<void> setHighContrast(bool enabled) =>
      write(key: _highContrastKey, value: enabled.toString());
  Future<void> deleteHighContrast() => delete(key: _highContrastKey);

  Future<bool> getMapMatchingPreviewEnabled() async {
    final raw = await read(key: _mapMatchingPreviewEnabledKey);
    return raw == 'true';
  }

  Future<void> setMapMatchingPreviewEnabled(bool enabled) =>
      write(key: _mapMatchingPreviewEnabledKey, value: enabled.toString());
  Future<void> deleteMapMatchingPreviewEnabled() =>
      delete(key: _mapMatchingPreviewEnabledKey);

  Future<String?> getRouteDisplayMode() => read(key: _routeDisplayModeKey);
  Future<void> setRouteDisplayMode(String mode) =>
      write(key: _routeDisplayModeKey, value: mode);
  Future<void> deleteRouteDisplayMode() => delete(key: _routeDisplayModeKey);

  Future<String?> getGpsFilterMode() => read(key: _gpsFilterModeKey);
  Future<void> setGpsFilterMode(String mode) =>
      write(key: _gpsFilterModeKey, value: mode);
  Future<void> deleteGpsFilterMode() => delete(key: _gpsFilterModeKey);

  Future<bool> getAllowInsecureTls() async {
    final raw = await read(key: _allowInsecureTlsKey);
    return raw == 'true';
  }

  Future<void> setAllowInsecureTls(bool enabled) =>
      write(key: _allowInsecureTlsKey, value: enabled.toString());
  Future<void> deleteAllowInsecureTls() => delete(key: _allowInsecureTlsKey);

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  // Clear all auth tokens
  Future<void> clearAuthTokens() async {
    await deleteAccessToken();
    await deleteRefreshToken();
    await deleteSessionId();
  }

  Future<bool> getPermissionsOnboardingCompleted() async {
    final raw = await read(key: _permissionsOnboardingCompletedKey);
    return raw == 'true';
  }

  Future<void> setPermissionsOnboardingCompleted(bool completed) =>
      write(
        key: _permissionsOnboardingCompletedKey,
        value: completed.toString(),
      );

  Future<void> deletePermissionsOnboardingCompleted() =>
      delete(key: _permissionsOnboardingCompletedKey);
}
