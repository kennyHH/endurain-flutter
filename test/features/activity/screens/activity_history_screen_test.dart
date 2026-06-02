import 'dart:io';

import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/features/activity/controllers/local_activity_history_controller.dart';
import 'package:endurain/features/activity/repositories/local_activity_repository.dart';
import 'package:endurain/features/activity/screens/activity_history_screen.dart';
import 'package:endurain/features/activity/services/activity_upload_service.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:endurain/shared/adaptive/adaptive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('ActivityHistoryScreen empty state is visible on iOS dark mode', (
    tester,
  ) async {
    _useIosDarkMode(tester);
    final tempDirectory = await Directory.systemTemp.createTemp(
      'endurain_activity_history_screen_',
    );
    addTearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });

    final repository = LocalActivityRepository(
      supportDirectoryProvider: () async => tempDirectory,
    );
    final controller = LocalActivityHistoryController(
      repository: repository,
      uploadService: ActivityUploadService(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AdaptiveApp(
        title: 'Test',
        home: ActivityHistoryScreen(controller: controller),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(l10n.activityHistoryTitle), findsOneWidget);
    _expectBrightCupertinoText(tester, l10n.activityHistoryEmpty);
  });
}

void _useIosDarkMode(WidgetTester tester) {
  PlatformUtils.debugIsApplePlatformOverride = true;
  tester.binding.platformDispatcher.platformBrightnessTestValue =
      Brightness.dark;
  addTearDown(() {
    PlatformUtils.debugResetOverrides();
    tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
  });
}

void _expectBrightCupertinoText(WidgetTester tester, String text) {
  final finder = find.text(text);
  final textWidget = tester.widget<Text>(finder);
  final color = textWidget.style?.color;

  expect(color, isNotNull);
  final resolvedColor = CupertinoDynamicColor.resolve(
    color!,
    tester.element(finder),
  );
  expect(resolvedColor.computeLuminance(), greaterThan(0.5));
}
