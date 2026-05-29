import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:endurain/core/models/server_settings.dart';
import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/constants/api_constants.dart';

/// Service for fetching and managing server settings
class ServerSettingsService {
  ServerSettingsService({
    SecureStorageService? storage,
    http.Client? httpClient,
  }) : _storage = storage ?? SecureStorageService(),
       _httpClient = httpClient ?? http.Client();

  final SecureStorageService _storage;
  final http.Client _httpClient;

  /// Fetch server settings from the server
  Future<ServerSettings> getServerSettings({String? serverUrl}) async {
    // Use provided serverUrl or get from storage
    String? url = serverUrl;
    if (url == null || url.isEmpty) {
      url = await _storage.getServerUrl();
    }

    if (url == null || url.isEmpty) {
      throw const AppException(AppErrorCode.serverUrlNotConfigured);
    }

    final apiUrl = Uri.parse('$url${ApiConstants.serverSettingsEndpoint}');

    try {
      final response = await _httpClient.get(
        apiUrl,
        headers: {ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final settings = ServerSettings.fromJson(data);

        // Store tile server settings for later use
        if (settings.tileserverUrl != null &&
            settings.tileserverUrl!.isNotEmpty) {
          await _storage.setTileServerUrl(settings.tileserverUrl!);
        }
        if (settings.tileserverAttribution != null &&
            settings.tileserverAttribution!.isNotEmpty) {
          await _storage.setTileServerAttribution(
            settings.tileserverAttribution!,
          );
        }
        if (settings.mapBackgroundColor != null &&
            settings.mapBackgroundColor!.isNotEmpty) {
          await _storage.setMapBackgroundColor(settings.mapBackgroundColor!);
        }

        return settings;
      } else {
        final error = json.decode(response.body);
        throw AppException(
          AppErrorCode.fetchServerSettingsFailed,
          details: error['detail']?.toString(),
        );
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(AppErrorCode.fetchServerSettingsFailed, cause: e);
    }
  }
}
