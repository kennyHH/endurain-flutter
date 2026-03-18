import 'dart:async';

import 'package:endurain/features/auth/biometric_lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'retries automatically when auth_in_progress occurs on startup',
    (tester) async {
      var authenticatedCalls = 0;
      var authAttempts = 0;

      Future<bool> authenticate() async {
        authAttempts++;
        if (authAttempts == 1) {
          throw PlatformException(
            code: 'auth_in_progress',
            message: 'Authentication in progress',
          );
        }
        return true;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: BiometricLockScreen(
            authenticate: authenticate,
            onAuthenticated: () {
              authenticatedCalls++;
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(authAttempts, equals(2));
      expect(authenticatedCalls, equals(1));
      expect(
        find.textContaining('PlatformException(auth_in_progress'),
        findsNothing,
      );
    },
  );

  testWidgets('does not start parallel biometric requests', (tester) async {
    final completer = Completer<bool>();
    var attempts = 0;

    Future<bool> authenticate() async {
      attempts++;
      return completer.future;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: BiometricLockScreen(
          authenticate: authenticate,
          onAuthenticated: () {},
        ),
      ),
    );

    await tester.pump();
    expect(attempts, equals(1));

    await tester.tap(find.text('Unlock'));
    await tester.pump();
    expect(attempts, equals(1));

    completer.complete(true);
    await tester.pump();
  });
}
