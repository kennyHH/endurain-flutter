import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Import suites
import 'suites/activity_flow_test.dart' as activity_flow;
import 'suites/settings_test.dart' as settings;
import 'suites/navigation_test.dart' as navigation;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Endurain Comprehensive Test Suite', () {
    // We launch the app once, but we might need to reset state between tests.
    // For simplicity, we assume sequential execution where one test leaves the app in a known state
    // OR we restart the app for each suite if possible (but main() can usually only be called once per process).
    // Better approach: Design tests to navigate back to Home after completion.

    // 1. Navigation & UI Structure
    navigation.main();

    // 2. Settings & Configuration
    settings.main();

    // 3. Core Activity Flow (Start -> Record -> Stop)
    activity_flow.main();
  });
}
