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
    Duration preemptiveRefreshWindow = const Duration(minutes: 3),
    DateTime Function()? nowProvider,
    void Function(String event, Map<String, Object?> payload)? telemetrySink,
  }) : _authService = authService,
       _storage = storage,
       _cooldown = cooldown,
       _preemptiveRefreshWindow = preemptiveRefreshWindow,
       _nowProvider = nowProvider ?? DateTime.now,
       _telemetrySink = telemetrySink;

  final AuthService _authService;
  final SecureStorageService _storage;
  final Duration _cooldown;
  final Duration _preemptiveRefreshWindow;
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
      final accessToken = await _storage.getAccessToken();
      final shouldRefresh = _shouldRefreshSoon(accessToken);
      if (!shouldRefresh) {
        _emitTelemetry('refresh_skipped_token_fresh');
        return;
      }
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

  bool _shouldRefreshSoon(String? accessToken) {
    if (accessToken == null || accessToken.isEmpty) return true;
    final exp = _extractJwtExpiry(accessToken);
    if (exp == null) {
      _emitTelemetry('refresh_token_exp_unavailable');
      return true;
    }
    final now = _nowProvider().toUtc();
    return now.add(_preemptiveRefreshWindow).isAfter(exp);
  }

  DateTime? _extractJwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payloadSegment = parts[1];
      final normalized = base64Url.normalize(payloadSegment);
      final payloadJson = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      final expRaw = payload['exp'];
      if (expRaw is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        (expRaw * 1000).round(),
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }

  void _emitTelemetry(String event) {
    final payload = <String, Object?>{
      'scope': 'resume_token_refresh',
      'event': event,
      'cooldown_seconds': _cooldown.inSeconds,
      'preemptive_window_seconds': _preemptiveRefreshWindow.inSeconds,
    };
    _telemetrySink?.call(event, payload);
    if (_enableResumeRefreshDiagnostics) {
      debugPrint('resume_refresh_diag:${jsonEncode(payload)}');
    }
  }
}
