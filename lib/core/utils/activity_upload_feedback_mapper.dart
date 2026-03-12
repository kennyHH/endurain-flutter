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
        return l10n.errorAuthentication;
      case ActivityUploadFailureType.configuration:
        return l10n.errorConfiguration;
      case ActivityUploadFailureType.network:
        return l10n.errorNetwork;
      case ActivityUploadFailureType.server:
        return l10n.errorServer;
      case ActivityUploadFailureType.unknown:
      case null:
        return l10n.errorGeneric;
    }
  }
}
