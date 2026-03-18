import 'package:endurain/core/services/activity_upload_service.dart';
import 'package:endurain/core/utils/activity_upload_feedback_mapper.dart';
import 'package:endurain/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityUploadFeedbackMapper', () {
    final l10n = AppLocalizationsEn();

    test('mappt network failure auf lokalisierte Netzwerkmeldung', () {
      final result = ActivityUploadResult.failure(
        attempts: 2,
        failureType: ActivityUploadFailureType.network,
      );

      expect(
        ActivityUploadFeedbackMapper.toUserMessage(result, l10n),
        l10n.errorNetwork,
      );
    });

    test('mappt authentication failure auf lokalisierte Auth-Meldung', () {
      final result = ActivityUploadResult.failure(
        attempts: 1,
        failureType: ActivityUploadFailureType.authentication,
      );

      expect(
        ActivityUploadFeedbackMapper.toUserMessage(result, l10n),
        l10n.errorAuthentication,
      );
    });

    test('mappt success auf positive lokale Meldung', () {
      final result = ActivityUploadResult.success(attempts: 1, statusCode: 200);

      expect(
        ActivityUploadFeedbackMapper.toUserMessage(result, l10n),
        l10n.trackingUploadSuccess,
      );
    });

    test('toDisplayMessage dupliziert Session-Detail nicht', () {
      const detail = 'Session expired. Please login again.';
      final result = ActivityUploadResult.failure(
        attempts: 1,
        failureType: ActivityUploadFailureType.authentication,
        serverDetail: detail,
      );

      expect(ActivityUploadFeedbackMapper.toDisplayMessage(result, l10n), detail);
    });

    test('toDisplayMessage ergänzt HTTP-Status und Detail ohne Dopplung', () {
      final result = ActivityUploadResult.failure(
        attempts: 1,
        statusCode: 500,
        failureType: ActivityUploadFailureType.server,
        serverDetail: 'Gateway timeout',
      );

      expect(
        ActivityUploadFeedbackMapper.toDisplayMessage(result, l10n),
        '${l10n.errorServer} (HTTP 500) - Gateway timeout',
      );
    });
  });
}
