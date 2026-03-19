import 'package:endurain/core/services/activity_upload_service.dart';
import 'package:endurain/l10n/app_localizations.dart';

class ActivityUploadFeedbackMapper {
  static String toUserMessage(
    ActivityUploadResult result,
    AppLocalizations l10n,
  ) {
    if (result.success) {
      return l10n.trackingUploadSuccess;
    }

    switch (result.failureType) {
      case ActivityUploadFailureType.authentication:
        final detail = result.serverDetail?.toLowerCase() ?? '';
        if (detail.contains('session expired') ||
            detail.contains('please login again')) {
          return result.serverDetail!;
        }
        return l10n.errorAuthentication;
      case ActivityUploadFailureType.configuration:
        return l10n.errorConfiguration;
      case ActivityUploadFailureType.invalidActivity:
        return result.serverDetail?.trim().isNotEmpty == true
            ? result.serverDetail!
            : 'Activity is not uploadable.';
      case ActivityUploadFailureType.network:
        return l10n.errorNetwork;
      case ActivityUploadFailureType.server:
        return l10n.errorServer;
      case ActivityUploadFailureType.unknown:
      case null:
        return l10n.errorGeneric;
    }
  }

  static String toDisplayMessage(
    ActivityUploadResult result,
    AppLocalizations l10n,
  ) {
    final base = toUserMessage(result, l10n);
    if (result.success) return base;

    final status = result.statusCode;
    final detail = result.serverDetail?.trim();
    final withStatus = status != null ? '$base (HTTP $status)' : base;
    if (detail == null || detail.isEmpty) return withStatus;

    final baseNormalized = base.trim().toLowerCase();
    final detailNormalized = detail.toLowerCase();
    if (baseNormalized == detailNormalized ||
        baseNormalized.contains(detailNormalized) ||
        detailNormalized.contains(baseNormalized)) {
      return withStatus;
    }
    return '$withStatus - $detail';
  }
}
