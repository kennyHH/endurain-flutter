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
import 'package:endurain/core/utils/activity_upload_policy.dart';
import 'package:injectable/injectable.dart';

enum ActivityUploadFailureType {
  configuration,
  authentication,
  invalidActivity,
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
    this.serverActivityId,
    this.serverDistanceMeters,
    this.serverDurationSeconds,
    this.serverElevationGainMeters,
    this.serverElevationLossMeters,
  });

  final bool success;
  final int attempts;
  final int? statusCode;
  final ActivityUploadFailureType? failureType;
  final String? serverDetail;
  final int? serverActivityId;
  final double? serverDistanceMeters;
  final int? serverDurationSeconds;
  final double? serverElevationGainMeters;
  final double? serverElevationLossMeters;

  factory ActivityUploadResult.success({
    required int attempts,
    int? statusCode,
    String? serverDetail,
    int? serverActivityId,
    double? serverDistanceMeters,
    int? serverDurationSeconds,
    double? serverElevationGainMeters,
    double? serverElevationLossMeters,
  }) {
    return ActivityUploadResult._(
      success: true,
      attempts: attempts,
      statusCode: statusCode,
      serverDetail: serverDetail,
      serverActivityId: serverActivityId,
      serverDistanceMeters: serverDistanceMeters,
      serverDurationSeconds: serverDurationSeconds,
      serverElevationGainMeters: serverElevationGainMeters,
      serverElevationLossMeters: serverElevationLossMeters,
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
  static const int _backendMaxActivityId = 2147483647;

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

    final candidateServerIds = <int>{};
    final storedServerId = _extractStoredServerActivityId(activity);
    if (_isBackendCompatibleActivityId(storedServerId)) {
      candidateServerIds.add(storedServerId!);
    }
    final numericLocalId = int.tryParse(activity.id.trim());
    if (_isBackendCompatibleActivityId(numericLocalId)) {
      candidateServerIds.add(numericLocalId!);
    }
    if (candidateServerIds.isEmpty) {
      return ActivityUploadResult.failure(
        attempts: 1,
        failureType: ActivityUploadFailureType.server,
        serverDetail:
            'Activity has no compatible server id for deletion. Upload again before deleting on server.',
      );
    }
    final endpointSet = <String>{};
    for (final id in candidateServerIds) {
      endpointSet.add('/api/v1/activities/$id/delete');
      endpointSet.add('/activities/$id/delete');
    }
    final endpoints = endpointSet.toList();

    ActivityUploadResult? lastFailure;
    ActivityUploadResult? firstNon405Failure;
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
        if (response.statusCode != 405 && firstNon405Failure == null) {
          firstNon405Failure = lastFailure;
        }
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

    return firstNon405Failure ??
        lastFailure ??
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

    final policy = ActivityUploadPolicy.evaluate(activity);
    if (!policy.isUploadable) {
      return ActivityUploadResult.failure(
        attempts: 0,
        failureType: ActivityUploadFailureType.invalidActivity,
        serverDetail: policy.message,
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

    await _persistUploaded(
      activity.id,
      serverActivityId: result.serverActivityId,
      serverDistanceMeters: result.serverDistanceMeters,
      serverDurationSeconds: result.serverDurationSeconds,
      serverElevationGainMeters: result.serverElevationGainMeters,
      serverElevationLossMeters: result.serverElevationLossMeters,
    );
    await _queueService.removeFromQueue(activity.id);
    return result;
  }

  Future<bool> _isAlreadyUploaded(String activityId) async {
    final repository = _activityRepository;
    if (repository == null) return false;
    final stored = await repository.getSummaryById(activityId);
    return stored?.uploaded ?? false;
  }

  Future<void> _persistUploaded(
    String activityId, {
    int? serverActivityId,
    double? serverDistanceMeters,
    int? serverDurationSeconds,
    double? serverElevationGainMeters,
    double? serverElevationLossMeters,
  }) async {
    final repository = _activityRepository;
    if (repository == null) return;
    final stored = await repository.getById(activityId);
    if (stored == null || stored.uploaded) return;
    final nextQualityMetrics = <String, dynamic>{...?stored.qualityMetrics};
    if (serverActivityId != null) {
      nextQualityMetrics['server_activity_id'] = serverActivityId;
    }
    if (serverElevationGainMeters != null) {
      nextQualityMetrics['filtered_elevation_gain_meters'] =
          serverElevationGainMeters;
    }
    if (serverElevationLossMeters != null) {
      nextQualityMetrics['filtered_elevation_loss_meters'] =
          serverElevationLossMeters;
    }
    final nextDistanceMeters = serverDistanceMeters ?? stored.distanceMeters;
    final nextEndedAt = serverDurationSeconds == null
        ? stored.endedAt
        : stored.startedAt.add(Duration(seconds: serverDurationSeconds));
    await repository.update(
      stored.copyWith(
        uploaded: true,
        distanceMeters: nextDistanceMeters,
        endedAt: nextEndedAt,
        qualityMetrics: nextQualityMetrics,
      ),
    );
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
                  final serverMetrics = _extractServerMetrics(response);
                  return ActivityUploadResult.success(
                    attempts: attempt,
                    statusCode: response.statusCode,
                    serverDetail: _extractServerDetail(response),
                    serverActivityId: _extractServerActivityId(response),
                    serverDistanceMeters: serverMetrics.distanceMeters,
                    serverDurationSeconds: serverMetrics.durationSeconds,
                    serverElevationGainMeters:
                        serverMetrics.elevationGainMeters,
                    serverElevationLossMeters:
                        serverMetrics.elevationLossMeters,
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

  int? _extractServerActivityId(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) return null;
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        final directId = _coerceToInt(decoded['id'] ?? decoded['activity_id']);
        if (_isBackendCompatibleActivityId(directId)) {
          return directId;
        }
        final detail =
            decoded['detail'] ?? decoded['message'] ?? decoded['error'];
        final idFromDetail = _extractIdFromMessage(detail?.toString());
        if (_isBackendCompatibleActivityId(idFromDetail)) {
          return idFromDetail;
        }
      }
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map<String, dynamic>) {
          final directId = _coerceToInt(first['id'] ?? first['activity_id']);
          if (_isBackendCompatibleActivityId(directId)) {
            return directId;
          }
          final detail = first['detail'] ?? first['message'] ?? first['error'];
          final idFromDetail = _extractIdFromMessage(detail?.toString());
          if (_isBackendCompatibleActivityId(idFromDetail)) {
            return idFromDetail;
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  _ServerActivityMetrics _extractServerMetrics(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) return const _ServerActivityMetrics();
    try {
      final decoded = json.decode(body);
      final map = _firstMap(decoded);
      if (map == null) return const _ServerActivityMetrics();
      final distanceMeters = _coerceToDouble(map['distance']);
      final durationSeconds = _coerceToInt(
        map['total_timer_time'] ?? map['total_elapsed_time'],
      );
      final elevationGainMeters = _coerceToDouble(map['elevation_gain']);
      final elevationLossMeters = _coerceToDouble(map['elevation_loss']);
      return _ServerActivityMetrics(
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        elevationGainMeters: elevationGainMeters,
        elevationLossMeters: elevationLossMeters,
      );
    } catch (_) {
      return const _ServerActivityMetrics();
    }
  }

  Map<String, dynamic>? _firstMap(Object? decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List && decoded.isNotEmpty) {
      final first = decoded.first;
      if (first is Map<String, dynamic>) return first;
    }
    return null;
  }

  int? _extractStoredServerActivityId(Activity activity) {
    final metrics = activity.qualityMetrics;
    if (metrics == null) return null;
    return _coerceToInt(metrics['server_activity_id']);
  }

  int? _coerceToInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  double? _coerceToDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  int? _extractIdFromMessage(String? message) {
    if (message == null || message.trim().isEmpty) return null;
    final match = RegExp(r'\b\d+\b').firstMatch(message);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  bool _isBackendCompatibleActivityId(int? value) {
    if (value == null) return false;
    return value >= 0 && value <= _backendMaxActivityId;
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

class _ServerActivityMetrics {
  const _ServerActivityMetrics({
    this.distanceMeters,
    this.durationSeconds,
    this.elevationGainMeters,
    this.elevationLossMeters,
  });

  final double? distanceMeters;
  final int? durationSeconds;
  final double? elevationGainMeters;
  final double? elevationLossMeters;
}
