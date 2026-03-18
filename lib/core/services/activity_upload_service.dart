import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/gpx_exporter.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/core/services/api_request_executor.dart';
import 'package:endurain/core/services/activity_repository.dart';
import 'package:endurain/core/error_handling/app_error.dart';
import 'package:endurain/core/constants/upload_constants.dart';
import 'package:endurain/core/services/upload_queue/upload_queue_service.dart';
import 'package:endurain/core/di/service_locator.dart';
import 'package:injectable/injectable.dart';

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

@singleton
class ActivityUploadService {
  ActivityUploadService({
    required ApiClient apiClient,
    required SecureStorageService storage,
    required AuthService authService,
    required GpxExporter gpxExporter,
    required UploadQueueService queueService,
    ActivityRepository? activityRepository,
  }) : _apiClient = apiClient,
       _storage = storage,
       _authService = authService,
       _gpxExporter = gpxExporter,
       _queueService = queueService,
       _activityRepository = _resolveActivityRepository(activityRepository);

  final ApiClient _apiClient;
  final SecureStorageService _storage;
  final AuthService _authService;
  final GpxExporter _gpxExporter;
  final UploadQueueService _queueService;
  final ActivityRepository? _activityRepository;
  final Map<String, Future<ActivityUploadResult>> _inFlightUploads =
      <String, Future<ActivityUploadResult>>{};

  static ActivityRepository? _resolveActivityRepository(
    ActivityRepository? injected,
  ) {
    if (injected != null) return injected;
    if (!serviceLocator.isRegistered<ActivityRepository>()) return null;
    try {
      return serviceLocator<ActivityRepository>();
    } catch (_) {
      return null;
    }
  }

  Future<ActivityUploadResult> deleteActivity(Activity activity) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      return ActivityUploadResult.failure(
        attempts: 0,
        failureType: ActivityUploadFailureType.configuration,
      );
    }

    final encodedId = Uri.encodeComponent(activity.id);
    final endpoints = <String>[
      '/api/v1/activities/$encodedId/delete',
      '/api/v1/activities/$encodedId',
      '/api/v1/activities/delete/$encodedId',
      '/activities/$encodedId/delete',
      '/activities/$encodedId',
    ];

    ActivityUploadResult? lastFailure;
    for (final endpoint in endpoints) {
      try {
        final response = await _apiClient.delete(endpoint);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ActivityUploadResult.success(
            attempts: 1,
            statusCode: response.statusCode,
            serverDetail: _extractServerDetail(response),
          );
        }
        lastFailure = ActivityUploadResult.failure(
          attempts: 1,
          statusCode: response.statusCode,
          failureType: response.statusCode == 401
              ? ActivityUploadFailureType.authentication
              : ActivityUploadFailureType.server,
          serverDetail: _extractServerDetail(response),
        );
      } on AuthenticationError catch (error) {
        final isAuthenticated = await _authService.isAuthenticated();
        return ActivityUploadResult.failure(
          attempts: 1,
          failureType: ActivityUploadFailureType.authentication,
          serverDetail: isAuthenticated
              ? error.message
              : 'Session expired. Please login again.',
        );
      } on NetworkError catch (error) {
        return ActivityUploadResult.failure(
          attempts: 1,
          failureType: ActivityUploadFailureType.network,
          serverDetail: error.message,
        );
      } catch (_) {
        // Try next endpoint fallback.
      }
    }

    return lastFailure ??
        ActivityUploadResult.failure(
          attempts: 1,
          failureType: ActivityUploadFailureType.server,
        );
  }

  Future<ActivityUploadResult> uploadActivity(Activity activity) async {
    final existing = _inFlightUploads[activity.id];
    if (existing != null) return existing;

    final uploadFuture = _uploadActivityInternal(activity).whenComplete(() {
      _inFlightUploads.remove(activity.id);
    });
    _inFlightUploads[activity.id] = uploadFuture;
    return uploadFuture;
  }

  Future<ActivityUploadResult> _uploadActivityInternal(
    Activity activity,
  ) async {
    final alreadyUploaded = await _isAlreadyUploaded(activity.id);
    if (alreadyUploaded) {
      await _queueService.removeFromQueue(activity.id);
      return ActivityUploadResult.success(
        attempts: 0,
        serverDetail: 'already_uploaded',
      );
    }

    final result = await _performUpload(activity);

    if (!result.success) {
      final type = result.failureType;
      if (type == ActivityUploadFailureType.network ||
          type == ActivityUploadFailureType.server) {
        await _queueService.addToQueue(activity);
      }
      return result;
    }

    await _persistUploaded(activity.id);
    await _queueService.removeFromQueue(activity.id);
    return result;
  }

  Future<bool> _isAlreadyUploaded(String activityId) async {
    final repository = _activityRepository;
    if (repository == null) return false;
    final stored = await repository.getSummaryById(activityId);
    return stored?.uploaded ?? false;
  }

  Future<void> _persistUploaded(String activityId) async {
    final repository = _activityRepository;
    if (repository == null) return;
    final stored = await repository.getById(activityId);
    if (stored == null || stored.uploaded) return;
    await repository.update(stored.copyWith(uploaded: true));
  }

  /// Process the offline queue
  Future<void> processQueue() async {
    final queue = await _queueService.getQueue();
    if (queue.isEmpty) return;

    for (final activity in queue) {
      final result = await uploadActivity(activity);
      if (!result.success &&
          (result.failureType == ActivityUploadFailureType.authentication ||
              result.failureType == ActivityUploadFailureType.configuration)) {
        break;
      }
    }
  }

  Future<ActivityUploadResult> _performUpload(Activity activity) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      return ActivityUploadResult.failure(
        attempts: 0,
        failureType: ActivityUploadFailureType.configuration,
      );
    }

    final gpx = _gpxExporter.export(activity);
    final gpxFilename = _gpxExporter.buildExportFilename(activity);
    final uploadHeaders = <String, String>{
      UploadConstants.idempotencyHeader: 'endurain-upload-${activity.id}',
      UploadConstants.uploadActivityIdHeader: activity.id,
    };
    const maxAttempts = UploadConstants.defaultUploadRetries + 1;
    final methodCandidates = <String>['POST', 'PUT', 'PATCH'];
    final fileFieldCandidates = <String>[
      UploadConstants.multipartFileField,
      ...UploadConstants.multipartFileFieldFallbacks,
    ];
    final visibilityFieldProfiles = <Map<String, String>>[
      <String, String>{
        'hidden': 'false',
        'is_hidden': 'false',
        'visibility': 'public',
        'is_public': 'true',
      },
      <String, String>{'hidden': 'false'},
      <String, String>{'is_hidden': 'false'},
      <String, String>{'visibility': 'public'},
      <String, String>{'is_public': 'true'},
    ];
    // Add variations to handle potential server path requirements (e.g. trailing slash)
    final endpointCandidates = {
      UploadConstants.activityUploadEndpoint,
      '${UploadConstants.activityUploadEndpoint}/',
      '/api/v1/activities/upload',
      '/api/v1/activities/import',
      '/api/v1/activities',
      '/activities/create/upload',
      '/activities/upload',
      '/activities/import',
      '/activities',
    }.toList();

    ActivityUploadResult? last405Result;

    attemptLoop:
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        ActivityUploadResult? exhaustedClientFailure;
        endpointLoop:
        for (final endpoint in endpointCandidates) {
          methodLoop:
          for (final method in methodCandidates) {
            for (final fields in visibilityFieldProfiles) {
              for (final fileField in fileFieldCandidates) {
                final response = await _apiClient.requestMultipart(
                  method: method,
                  endpoint: endpoint,
                  headers: uploadHeaders,
                  fields: fields,
                  files: [
                    UploadableFile.fromString(
                      field: fileField,
                      content: gpx,
                      filename: gpxFilename,
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
                  return ActivityUploadResult.failure(
                    attempts: attempt,
                    statusCode: response.statusCode,
                    failureType: ActivityUploadFailureType.authentication,
                    serverDetail: _extractServerDetail(response),
                  );
                }

                if (response.statusCode == 405 &&
                    method != methodCandidates.last) {
                  continue methodLoop;
                }

                final shouldTryNextVariant =
                    response.statusCode == 400 ||
                    response.statusCode == 404 ||
                    response.statusCode == 415 ||
                    response.statusCode == 422;
                if (shouldTryNextVariant) {
                  if (fileField != fileFieldCandidates.last) {
                    continue;
                  }
                  if (!identical(fields, visibilityFieldProfiles.last)) {
                    continue;
                  }
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
                  last405Result = ActivityUploadResult.failure(
                    attempts: attempt,
                    statusCode: response.statusCode,
                    failureType: ActivityUploadFailureType.server,
                    serverDetail:
                        'Method Not Allowed (405) for endpoint: $endpoint',
                  );
                  final hasMoreEndpoints = endpoint != endpointCandidates.last;
                  if (hasMoreEndpoints) {
                    continue endpointLoop;
                  }
                  return last405Result;
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
          serverDetail: error.message,
        );
      } on AuthenticationError catch (error) {
        final isAuthenticated = await _authService.isAuthenticated();
        final detail = isAuthenticated
            ? error.message
            : 'Session expired. Please login again.';
        return ActivityUploadResult.failure(
          attempts: attempt,
          failureType: ActivityUploadFailureType.authentication,
          serverDetail: detail,
        );
      } on NetworkError catch (error) {
        if (attempt < maxAttempts) {
          continue;
        }
        return ActivityUploadResult.failure(
          attempts: attempt,
          failureType: ActivityUploadFailureType.network,
          serverDetail: error.message,
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
