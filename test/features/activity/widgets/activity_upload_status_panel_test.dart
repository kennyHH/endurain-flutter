import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/features/activity/models/activity_upload_state.dart';
import 'package:endurain/features/activity/widgets/activity_upload_status_panel.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityUploadStatusPanel', () {
    testWidgets('shows uploading state without retry', (tester) async {
      await tester.pumpWidget(
        const _TestApp(
          child: ActivityUploadStatusPanel(
            status: ActivityUploadStatus.uploading,
            error: null,
            onRetry: null,
            onDiscard: null,
          ),
        ),
      );

      expect(find.text(AppLocalizationsEn().activityUploading), findsOneWidget);
      expect(find.text(AppLocalizationsEn().activityRetryUpload), findsNothing);
    });

    testWidgets('shows uploaded state with discard action', (tester) async {
      var discarded = false;

      await tester.pumpWidget(
        _TestApp(
          child: ActivityUploadStatusPanel(
            status: ActivityUploadStatus.uploaded,
            error: null,
            onRetry: null,
            onDiscard: () => discarded = true,
          ),
        ),
      );

      expect(find.text(AppLocalizationsEn().activityUploaded), findsOneWidget);
      await tester.tap(find.text(AppLocalizationsEn().activityDiscard));

      expect(discarded, isTrue);
    });

    testWidgets('shows failed state with retry and discard actions', (
      tester,
    ) async {
      var retried = false;
      var discarded = false;

      await tester.pumpWidget(
        _TestApp(
          child: ActivityUploadStatusPanel(
            status: ActivityUploadStatus.failed,
            error: const AppException(AppErrorCode.activityUploadNotConfigured),
            onRetry: () => retried = true,
            onDiscard: () => discarded = true,
          ),
        ),
      );

      expect(
        find.text(AppLocalizationsEn().activityUploadFailed),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().errorActivityUploadNotConfigured),
        findsOneWidget,
      );

      await tester.tap(find.text(AppLocalizationsEn().activityRetryUpload));
      await tester.tap(find.text(AppLocalizationsEn().activityDiscard));

      expect(retried, isTrue);
      expect(discarded, isTrue);
    });

    testWidgets('shows cleanup failure without retry action', (tester) async {
      var discarded = false;

      await tester.pumpWidget(
        _TestApp(
          child: ActivityUploadStatusPanel(
            status: ActivityUploadStatus.cleanupFailed,
            error: const AppException(AppErrorCode.activityGpxCleanupFailed),
            onRetry: () {},
            onDiscard: () => discarded = true,
          ),
        ),
      );

      expect(
        find.text(AppLocalizationsEn().activityUploadCleanupFailed),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().errorActivityGpxCleanupFailed),
        findsOneWidget,
      );
      expect(find.text(AppLocalizationsEn().activityRetryUpload), findsNothing);

      await tester.tap(find.text(AppLocalizationsEn().activityDiscard));

      expect(discarded, isTrue);
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }
}
