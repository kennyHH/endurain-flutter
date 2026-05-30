import 'package:endurain/features/activity/models/activity_type.dart';
import 'package:endurain/l10n/app_localizations.dart';

extension ActivityTypeLabel on ActivityType {
  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      ActivityType.run => l10n.activityTypeRun,
      ActivityType.ride => l10n.activityTypeRide,
      ActivityType.walk => l10n.activityTypeWalk,
      ActivityType.hike => l10n.activityTypeHike,
      ActivityType.other => l10n.activityTypeOther,
    };
  }
}
