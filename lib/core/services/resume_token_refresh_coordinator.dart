import 'dart:async';
import 'dart:convert';

import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:flutter/foundation.dart';

const _enableResumeRefreshDiagnostics = bool.fromEnvironment(
  'ENDURAIN_RESUME_REFRESH_DIAGNOSTICS',
  defaultValue: false,
);

class ResumeTokenRefreshCoordinator {
  ResumeTokenRefreshCoordinator({
    required AuthService authService,
    required SecureStorageService storage,
    Duration cooldown = const Duration(seconds: 90),
    DateTime Function()? nowProvider,
    void Function(String event, Map<String, Object?> payload)? telemetrySink,
  }) : _authService = authService,
       _storage = storage,
       _cooldown = cooldown,
       _nowProvider = nowProvider ?? DateTime.now,
       _telemetrySink = telemetrySink;

  final AuthService _authService;
  final SecureStorageService _storage;
  final Duration _cooldown;
  final DateTime Function() _nowProvider;
  final void Function(String event, Map<String, Object?> payload)?
  _telemetrySink;

  DateTime? _lastAttemptAt;
  Future<void>? _inflightRefresh;

  Future<void> triggerBestEffortRefresh() {
    final running = _inflightRefresh;
    if (running != null) return running;

    final now = _nowProvider();
    final lastAttemptAt = _lastAttemptAt;
    if (lastAttemptAt != null && now.difference(lastAttemptAt) < _cooldown) {
      return Future<void>.value();
    }

    _lastAttemptAt = now;
    final refresh = _refreshSilently();
    _inflightRefresh = refresh;
    return refresh;
  }

  Future<void> _refreshSilently() async {
    try {
      final isAuthenticated = await _storage.isAuthenticated();
      if (!isAuthenticated) return;
      _emitTelemetry('refresh_attempt');
      final refreshed = await _authService.refreshToken();
      if (refreshed) {
        _emitTelemetry('refresh_success');
      } else {
        _emitTelemetry('refresh_fail');
      }
    } catch (_) {
      _emitTelemetry('refresh_fail');
    } finally {
      _inflightRefresh = null;
    }
  }

  void _emitTelemetry(String event) {
    final payload = <String, Object?>{
      'scope': 'resume_token_refresh',
      'event': event,
      'cooldown_seconds': _cooldown.inSeconds,
    };
    _telemetrySink?.call(event, payload);
    if (_enableResumeRefreshDiagnostics) {
      debugPrint('resume_refresh_diag:${jsonEncode(payload)}');
    }
  }
}
