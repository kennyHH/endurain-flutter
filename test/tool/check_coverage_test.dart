import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_coverage.dart';

void main() {
  group('CoverageSummary', () {
    test('calculates line coverage from LCOV records', () {
      final summary = CoverageSummary.fromLcov([
        'SF:lib/core/example.dart',
        'LH:8',
        'LF:10',
        'end_of_record',
        'SF:lib/features/example.dart',
        'LH:2',
        'LF:5',
        'end_of_record',
      ], excludePatterns: const []);

      expect(summary.hitLines, 10);
      expect(summary.totalLines, 15);
      expect(summary.includedFiles, 2);
      expect(summary.percent, closeTo(66.67, 0.01));
    });

    test('excludes files using glob patterns', () {
      final summary = CoverageSummary.fromLcov(
        [
          'SF:lib/l10n/app_localizations_en.dart',
          'LH:0',
          'LF:100',
          'end_of_record',
          'SF:lib/features/auth/login_screen.dart',
          'LH:75',
          'LF:100',
          'end_of_record',
        ],
        excludePatterns: const ['lib/l10n/app_localizations*.dart'],
      );

      expect(summary.hitLines, 75);
      expect(summary.totalLines, 100);
      expect(summary.includedFiles, 1);
      expect(summary.percent, 75);
    });
  });
}
