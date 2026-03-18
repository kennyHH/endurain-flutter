import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:endurain/core/constants/api_constants.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

enum ApiRequestExceptionType { timeout, tls, network, invalidRequest, unknown }

class ApiRequestException implements Exception {
  ApiRequestException({
    required this.type,
    required this.message,
    this.method,
    this.endpoint,
    this.cause,
  });

  final ApiRequestExceptionType type;
  final String message;
  final String? method;
  final String? endpoint;
  final Object? cause;

  @override
  String toString() {
    final suffix = cause == null ? '' : ' | cause: $cause';
    return 'ApiRequestException($type): $message$suffix';
  }
}

@singleton
class ApiRequestExecutor {
  ApiRequestExecutor(
    this._httpClient, {
    this.defaultTimeout = const Duration(seconds: 15),
  });

  final http.Client _httpClient;
  final Duration defaultTimeout;

  Uri buildUri({required String serverUrl, required String endpoint}) {
    final trimmedServerUrl = serverUrl.trim();
    if (trimmedServerUrl.isEmpty) {
      throw ApiRequestException(
        type: ApiRequestExceptionType.invalidRequest,
        message: 'Server URL is empty',
        endpoint: endpoint,
      );
    }

    final baseUri = Uri.tryParse(trimmedServerUrl);
    if (baseUri == null ||
        !baseUri.hasScheme ||
        (!baseUri.isScheme('http') && !baseUri.isScheme('https'))) {
      throw ApiRequestException(
        type: ApiRequestExceptionType.invalidRequest,
        message: 'Server URL must be a valid HTTP/HTTPS URL',
        endpoint: endpoint,
      );
    }

    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '/$endpoint';
    final endpointUri = Uri.parse(normalizedEndpoint);
    final endpointPath = endpointUri.path.isEmpty ? '/' : endpointUri.path;
    return baseUri.replace(
      path: _joinPaths(baseUri.path, endpointPath),
      query: endpointUri.hasQuery ? endpointUri.query : null,
      fragment: null,
    );
  }

  Future<http.Response> request({
    required String method,
    required String serverUrl,
    required String endpoint,
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
    bool encodeBodyAsJson = false,
  }) async {
    final requestMethod = method.toUpperCase();
    final uri = buildUri(serverUrl: serverUrl, endpoint: endpoint);
    final mergedHeaders = <String, String>{
      ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
      ...?headers,
    };

    try {
      switch (requestMethod) {
        case 'GET':
          return await _httpClient
              .get(uri, headers: mergedHeaders)
              .timeout(timeout ?? defaultTimeout);
        case 'POST':
          return await _httpClient
              .post(
                uri,
                headers: mergedHeaders,
                body: _encodeBody(body, encodeBodyAsJson),
              )
              .timeout(timeout ?? defaultTimeout);
        case 'PUT':
          return await _httpClient
              .put(
                uri,
                headers: mergedHeaders,
                body: _encodeBody(body, encodeBodyAsJson),
              )
              .timeout(timeout ?? defaultTimeout);
        case 'DELETE':
          return await _httpClient
              .delete(uri, headers: mergedHeaders)
              .timeout(timeout ?? defaultTimeout);
        default:
          throw ApiRequestException(
            type: ApiRequestExceptionType.invalidRequest,
            message: 'Unsupported HTTP method: $requestMethod',
            method: requestMethod,
            endpoint: endpoint,
          );
      }
    } on TimeoutException catch (error) {
      throw ApiRequestException(
        type: ApiRequestExceptionType.timeout,
        message: 'Request timed out',
        method: requestMethod,
        endpoint: endpoint,
        cause: error,
      );
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      if (_looksLikeTlsError(error)) {
        throw ApiRequestException(
          type: ApiRequestExceptionType.tls,
          message: 'TLS handshake or certificate validation failed',
          method: requestMethod,
          endpoint: endpoint,
          cause: error,
        );
      }
      throw ApiRequestException(
        type: ApiRequestExceptionType.network,
        message: 'Network request failed',
        method: requestMethod,
        endpoint: endpoint,
        cause: error,
      );
    }
  }

  Future<http.Response> requestMultipart({
    required String method,
    required String serverUrl,
    required String endpoint,
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
    Duration? timeout,
  }) async {
    final requestMethod = method.toUpperCase();
    if (requestMethod != 'POST' &&
        requestMethod != 'PUT' &&
        requestMethod != 'PATCH') {
      throw ApiRequestException(
        type: ApiRequestExceptionType.invalidRequest,
        message: 'Unsupported multipart HTTP method: $requestMethod',
        method: requestMethod,
        endpoint: endpoint,
      );
    }

    final uri = buildUri(serverUrl: serverUrl, endpoint: endpoint);
    final request = http.MultipartRequest(requestMethod, uri);
    request.headers.addAll({
      ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
      ...?headers,
    });
    if (fields != null) {
      request.fields.addAll(fields);
    }
    if (files != null) {
      request.files.addAll(files);
    }

    try {
      final streamed = await _httpClient
          .send(request)
          .timeout(timeout ?? defaultTimeout);
      return http.Response.fromStream(streamed);
    } on TimeoutException catch (error) {
      throw ApiRequestException(
        type: ApiRequestExceptionType.timeout,
        message: 'Request timed out',
        method: requestMethod,
        endpoint: endpoint,
        cause: error,
      );
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      if (_looksLikeTlsError(error)) {
        throw ApiRequestException(
          type: ApiRequestExceptionType.tls,
          message: 'TLS handshake or certificate validation failed',
          method: requestMethod,
          endpoint: endpoint,
          cause: error,
        );
      }
      throw ApiRequestException(
        type: ApiRequestExceptionType.network,
        message: 'Network request failed',
        method: requestMethod,
        endpoint: endpoint,
        cause: error,
      );
    }
  }

  Object? _encodeBody(Object? body, bool encodeBodyAsJson) {
    if (body == null) return null;
    if (!encodeBodyAsJson) return body;
    return json.encode(body);
  }

  String _joinPaths(String basePath, String endpointPath) {
    final normalizedBase = basePath.trim();
    final normalizedEndpoint = endpointPath.startsWith('/')
        ? endpointPath
        : '/$endpointPath';

    final baseSegments = normalizedBase
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    final endpointSegments = normalizedEndpoint
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();

    var overlap = 0;
    final maxOverlap = math.min(baseSegments.length, endpointSegments.length);
    for (var length = maxOverlap; length > 0; length--) {
      final baseSuffix = baseSegments.sublist(baseSegments.length - length);
      final endpointPrefix = endpointSegments.sublist(0, length);
      if (_segmentsEqual(baseSuffix, endpointPrefix)) {
        overlap = length;
        break;
      }
    }

    final mergedSegments = <String>[
      ...baseSegments,
      ...endpointSegments.sublist(overlap),
    ];
    return '/${mergedSegments.join('/')}';
  }

  bool _segmentsEqual(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  bool _looksLikeTlsError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('certificate') ||
        raw.contains('cert_verify_failed') ||
        raw.contains('handshake') ||
        raw.contains('bad certificate') ||
        raw.contains('hostname');
  }
}
