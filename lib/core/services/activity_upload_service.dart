import 'dart:convert';

import 'package:endurain/core/constants/api_constants.dart';
import 'package:endurain/core/constants/upload_constants.dart';
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/api_request_executor.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/gpx_exporter.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:http/http.dart' as http;

enum ActivityUploadFailureType {
  configuration,
  authentication,
  server,
  network,
  unknown,
}

class ActivityUploadResult {
  const ActivityUploadResult._({
    required this.success,
    required this.attempts,
    this.statusCode,
    this.failureType,
    this.serverDetail,
  });

  final bool success;
  final int attempts;
  final int? statusCode;
  final ActivityUploadFailureType? failureType;
  final String? serverDetail;

  factory ActivityUploadResult.success({
    required int attempts,
    int? statusCode,
    String? serverDetail,
  }) {
    return ActivityUploadResult._(
      success: true,
      attempts: attempts,
      statusCode: statusCode,
      serverDetail: serverDetail,
    );
  }

  factory ActivityUploadResult.failure({
    required int attempts,
    required ActivityUploadFailureType failureType,
    int? statusCode,
    String? serverDetail,
  }) {
    return ActivityUploadResult._(
      success: false,
      attempts: attempts,
      statusCode: statusCode,
      failureType: failureType,
      serverDetail: serverDetail,
    );
  }
}

class ActivityUploadService {
  ActivityUploadService({
    SecureStorageService? storage,
    AuthService? authService,
    ApiRequestExecutor? requestExecutor,
    GpxExporter? gpxExporter,
    this.uploadEndpoint = UploadConstants.activityUploadEndpoint,
    this.maxRetries = UploadConstants.defaultUploadRetries,
  }) : _storage = storage ?? SecureStorageService(),
       _authService = authService ?? AuthService(),
       _requestExecutor = requestExecutor ?? ApiRequestExecutor(),
       _gpxExporter = gpxExporter ?? GpxExporter();

  final SecureStorageService _storage;
  final AuthService _authService;
  final ApiRequestExecutor _requestExecutor;
  final GpxExporter _gpxExporter;
  final String uploadEndpoint;
  final int maxRetries;

  Future<ActivityUploadResult> deleteActivity(Activity activity) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      return ActivityUploadResult.failure(
        attempts: 0,
        failureType: ActivityUploadFailureType.configuration,
      );
    }
    final accessToken = await _storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return ActivityUploadResult.failure(
        attempts: 0,
        failureType: ActivityUploadFailureType.authentication,
      );
    }

    final encodedId = Uri.encodeComponent(activity.id);
    final endpoints = <String>[
      '/api/v1/activities/$encodedId',
      '/api/v1/activities/delete/$encodedId',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _requestExecutor.request(
          method: 'DELETE',
          serverUrl: serverUrl,
          endpoint: endpoint,
          headers: {ApiConstants.authorizationHeader: 'Bearer $accessToken'},
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ActivityUploadResult.success(
            attempts: 1,
            statusCode: response.statusCode,
            serverDetail: _extractServerDetail(response),
          );
        }
      } catch (_) {
        // Try next endpoint fallback.
      }
    }

    return ActivityUploadResult.failure(
      attempts: 1,
      failureType: ActivityUploadFailureType.server,
    );
  }

  Future<ActivityUploadResult> uploadActivity(Activity activity) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      return ActivityUploadResult.failure(
        attempts: 0,
        failureType: ActivityUploadFailureType.configuration,
      );
    }

    String? accessToken = await _storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return ActivityUploadResult.failure(
        attempts: 0,
        failureType: ActivityUploadFailureType.authentication,
      );
    }

    final gpx = _gpxExporter.export(activity);
    final maxAttempts = maxRetries + 1;
    var refreshAttempted = false;
    final methodCandidates = <String>['POST', 'PUT', 'PATCH'];
    final fileFieldCandidates = <String>[
      UploadConstants.multipartFileField,
      ...UploadConstants.multipartFileFieldFallbacks,
    ];
    final endpointCandidates = <String>{
      uploadEndpoint,
      '/api/v1/activities/create/upload',
      '/api/v1/activities/import',
      '/api/v1/activities/upload',
      '/api/v1/activities',
    }.toList();

    attemptLoop:
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        var retryWithRefreshedToken = false;
        ActivityUploadResult? exhaustedClientFailure;
        endpointLoop:
        for (final endpoint in endpointCandidates) {
          methodLoop:
          for (final method in methodCandidates) {
            for (final fileField in fileFieldCandidates) {
              final response = await _requestExecutor.requestMultipart(
                method: method,
                serverUrl: serverUrl,
                endpoint: endpoint,
                headers: {
                  ApiConstants.authorizationHeader: 'Bearer $accessToken',
                },
                files: [
                  http.MultipartFile.fromString(
                    fileField,
                    gpx,
                    filename: UploadConstants.defaultGpxFilename,
                  ),
                ],
              );

              if (response.statusCode >= 200 && response.statusCode < 300) {
                return ActivityUploadResult.success(
                  attempts: attempt,
                  statusCode: response.statusCode,
                  serverDetail: _extractServerDetail(response),
                );
              }

              if (response.statusCode == 401) {
                if (refreshAttempted) {
                  return ActivityUploadResult.failure(
                    attempts: attempt,
                    statusCode: response.statusCode,
                    failureType: ActivityUploadFailureType.authentication,
                    serverDetail: _extractServerDetail(response),
                  );
                }
                refreshAttempted = true;
                final refreshed = await _authService.refreshToken();
                if (!refreshed) {
                  return ActivityUploadResult.failure(
                    attempts: attempt,
                    statusCode: response.statusCode,
                    failureType: ActivityUploadFailureType.authentication,
                    serverDetail: _extractServerDetail(response),
                  );
                }
                accessToken = await _storage.getAccessToken();
                if (accessToken == null || accessToken.isEmpty) {
                  return ActivityUploadResult.failure(
                    attempts: attempt,
                    statusCode: response.statusCode,
                    failureType: ActivityUploadFailureType.authentication,
                    serverDetail: _extractServerDetail(response),
                  );
                }
                retryWithRefreshedToken = true;
                break endpointLoop;
              }

              if (response.statusCode == 405 && method != methodCandidates.last) {
                break;
              }

              final shouldTryNextField =
                  response.statusCode == 400 ||
                  response.statusCode == 404 ||
                  response.statusCode == 415 ||
                  response.statusCode == 422;
              if (shouldTryNextField) {
                if (fileField != fileFieldCandidates.last) {
                  continue;
                }
                // After all field candidates fail for this method, continue with
                // next method/endpoint before returning a hard failure.
                exhaustedClientFailure = ActivityUploadResult.failure(
                  attempts: attempt,
                  statusCode: response.statusCode,
                  failureType: ActivityUploadFailureType.unknown,
                  serverDetail: _extractServerDetail(response),
                );
                break;
              }

              if (response.statusCode >= 500) {
                if (attempt < maxAttempts) {
                  continue attemptLoop;
                }
                return ActivityUploadResult.failure(
                  attempts: attempt,
                  statusCode: response.statusCode,
                  failureType: ActivityUploadFailureType.server,
                  serverDetail: _extractServerDetail(response),
                );
              }

              if (response.statusCode == 405 &&
                  method == methodCandidates.last) {
                final hasMoreEndpoints = endpoint != endpointCandidates.last;
                if (hasMoreEndpoints) {
                  exhaustedClientFailure = ActivityUploadResult.failure(
                    attempts: attempt,
                    statusCode: response.statusCode,
                    failureType: ActivityUploadFailureType.server,
                    serverDetail: _extractServerDetail(response),
                  );
                  break methodLoop;
                }
                return ActivityUploadResult.failure(
                  attempts: attempt,
                  statusCode: response.statusCode,
                  failureType: ActivityUploadFailureType.server,
                  serverDetail: _extractServerDetail(response),
                );
              }

              return ActivityUploadResult.failure(
                attempts: attempt,
                statusCode: response.statusCode,
                failureType: ActivityUploadFailureType.unknown,
                serverDetail: _extractServerDetail(response),
              );
            }
          }
        }
        if (retryWithRefreshedToken) {
          continue;
        }
        if (exhaustedClientFailure != null) {
          return exhaustedClientFailure;
        }
      } on ApiRequestException catch (error) {
        final isRetryable =
            error.type == ApiRequestExceptionType.network ||
            error.type == ApiRequestExceptionType.timeout;
        if (isRetryable && attempt < maxAttempts) {
          continue;
        }
        return ActivityUploadResult.failure(
          attempts: attempt,
          failureType: isRetryable
              ? ActivityUploadFailureType.network
              : ActivityUploadFailureType.unknown,
        );
      } catch (_) {
        return ActivityUploadResult.failure(
          attempts: attempt,
          failureType: ActivityUploadFailureType.unknown,
        );
      }
    }

    return ActivityUploadResult.failure(
      attempts: maxAttempts,
      failureType: ActivityUploadFailureType.server,
    );
  }

  String? _extractServerDetail(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) return null;
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        final detail =
            decoded['detail'] ?? decoded['message'] ?? decoded['error'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
        if (detail is List) {
          final normalized = detail
              .map(_normalizeValidationDetailItem)
              .whereType<String>()
              .where((item) => item.trim().isNotEmpty)
              .join(' | ');
          if (normalized.trim().isNotEmpty) {
            return normalized.trim();
          }
        }
      }
    } catch (_) {
      // Keep silent and fallback to plain text.
    }
    if (body.length <= 180) return body;
    return '${body.substring(0, 180)}...';
  }

  String? _normalizeValidationDetailItem(Object? item) {
    if (item is String) return item;
    if (item is Map<String, dynamic>) {
      final message = item['msg']?.toString().trim();
      final location = item['loc'];
      if (message != null && message.isNotEmpty) {
        if (location is List && location.isNotEmpty) {
          final field = location.last.toString();
          if (field.isNotEmpty) {
            return '$field: $message';
          }
        }
        return message;
      }
    }
    return null;
  }
}
