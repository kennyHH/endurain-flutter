import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Localized text shown in the persistent notification that keeps location
/// tracking alive while the app is backgrounded.
///
/// The strings are supplied by the UI layer so they stay localized; core
/// services never reach into the widget tree for translations.
class BackgroundLocationConfig {
  const BackgroundLocationConfig({
    required this.notificationTitle,
    required this.notificationText,
  });

  final String notificationTitle;
  final String notificationText;
}

/// Builds [LocationSettings] tuned for either foreground-only updates or
/// continuous background tracking.
///
/// When [background] is provided, platform-specific settings are returned so
/// updates keep flowing while the app is backgrounded:
/// - Android starts a foreground service with a persistent notification and
///   forces the FOSS `LocationManager` (no Google Play Services), keeping the
///   build F-Droid compatible.
/// - Apple platforms enable background location updates.
LocationSettings buildLocationSettings({
  BackgroundLocationConfig? background,
  LocationAccuracy accuracy = LocationAccuracy.high,
  int distanceFilter = 10,
  TargetPlatform? platform,
}) {
  if (background == null) {
    return LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
  }

  final targetPlatform = platform ?? defaultTargetPlatform;
  switch (targetPlatform) {
    case TargetPlatform.android:
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        forceLocationManager: true,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: background.notificationTitle,
          notificationText: background.notificationText,
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
        activityType: ActivityType.fitness,
      );
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );
  }
}
