import 'package:endurain/core/services/package_info_service.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/features/settings/settings_screen.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:endurain/shared/adaptive/adaptive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  final l10n = AppLocalizationsEn();

  setUp(() {
    PlatformUtils.debugIsApplePlatformOverride = false;
  });

  tearDown(PlatformUtils.debugResetOverrides);

  testWidgets('SettingsScreen shows navigation and package version', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveApp(
        title: 'Test',
        home: SettingsScreen(
          packageInfoService: _FakePackageInfoService(version: '1.2.3'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsScreen), findsOneWidget);
    expect(find.text(l10n.serverSettings), findsOneWidget);
    expect(find.text(l10n.diagnostics), findsOneWidget);
    expect(find.textContaining('Endurain • 1.2.3'), findsOneWidget);
  });
}

class _FakePackageInfoService extends PackageInfoService {
  const _FakePackageInfoService({required this.version});

  final String version;

  @override
  Future<PackageInfo> fromPlatform() async {
    return PackageInfo(
      appName: 'Endurain',
      packageName: 'com.endurain.mobile',
      version: version,
      buildNumber: '1',
    );
  }
}
