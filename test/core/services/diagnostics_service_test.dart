import 'dart:convert';
import 'dart:io';

import 'package:endurain/core/services/diagnostics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiagnosticsService', () {
    late Directory tempDirectory;

    setUp(() {
      tempDirectory = Directory.systemTemp.createTempSync(
        'endurain_diagnostics_test_',
      );
    });

    tearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });

    test('records sanitized breadcrumbs and errors locally', () async {
      final service = DiagnosticsService(
        supportDirectoryProvider: () async => tempDirectory,
        now: () => DateTime.utc(2026, 6),
      );

      await service.initialize();
      service.recordBreadcrumbSync(
        DiagnosticsEvents.activityStarted,
        details: {
          'url': 'https://example.test/path?token=secret-token',
          'coordinates': '41.12345, -8.67890',
        },
      );
      service.recordErrorSync(
        StateError(
          'Bearer abc123 at /Users/person/project with 41.12345, -8.67890',
        ),
        StackTrace.fromString('/private/var/containers/example/file.dart:12'),
      );

      final report = await service.readReportText();

      expect(report, isNotNull);
      expect(report, contains(DiagnosticsEvents.activityStarted));
      expect(report, contains('Bearer <redacted>'));
      expect(report, contains('<coordinates>'));
      expect(report, contains('<path>'));
      expect(report, isNot(contains('secret-token')));
      expect(report, isNot(contains('/Users/person')));
      expect(report, isNot(contains('/private/var/containers')));

      final parsedReport = await service.readReport();
      expect(parsedReport, isNotNull);
      expect(parsedReport!.breadcrumbs, hasLength(1));
      expect(parsedReport.errors, hasLength(1));
      expect(
        parsedReport.breadcrumbs.single.event,
        DiagnosticsEvents.activityStarted,
      );
      expect(parsedReport.errors.single.type, 'StateError');
    });

    test('keeps breadcrumbs bounded', () async {
      final service = DiagnosticsService(
        supportDirectoryProvider: () async => tempDirectory,
        maxBreadcrumbs: 2,
      );

      await service.initialize();
      service.recordBreadcrumbSync('one');
      service.recordBreadcrumbSync('two');
      service.recordBreadcrumbSync('three');

      final report = await service.readReportText();
      final decoded = jsonDecode(report!) as Map<String, dynamic>;
      final breadcrumbs = decoded['breadcrumbs'] as List<dynamic>;

      expect(breadcrumbs, hasLength(2));
      expect(breadcrumbs.first, containsPair('event', 'two'));
      expect(breadcrumbs.last, containsPair('event', 'three'));
    });

    test('clear removes the report', () async {
      final service = DiagnosticsService(
        supportDirectoryProvider: () async => tempDirectory,
      );

      await service.initialize();
      service.recordBreadcrumbSync('captured');
      await service.clearReport();

      expect(await service.readReportText(), isNull);
    });
  });
}
