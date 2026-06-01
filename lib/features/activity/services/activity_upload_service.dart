import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:http/http.dart' as http;

typedef ActivityFileUploader =
    Future<http.StreamedResponse> Function(
      String endpoint,
      String filePath,
      String fieldName,
    );

class ActivityUploadConfig {
  const ActivityUploadConfig({required this.endpoint, required this.fieldName});

  /// Default contract matching the Endurain server upload endpoint
  /// (`POST /api/v1/activities/create/upload` with a `file` multipart field).
  const ActivityUploadConfig.endurain()
    : endpoint = ApiConstants.activityUploadEndpoint,
      fieldName = ApiConstants.activityUploadFieldName;

  final String endpoint;
  final String fieldName;

  bool get isConfigured {
    return endpoint.trim().isNotEmpty && fieldName.trim().isNotEmpty;
  }
}

class ActivityUploadRequest {
  const ActivityUploadRequest({
    required this.filePath,
    required this.activityType,
  });

  final String filePath;
  final ActivityType activityType;
}

class ActivityUploadService {
  ActivityUploadService({
    ApiClient? apiClient,
    ActivityUploadConfig? config,
    ActivityFileUploader? uploadFile,
  }) : _config = config,
       _uploadFile = uploadFile ?? (apiClient ?? ApiClient()).uploadFile;

  final ActivityUploadConfig? _config;
  final ActivityFileUploader _uploadFile;

  bool get isConfigured => _config?.isConfigured ?? false;

  Future<void> uploadGpx(ActivityUploadRequest request) async {
    final config = _config;
    if (config == null || !config.isConfigured) {
      throw const AppException(AppErrorCode.activityUploadNotConfigured);
    }

    late final http.StreamedResponse response;
    try {
      response = await _uploadFile(
        config.endpoint,
        request.filePath,
        config.fieldName,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(AppErrorCode.activityUploadFailed, cause: error);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    if (response.statusCode == 401) {
      throw const AppException(AppErrorCode.sessionExpired);
    }

    throw AppException(
      AppErrorCode.activityUploadFailed,
      details: 'HTTP ${response.statusCode}',
    );
  }
}
