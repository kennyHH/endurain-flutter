import 'package:endurain/core/di/injection.dart';
import 'package:endurain/core/services/tracking_session_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Dependency injection registration', () {
    setUp(() async {
      await getIt.reset();
      await configureDependencies();
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('registriert Tracking-Abhängigkeiten für App-Startup', () {
      expect(getIt.isRegistered<PositionStreamProvider>(), isTrue);
      expect(getIt.isRegistered<bool>(instanceName: 'phaseADiagnostics'), isTrue);
      expect(
        getIt.isRegistered<bool>(instanceName: 'phaseBDistanceConsistency'),
        isTrue,
      );
      expect(getIt.isRegistered<TrackingSessionEngine>(), isTrue);
    });
  });
}
