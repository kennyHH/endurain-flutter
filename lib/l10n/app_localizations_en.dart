// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get error => 'Error';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get back => 'Back';

  @override
  String get requiredField => 'This field is required';

  @override
  String get invalidUrl => 'Please enter a valid URL';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork =>
      'Network error. Please check your connection and try again.';

  @override
  String get errorTls =>
      'Secure connection failed (TLS/SSL). Please verify certificate chain, hostname, and trusted CA.';

  @override
  String get errorAuthentication =>
      'Authentication failed. Please check your credentials.';

  @override
  String get errorServer => 'Server error. Please try again later.';

  @override
  String get errorConfiguration =>
      'Server configuration is invalid. Please verify your settings.';

  @override
  String get errorSso => 'Single sign-on failed. Please try again.';

  @override
  String get httpsRequiredUrl => 'Please use an HTTPS URL';

  @override
  String get loginTitle => 'Login';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirmTitle => 'Logout';

  @override
  String get logoutConfirmMessage => 'Are you sure you want to logout?';

  @override
  String get logoutServerFailedWarning =>
      'Could not logout from server, but logged out locally';

  @override
  String get retry => 'Retry';

  @override
  String get ssoWebViewTitle => 'Sign In';

  @override
  String get ssoCancel => 'Cancel';

  @override
  String get ssoAuthenticationFailed =>
      'SSO authentication failed. Please try again.';

  @override
  String get ssoAuthenticationCancelled => 'SSO authentication was cancelled.';

  @override
  String get ssoBlockedNavigation =>
      'Navigation was blocked for security reasons.';

  @override
  String ssoSignInWith(String provider) {
    return 'Sign in with $provider';
  }

  @override
  String get ssoOrDivider => 'OR';

  @override
  String get next => 'Next';

  @override
  String get username => 'Username';

  @override
  String get usernameHint => 'Enter your username';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get showPassword => 'Show password';

  @override
  String get mfaTitle => 'Two-Factor Authentication';

  @override
  String get mfaCode => 'MFA code';

  @override
  String get mfaCodeHint => 'Enter 6-digit code';

  @override
  String get mfaCodeRequired => 'Please enter MFA code';

  @override
  String get helpTitle => 'Info';

  @override
  String get loginServerUrlHelp =>
      'Enter the exact base URL of your Endurain server, including https:// and matching the certificate hostname. Example: https://train.example.com';

  @override
  String get loginNextHelp =>
      'Next checks server settings and available login providers. If this step fails with TLS, verify full certificate chain, hostname/SAN, and Android trust.';

  @override
  String get loginTlsToggleHelp =>
      'Test-only mode. If enabled, certificate validation is bypassed for diagnostics. If login only works with this mode, your server TLS trust chain or hostname setup must be fixed.';

  @override
  String get verify => 'Verify';

  @override
  String get mapTab => 'Map';

  @override
  String get historyTab => 'History';

  @override
  String get historyTitle => 'Activity history';

  @override
  String get historyDetailTitle => 'Activity details';

  @override
  String get historyEmptyTitle => 'No activities yet';

  @override
  String get historyEmptyBody =>
      'Start and stop a tracking session to see your activities here.';

  @override
  String get historyEmptyCtaStart => 'Start first activity';

  @override
  String get historyLoadError => 'Could not load activities. Please try again.';

  @override
  String get historyTrackPoints => 'Track points';

  @override
  String get historyTapMapForOverview =>
      'Tap the map to open full route overview';

  @override
  String get historyGroupToday => 'Today';

  @override
  String get historyGroupYesterday => 'Yesterday';

  @override
  String get historyGroupThisWeek => 'This week';

  @override
  String get historyGroupOlder => 'Older';

  @override
  String get historyFilterAll => 'All';

  @override
  String get historyRange7d => '7d';

  @override
  String get historyRange30d => '30d';

  @override
  String get historyRange90d => '90d';

  @override
  String get historyRange1y => '1y';

  @override
  String get historyRangeAllTime => 'All time';

  @override
  String get historyFilterSort => 'Filter & sort';

  @override
  String get historyDateRange => 'Date range';

  @override
  String get historySortBy => 'Sort by';

  @override
  String get historySortNewest => 'Newest';

  @override
  String get historySortOldest => 'Oldest';

  @override
  String get historySortLongest => 'Longest';

  @override
  String get historySortShortest => 'Shortest';

  @override
  String get historyOnlyUnuploaded => 'Only unuploaded activities';

  @override
  String get historyUploadPending => 'Upload pending';

  @override
  String get historyRenameTitle => 'Name activity';

  @override
  String get historyRenameHint => 'e.g. Evening ride';

  @override
  String get historyDeleteAction => 'Delete';

  @override
  String get historyDeleteTitle => 'Delete activity?';

  @override
  String get historyDeleteMessage =>
      'This removes the activity from the app and (if uploaded) from the server.';

  @override
  String get historyDeletedSuccess => 'Activity deleted';

  @override
  String get mapCenterOnLocation => 'Center on my location';

  @override
  String get activityTypeLabel => 'Activity type';

  @override
  String get activityTypeRun => 'Run';

  @override
  String get activityTypeRide => 'Ride';

  @override
  String get activityTypeWalk => 'Walk';

  @override
  String get trackingIdle => 'Idle';

  @override
  String get trackingRecording => 'Recording';

  @override
  String get trackingPaused => 'Paused';

  @override
  String get trackingStopped => 'Stopped';

  @override
  String get trackingStart => 'Start tracking';

  @override
  String get trackingStop => 'Stop tracking';

  @override
  String get trackingDuration => 'Duration';

  @override
  String get trackingDistance => 'Distance';

  @override
  String get trackingDistanceUnitKm => 'km';

  @override
  String get trackingPace => 'Pace';

  @override
  String get trackingPaceUnitMinKm => 'min/km';

  @override
  String get trackingAverageSpeed => 'Avg speed';

  @override
  String get trackingSpeedUnitKmh => 'km/h';

  @override
  String get trackingElevationGain => 'Elevation gain';

  @override
  String get trackingElevationUnitM => 'm';

  @override
  String get historyElevationLoss => 'Elevation loss';

  @override
  String get historyElevationProfile => 'Elevation profile';

  @override
  String get historyNoAltitudeData => 'No altitude data available';

  @override
  String get trackingPermissionRequired =>
      'Location permission is required to start tracking.';

  @override
  String get trackingGpsSignalLost =>
      'No GPS signal. Recording continues and sync resumes automatically when signal returns.';

  @override
  String get trackingGpsReady => 'GPS fix available';

  @override
  String get trackingGpsSearching => 'Searching GPS fix';

  @override
  String get trackingGpsNeedStableFix =>
      'Wait for a stable GPS fix (3 consecutive good fixes) before starting.';

  @override
  String trackingGpsPreparingCountdown(int seconds, String status) {
    return 'Starting in ${seconds}s - $status';
  }

  @override
  String get trackingRetryInBackground => 'Retry in background';

  @override
  String get trackingSuspiciousSaveTitle => 'Save this activity?';

  @override
  String trackingSuspiciousSaveMessage(String duration, String distance) {
    return 'This activity looks very short or unusual ($duration, $distance). Save anyway?';
  }

  @override
  String get trackingDiscardAction => 'Discard';

  @override
  String get trackingDiscardedActivity => 'Activity discarded';

  @override
  String trackingRepeatLast(String activity) {
    return 'Repeat last: $activity';
  }

  @override
  String get trackingActivitySavedCelebration => 'Activity saved';

  @override
  String get routeStatusMatched => 'Route: matched';

  @override
  String get routeStatusFallback => 'Route: raw fallback';

  @override
  String get routeStatusRaw => 'Route: raw GPS';

  @override
  String get apply => 'Apply';

  @override
  String get settingsTab => 'Settings';

  @override
  String get settingsScreen => 'Settings';

  @override
  String get serverSettings => 'Server';

  @override
  String get serverSettingsTitle => 'Server settings';

  @override
  String get loggedIn => 'Logged in';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUrlHint => 'https://example.com';

  @override
  String get tileServerUrl => 'Map tile server URL';

  @override
  String get tileServerUrlHint => 'https://tile.openstreetmap.org/...';

  @override
  String get savedSuccessfully => 'Settings saved successfully';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get settingsThemeSystem => 'Follow system';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemePreset => 'Color preset';

  @override
  String get settingsThemePresetEndurain => 'Endurain';

  @override
  String get settingsThemePresetOcean => 'Ocean';

  @override
  String get settingsThemePresetForest => 'Forest';

  @override
  String get settingsHighContrast => 'High contrast';

  @override
  String get settingsRouteMatchingTitle => 'Route matching';

  @override
  String get settingsRouteMatchingToggle => 'Enable route matching (MVP)';

  @override
  String get settingsRouteMatchingDescription =>
      'Uses road matching when available and automatically falls back to smoothed/raw GPS when matching is not possible.';

  @override
  String get settingsRouteDisplayModeTitle => 'Route display mode';

  @override
  String get settingsRouteDisplayModeAuto => 'Auto (recommended)';

  @override
  String get settingsRouteDisplayModeMatched => 'Matched preferred';

  @override
  String get settingsRouteDisplayModeRaw => 'Raw GPS';

  @override
  String get settingsGpsFilterModeTitle => 'GPS filter mode';

  @override
  String get settingsGpsFilterModeAuto => 'Auto by activity';

  @override
  String get settingsGpsFilterModeAutoDescription =>
      'Walk/Run use stricter filtering, Ride stays balanced. Best default.';

  @override
  String get settingsGpsFilterModeNormal => 'Normal (less strict)';

  @override
  String get settingsGpsFilterModeNormalDescription =>
      'Accepts more GPS points in difficult signal areas. Can include more noise.';

  @override
  String get settingsGpsFilterModeStrict => 'Strict (urban)';

  @override
  String get settingsGpsFilterModeStrictDescription =>
      'Rejects noisy points more aggressively. Useful in dense city areas.';

  @override
  String get settingsRouteMatchingEnabledLabel => 'Matched preview active';

  @override
  String get settingsAllowInsecureTls => 'Allow insecure TLS (test only)';

  @override
  String get settingsAllowInsecureTlsDescription =>
      'Use only for diagnostics on self-hosted servers. Disables certificate trust checks and is not recommended for normal use.';
}
