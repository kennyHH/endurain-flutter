import 'dart:io';

import 'package:endurain/core/utils/startup_error_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowEmergencyStartupError', () {
    test('liefert true waehrend bootstrap-phase', () {
      final result = shouldShowEmergencyStartupError(
        error: Exception('bootstrap failed'),
        appBootstrapped: false,
      );

      expect(result, isTrue);
    });

    test('liefert false nach erfolgreichem bootstrap bei socketfehlern', () {
      final result = shouldShowEmergencyStartupError(
        error: const SocketException('Connection attempt canceled'),
        appBootstrapped: true,
      );

      expect(result, isFalse);
    });
  });
}
