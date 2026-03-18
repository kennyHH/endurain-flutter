import 'dart:async';

import 'package:endurain/core/services/resume_token_refresh_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../widget_test.mocks.dart';

void main() {
  group('ResumeTokenRefreshCoordinator', () {
    test('refreshes once when authenticated', () async {
      final auth = MockAuthService();
      final storage = MockSecureStorageService();
      final events = <String>[];
      when(storage.isAuthenticated()).thenAnswer((_) async => true);
      when(auth.refreshToken()).thenAnswer((_) async => true);

      final coordinator = ResumeTokenRefreshCoordinator(
        authService: auth,
        storage: storage,
        telemetrySink: (event, _) => events.add(event),
      );

      await coordinator.triggerBestEffortRefresh();

      verify(storage.isAuthenticated()).called(1);
      verify(auth.refreshToken()).called(1);
      expect(events, <String>['refresh_attempt', 'refresh_success']);
    });

    test('skips refresh when user is not authenticated', () async {
      final auth = MockAuthService();
      final storage = MockSecureStorageService();
      final events = <String>[];
      when(storage.isAuthenticated()).thenAnswer((_) async => false);

      final coordinator = ResumeTokenRefreshCoordinator(
        authService: auth,
        storage: storage,
        telemetrySink: (event, _) => events.add(event),
      );

      await coordinator.triggerBestEffortRefresh();

      verify(storage.isAuthenticated()).called(1);
      verifyNever(auth.refreshToken());
      expect(events, isEmpty);
    });

    test('applies cooldown between refresh attempts', () async {
      final auth = MockAuthService();
      final storage = MockSecureStorageService();
      final events = <String>[];
      when(storage.isAuthenticated()).thenAnswer((_) async => true);
      when(auth.refreshToken()).thenAnswer((_) async => true);
      var now = DateTime(2026, 1, 1, 12, 0, 0);

      final coordinator = ResumeTokenRefreshCoordinator(
        authService: auth,
        storage: storage,
        cooldown: const Duration(seconds: 90),
        nowProvider: () => now,
        telemetrySink: (event, _) => events.add(event),
      );

      await coordinator.triggerBestEffortRefresh();
      now = now.add(const Duration(seconds: 30));
      await coordinator.triggerBestEffortRefresh();
      now = now.add(const Duration(seconds: 100));
      await coordinator.triggerBestEffortRefresh();

      verify(auth.refreshToken()).called(2);
      expect(
        events,
        <String>[
          'refresh_attempt',
          'refresh_success',
          'refresh_attempt',
          'refresh_success',
        ],
      );
    });

    test('reuses inflight refresh when resumed rapidly', () async {
      final auth = MockAuthService();
      final storage = MockSecureStorageService();
      final events = <String>[];
      final refreshCompleter = Completer<bool>();
      when(storage.isAuthenticated()).thenAnswer((_) async => true);
      when(auth.refreshToken()).thenAnswer((_) => refreshCompleter.future);

      final coordinator = ResumeTokenRefreshCoordinator(
        authService: auth,
        storage: storage,
        telemetrySink: (event, _) => events.add(event),
      );

      final first = coordinator.triggerBestEffortRefresh();
      final second = coordinator.triggerBestEffortRefresh();
      await Future<void>.delayed(Duration.zero);
      expect(identical(first, second), isTrue);
      verify(auth.refreshToken()).called(1);

      refreshCompleter.complete(true);
      await Future.wait([first, second]);
      expect(events, <String>['refresh_attempt', 'refresh_success']);
    });

    test('emits fail telemetry when refresh returns false', () async {
      final auth = MockAuthService();
      final storage = MockSecureStorageService();
      final events = <String>[];
      when(storage.isAuthenticated()).thenAnswer((_) async => true);
      when(auth.refreshToken()).thenAnswer((_) async => false);

      final coordinator = ResumeTokenRefreshCoordinator(
        authService: auth,
        storage: storage,
        telemetrySink: (event, _) => events.add(event),
      );

      await coordinator.triggerBestEffortRefresh();

      expect(events, <String>['refresh_attempt', 'refresh_fail']);
    });
  });
}
