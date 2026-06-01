import 'package:endurain/core/services/diagnostics_service.dart';
import 'package:endurain/features/settings/diagnostics_screen.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:endurain/shared/adaptive/adaptive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('DiagnosticsScreen shows empty state', (tester) async {
    await tester.pumpWidget(
      AdaptiveApp(
        title: 'Test',
        home: DiagnosticsScreen(diagnostics: _FakeDiagnosticsStore()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(l10n.diagnosticsTitle), findsOneWidget);
    expect(find.text(l10n.diagnosticsEmpty), findsOneWidget);
  });

  testWidgets('DiagnosticsScreen shows captured report actions', (
    tester,
  ) async {
    final report = DiagnosticsReport.fromPayload({
      'schemaVersion': 1,
      'app': 'Endurain',
      'lastUpdatedAt': '2026-06-01T12:30:00Z',
      'breadcrumbs': [
        {
          'at': '2026-06-01T12:29:00Z',
          'event': DiagnosticsEvents.activityStarted,
          'details': {'activityType': 'walk', 'pointCount': 2},
        },
      ],
      'errors': [
        {
          'at': '2026-06-01T12:30:00Z',
          'source': DiagnosticsSources.flutter,
          'type': 'StateError',
          'message': 'Something failed',
          'stack': 'stack',
        },
      ],
    });

    await tester.pumpWidget(
      AdaptiveApp(
        title: 'Test',
        home: DiagnosticsScreen(
          diagnostics: _FakeDiagnosticsStore(report: report),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(l10n.diagnosticsSummary), findsOneWidget);
    expect(find.text(l10n.diagnosticsEventsCount(1)), findsOneWidget);
    expect(find.text(l10n.diagnosticsErrorsCount(1)), findsOneWidget);
    expect(
      find.text(l10n.diagnosticsEventTitle(DiagnosticsEvents.activityStarted)),
      findsOneWidget,
    );
    expect(find.text(l10n.diagnosticsErrorTitle('StateError')), findsOneWidget);
    expect(find.text(l10n.diagnosticsCopy), findsOneWidget);
    expect(find.text(l10n.diagnosticsClear), findsOneWidget);
    expect(find.textContaining('"breadcrumbs"'), findsOneWidget);
  });
}

class _FakeDiagnosticsStore implements DiagnosticsStore {
  _FakeDiagnosticsStore({this.report});

  final DiagnosticsReport? report;

  @override
  Future<void> clearReport() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<DiagnosticsReport?> readReport() async => report;

  @override
  Future<String?> readReportText() async => report?.rawText;

  @override
  void recordBreadcrumbSync(
    String event, {
    Map<String, Object?> details = const {},
  }) {}

  @override
  void recordErrorSync(
    Object error,
    StackTrace stackTrace, {
    String source = DiagnosticsSources.uncaught,
  }) {}

  @override
  void recordFlutterErrorSync(FlutterErrorDetails details) {}
}
