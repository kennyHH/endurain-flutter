import 'dart:convert';
import 'package:endurain/core/models/server_settings.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/services/api_request_executor.dart';

/// Service for fetching and managing server settings
class ServerSettingsService {
  ServerSettingsService({
    SecureStorageService? storage,
    ApiRequestExecutor? requestExecutor,
  }) : _storage = storage ?? SecureStorageService(),
       _requestExecutor = requestExecutor ?? ApiRequestExecutor();

  final SecureStorageService _storage;
  final ApiRequestExecutor _requestExecutor;

  /// Fetch server settings from the server
  Future<ServerSettings> getServerSettings({String? serverUrl}) async {
    // Use provided serverUrl or get from storage
    String? url = serverUrl;
    if (url == null || url.isEmpty) {
      url = await _storage.getServerUrl();
    }

    if (url == null || url.isEmpty) {
      throw Exception('Server URL not configured');
    }

    try {
      final response = await _requestExecutor.request(
        method: 'GET',
        serverUrl: url,
        endpoint: ApiConstants.serverSettingsEndpoint,
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
        throw Exception(error['detail'] ?? 'Failed to fetch server settings');
      }
    } on ApiRequestException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to fetch server settings: $e');
    }
  }
}
