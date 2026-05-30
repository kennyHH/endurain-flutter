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
  String get errorActivityUploadFailed => 'Could not upload activity';

  @override
  String errorActivityUploadFailedWithDetails(String details) {
    return 'Could not upload activity: $details';
  }

  @override
  String get errorActivityUploadNotConfigured =>
      'Activity upload is not configured yet';

  @override
  String get errorFetchIdentityProvidersFailed =>
      'Could not load identity providers';

  @override
  String errorFetchIdentityProvidersFailedWithDetails(String details) {
    return 'Could not load identity providers: $details';
  }

  @override
  String get errorFetchProvidersFailed => 'Could not load sign-in providers';

  @override
  String errorFetchProvidersFailedWithDetails(String details) {
    return 'Could not load sign-in providers: $details';
  }

  @override
  String get errorFetchServerSettingsFailed => 'Could not load server settings';

  @override
  String errorFetchServerSettingsFailedWithDetails(String details) {
    return 'Could not load server settings: $details';
  }

  @override
  String get errorLoginError => 'Could not sign in';

  @override
  String errorLoginErrorWithDetails(String details) {
    return 'Could not sign in: $details';
  }

  @override
  String get errorLoginFailed => 'Sign-in failed';

  @override
  String errorLoginFailedWithDetails(String details) {
    return 'Sign-in failed: $details';
  }

  @override
  String get errorMfaVerificationError => 'Could not verify MFA code';

  @override
  String errorMfaVerificationErrorWithDetails(String details) {
    return 'Could not verify MFA code: $details';
  }

  @override
  String get errorMfaVerificationFailed => 'MFA verification failed';

  @override
  String errorMfaVerificationFailedWithDetails(String details) {
    return 'MFA verification failed: $details';
  }

  @override
  String get errorNoSessionIdReceived =>
      'No session ID was received from the server';

  @override
  String get errorNotAuthenticated => 'You are not signed in';

  @override
  String get errorPkceVerifierMissing => 'The sign-in verifier was not found';

  @override
  String get errorPkceVerifierMissingRestartLogin =>
      'The sign-in verifier was not found. Please start sign-in again.';

  @override
  String get errorServerUrlNotConfigured => 'Server URL is not configured';

  @override
  String get errorSessionExpired =>
      'Your session expired. Please sign in again.';

  @override
  String get errorSsoTokenExchangeError => 'Could not complete SSO sign-in';

  @override
  String errorSsoTokenExchangeErrorWithDetails(String details) {
    return 'Could not complete SSO sign-in: $details';
  }

  @override
  String get errorTokenExchangeError => 'Could not complete sign-in';

  @override
  String errorTokenExchangeErrorWithDetails(String details) {
    return 'Could not complete sign-in: $details';
  }

  @override
  String get errorTokenExchangeFailed => 'Token exchange failed';

  @override
  String errorTokenExchangeFailedWithDetails(String details) {
    return 'Token exchange failed: $details';
  }

  @override
  String get errorUnexpectedResponseFormat =>
      'The server returned an unexpected response';

  @override
  String get errorUnsupportedHttpMethod => 'Unsupported HTTP method';

  @override
  String errorUnsupportedHttpMethodWithDetails(String details) {
    return 'Unsupported HTTP method: $details';
  }

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
  String get ssoBrowserLaunchFailed =>
      'Could not open SSO sign-in in the system browser';

  @override
  String get ssoMissingSessionId => 'SSO callback did not include a session ID';

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
  String get verify => 'Verify';

  @override
  String get activityPause => 'Pause';

  @override
  String get activityDiscard => 'Discard';

  @override
  String get activityDiscardConfirmMessage =>
      'This will delete the recorded points for this activity.';

  @override
  String get activityDiscardConfirmTitle => 'Discard activity?';

  @override
  String get activityResume => 'Resume';

  @override
  String get activityLocationStreamFailed =>
      'Location updates stopped unexpectedly.';

  @override
  String get activityLocationPermissionDenied =>
      'Location permission is required to record an activity.';

  @override
  String get activityLocationPermissionDeniedForever =>
      'Location permission is blocked. Open settings to allow location access.';

  @override
  String get activityLocationServiceDisabled =>
      'Location services are disabled.';

  @override
  String get activityOpenSettings => 'Open settings';

  @override
  String get activityRecordingEmpty => 'No GPS points were recorded.';

  @override
  String get activityRecordingFailed => 'Recording failed.';

  @override
  String get activityStart => 'Start';

  @override
  String get activityStatDistance => 'Distance';

  @override
  String get activityStatDuration => 'Time';

  @override
  String get activityStatSpeed => 'Speed';

  @override
  String get activityStop => 'Stop';

  @override
  String get activityStopAndSave => 'Stop and save';

  @override
  String get activityStopConfirmMessage =>
      'Choose whether to keep this recording or discard it.';

  @override
  String get activityStopConfirmTitle => 'End activity?';

  @override
  String get activityStopping => 'Stopping';

  @override
  String get activityTypeHike => 'Hike';

  @override
  String get activityTypeLabel => 'Activity type';

  @override
  String get activityTypeOther => 'Other';

  @override
  String get activityTypeRide => 'Ride';

  @override
  String get activityTypeRun => 'Run';

  @override
  String get activityTypeWalk => 'Walk';

  @override
  String get activityRetryUpload => 'Retry upload';

  @override
  String get activityUploadFailed => 'Upload failed';

  @override
  String get activityUploadReady => 'Ready to upload';

  @override
  String get activityUploaded => 'Uploaded';

  @override
  String get activityUploading => 'Uploading';

  @override
  String get mapTab => 'Map';

  @override
  String get myLocation => 'My Location';

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
  String get notConfigured => 'Not configured';

  @override
  String get notLoggedIn => 'Not logged in';

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
}
