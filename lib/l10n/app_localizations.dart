import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// Generic error title - Used in: dialog_utils.dart
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// OK button label - Used in: dialog_utils.dart
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Cancel button label - Used in: dialog_utils.dart, server_settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button label - Used in: server_settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Back button label - Used in: login_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Validation message for required fields - Used in: validators.dart
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// Validation message for invalid URL - Used in: validators.dart
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get invalidUrl;

  /// Generic fallback error shown when no specific mapping exists - Used in: error_mapper.dart
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// Error shown for connectivity/timeouts - Used in: error_mapper.dart
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection and try again.'**
  String get errorNetwork;

  /// Error shown for TLS handshake/certificate validation failures - Used in: error_mapper.dart
  ///
  /// In en, this message translates to:
  /// **'Secure connection failed (TLS/SSL). Please verify certificate chain, hostname, and trusted CA.'**
  String get errorTls;

  /// Error shown for login/authentication failures - Used in: error_mapper.dart
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please check your credentials.'**
  String get errorAuthentication;

  /// Error shown for server-side failures - Used in: error_mapper.dart
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get errorServer;

  /// Error shown for invalid/missing server configuration - Used in: error_mapper.dart
  ///
  /// In en, this message translates to:
  /// **'Server configuration is invalid. Please verify your settings.'**
  String get errorConfiguration;

  /// Error shown for SSO specific failures - Used in: error_mapper.dart
  ///
  /// In en, this message translates to:
  /// **'Single sign-on failed. Please try again.'**
  String get errorSso;

  /// Validation message when HTTP URL is not allowed for server login - Used in: validators.dart
  ///
  /// In en, this message translates to:
  /// **'Please use an HTTPS URL'**
  String get httpsRequiredUrl;

  /// Title for login screen
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// Login button label
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Logout button label - Used in: settings_screen.dart, server_settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Logout confirmation dialog title - Used in: dialog_utils.dart (via server_settings_screen)
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutConfirmTitle;

  /// Logout confirmation dialog message - Used in: server_settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirmMessage;

  /// Warning shown when server logout fails but local logout succeeds - Used in: server_settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not logout from server, but logged out locally'**
  String get logoutServerFailedWarning;

  /// Retry button label - Used in: sso_webview_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// SSO WebView screen title - Used in: sso_webview_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get ssoWebViewTitle;

  /// SSO cancel button label - Used in: sso_webview_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ssoCancel;

  /// Generic SSO authentication error message - Used in: sso_webview_screen.dart
  ///
  /// In en, this message translates to:
  /// **'SSO authentication failed. Please try again.'**
  String get ssoAuthenticationFailed;

  /// Message shown when user cancels SSO flow - Used in: sso_webview_screen.dart
  ///
  /// In en, this message translates to:
  /// **'SSO authentication was cancelled.'**
  String get ssoAuthenticationCancelled;

  /// Message shown when WebView navigation host is not allowed - Used in: sso_webview_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Navigation was blocked for security reasons.'**
  String get ssoBlockedNavigation;

  /// SSO provider button label - Used in: login_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sign in with {provider}'**
  String ssoSignInWith(String provider);

  /// Divider text between SSO and traditional login - Used in: login_screen.dart
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get ssoOrDivider;

  /// Next button label for multi-step flows - Used in: login_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Username field label - Used in: login_screen.dart, server_settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// Username field hint text
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get usernameHint;

  /// Password field label - Used in: login_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Password field hint text
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// Show/hide password toggle label
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// MFA screen title
  ///
  /// In en, this message translates to:
  /// **'Two-Factor Authentication'**
  String get mfaTitle;

  /// MFA code field label
  ///
  /// In en, this message translates to:
  /// **'MFA code'**
  String get mfaCode;

  /// MFA code field hint text
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit code'**
  String get mfaCodeHint;

  /// MFA code validation error message
  ///
  /// In en, this message translates to:
  /// **'Please enter MFA code'**
  String get mfaCodeRequired;

  /// Generic title for help/info dialogs - Used in login/settings screens
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get helpTitle;

  /// Helper text for server URL input in login step 1
  ///
  /// In en, this message translates to:
  /// **'Enter the exact base URL of your Endurain server, including https:// and matching the certificate hostname. Example: https://train.example.com'**
  String get loginServerUrlHelp;

  /// Helper text explaining what the Next button does in login step 1
  ///
  /// In en, this message translates to:
  /// **'Next checks server settings and available login providers. If this step fails with TLS, verify full certificate chain, hostname/SAN, and Android trust.'**
  String get loginNextHelp;

  /// Helper text for insecure TLS toggle in login/settings
  ///
  /// In en, this message translates to:
  /// **'Test-only mode. If enabled, certificate validation is bypassed for diagnostics. If login only works with this mode, your server TLS trust chain or hostname setup must be fixed.'**
  String get loginTlsToggleHelp;

  /// MFA verification button label
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// Map tab label - Used in: app_bottom_nav.dart
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapTab;

  /// History tab label - Used in: app_bottom_nav.dart
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTab;

  /// Title for activity history screen - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Activity history'**
  String get historyTitle;

  /// Title for activity detail screen - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Activity details'**
  String get historyDetailTitle;

  /// Empty state title for history - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No activities yet'**
  String get historyEmptyTitle;

  /// Empty state body text for history - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Start and stop a tracking session to see your activities here.'**
  String get historyEmptyBody;

  /// Primary CTA in history empty state that jumps to tracking map - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Start first activity'**
  String get historyEmptyCtaStart;

  /// Error message for failed history loading - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not load activities. Please try again.'**
  String get historyLoadError;

  /// Label for track point count in activity details - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Track points'**
  String get historyTrackPoints;

  /// Hint below detail map to open full route/metrics view - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tap the map to open full route overview'**
  String get historyTapMapForOverview;

  /// Section header for activities from current day - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyGroupToday;

  /// Section header for activities from previous day - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get historyGroupYesterday;

  /// Section header for activities from current week - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get historyGroupThisWeek;

  /// Section header for older activities - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get historyGroupOlder;

  /// Filter chip label to show all activity types - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get historyFilterAll;

  /// History date range filter chip label for last 7 days - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'7d'**
  String get historyRange7d;

  /// History date range filter chip label for last 30 days - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'30d'**
  String get historyRange30d;

  /// History date range filter chip label for last 90 days - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'90d'**
  String get historyRange90d;

  /// History date range filter chip label for last year - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'1y'**
  String get historyRange1y;

  /// History date range filter chip label for all time - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get historyRangeAllTime;

  /// Button title to open history filter and sort bottom sheet - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Filter & sort'**
  String get historyFilterSort;

  /// Section label for history date range filters - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get historyDateRange;

  /// Section label for history sorting options - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get historySortBy;

  /// Sort option for newest activities first - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get historySortNewest;

  /// Sort option for oldest activities first - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get historySortOldest;

  /// Sort option for longest activities first - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Longest'**
  String get historySortLongest;

  /// Sort option for shortest activities first - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Shortest'**
  String get historySortShortest;

  /// Toggle label to filter history by not yet uploaded activities - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Only unuploaded activities'**
  String get historyOnlyUnuploaded;

  /// Badge for activities that are not uploaded yet - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Upload pending'**
  String get historyUploadPending;

  /// Badge for activities already uploaded to server - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get historyUploadDone;

  /// Dialog title to rename an activity - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Name activity'**
  String get historyRenameTitle;

  /// Input hint for activity naming - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'e.g. Evening ride'**
  String get historyRenameHint;

  /// Action label for deleting an activity - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get historyDeleteAction;

  /// Confirmation dialog title before deleting an activity - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete activity?'**
  String get historyDeleteTitle;

  /// Confirmation dialog message for deleting an activity - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This removes the activity from the app and (if uploaded) from the server.'**
  String get historyDeleteMessage;

  /// Snackbar text after successfully deleting an activity - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Activity deleted'**
  String get historyDeletedSuccess;

  /// Tooltip for map location lock/center button - Used in: map_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Center on my location'**
  String get mapCenterOnLocation;

  /// Label for activity type selector - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Activity type'**
  String get activityTypeLabel;

  /// Activity type label for running - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get activityTypeRun;

  /// Activity type label for riding - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get activityTypeRide;

  /// Activity type label for walking - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get activityTypeWalk;

  /// Activity type label for trail run - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Trail run'**
  String get activityTypeTrailRun;

  /// Activity type label for track run - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Track run'**
  String get activityTypeTrackRun;

  /// Activity type label for treadmill run - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Treadmill run'**
  String get activityTypeTreadmillRun;

  /// Activity type label for virtual run - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Virtual run'**
  String get activityTypeVirtualRun;

  /// Activity type label for road cycling - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Road cycling'**
  String get activityTypeRoadCycling;

  /// Activity type label for gravel cycling - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Gravel cycling'**
  String get activityTypeGravelCycling;

  /// Activity type label for mtb cycling - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'MTB cycling'**
  String get activityTypeMtbCycling;

  /// Activity type label for commuting cycling - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Commuting cycling'**
  String get activityTypeCommutingCycling;

  /// Activity type label for mixed surface cycling - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Mixed surface cycling'**
  String get activityTypeMixedSurfaceCycling;

  /// Activity type label for virtual cycling - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Virtual cycling'**
  String get activityTypeVirtualCycling;

  /// Activity type label for indoor cycling - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Indoor cycling'**
  String get activityTypeIndoorCycling;

  /// Activity type label for e-bike cycling - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'E-Bike cycling'**
  String get activityTypeEBikeCycling;

  /// Activity type label for e-bike mountain cycling - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'E-Bike mountain cycling'**
  String get activityTypeEBikeMountainCycling;

  /// Activity type label for indoor swimming - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Indoor swimming'**
  String get activityTypeIndoorSwimming;

  /// Activity type label for open water swimming - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Open water swimming'**
  String get activityTypeOpenWaterSwimming;

  /// Activity type label for general workout - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'General workout'**
  String get activityTypeGeneralWorkout;

  /// Activity type label for indoor walk - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Indoor walk'**
  String get activityTypeIndoorWalk;

  /// Activity type label for hike - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Hike'**
  String get activityTypeHike;

  /// Activity type label for rowing - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Rowing'**
  String get activityTypeRowing;

  /// Activity type label for yoga - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get activityTypeYoga;

  /// Activity type label for alpine ski - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Alpine ski'**
  String get activityTypeAlpineSki;

  /// Activity type label for nordic ski - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Nordic ski'**
  String get activityTypeNordicSki;

  /// Activity type label for snowboard - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Snowboard'**
  String get activityTypeSnowboard;

  /// Activity type label for ice skate - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Ice skate'**
  String get activityTypeIceSkate;

  /// Activity type label for transition - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Transition'**
  String get activityTypeTransition;

  /// Activity type label for strength training - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Strength training'**
  String get activityTypeStrengthTraining;

  /// Activity type label for crossfit - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Crossfit'**
  String get activityTypeCrossfit;

  /// Activity type label for tennis - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Tennis'**
  String get activityTypeTennis;

  /// Activity type label for table tennis - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Table tennis'**
  String get activityTypeTableTennis;

  /// Activity type label for badminton - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Badminton'**
  String get activityTypeBadminton;

  /// Activity type label for squash - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Squash'**
  String get activityTypeSquash;

  /// Activity type label for racquetball - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Racquetball'**
  String get activityTypeRacquetball;

  /// Activity type label for pickleball - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Pickleball'**
  String get activityTypePickleball;

  /// Activity type label for padel - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Padel'**
  String get activityTypePadel;

  /// Activity type label for windsurf - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Windsurf'**
  String get activityTypeWindsurf;

  /// Activity type label for stand up paddling - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Stand up paddling'**
  String get activityTypeStandUpPaddling;

  /// Activity type label for surf - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Surf'**
  String get activityTypeSurf;

  /// Activity type label for soccer - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Soccer'**
  String get activityTypeSoccer;

  /// Activity type label for cardio training - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Cardio training'**
  String get activityTypeCardioTraining;

  /// Activity type label for kayaking - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Kayaking'**
  String get activityTypeKayaking;

  /// Activity type label for sailing - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Sailing'**
  String get activityTypeSailing;

  /// Activity type label for snow shoeing - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Snow shoeing'**
  String get activityTypeSnowShoeing;

  /// Activity type label for inline skating - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Inline skating'**
  String get activityTypeInlineSkating;

  /// Activity type label for hiit - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'HIIT'**
  String get activityTypeHiit;

  /// Tracking status when session has not started - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get trackingIdle;

  /// Tracking status while session is active - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get trackingRecording;

  /// Tracking status while session is paused - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get trackingPaused;

  /// Tracking status after session stops - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get trackingStopped;

  /// Button label to start tracking - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Start tracking'**
  String get trackingStart;

  /// Button label to stop tracking - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Stop tracking'**
  String get trackingStop;

  /// Label for tracking duration metric - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get trackingDuration;

  /// Label for tracking distance metric - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get trackingDistance;

  /// Distance unit abbreviation used in tracking metrics - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get trackingDistanceUnitKm;

  /// Label for average pace metric - Used in: tracking_controls.dart, activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get trackingPace;

  /// Pace unit used for average pace metric - Used in: tracking_controls.dart, activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'min/km'**
  String get trackingPaceUnitMinKm;

  /// Label for average speed metric (used for cycling activities) - Used in: tracking_controls.dart, activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Avg speed'**
  String get trackingAverageSpeed;

  /// Label for live current speed metric in tracking controls - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Current speed'**
  String get trackingCurrentSpeed;

  /// Speed unit for cycling metrics - Used in: tracking_controls.dart, activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'km/h'**
  String get trackingSpeedUnitKmh;

  /// Label for elevation gain metric - Used in: tracking_controls.dart, activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Elevation gain'**
  String get trackingElevationGain;

  /// Elevation unit abbreviation - Used in: tracking_controls.dart, activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get trackingElevationUnitM;

  /// Label for elevation loss metric in activity details - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Elevation loss'**
  String get historyElevationLoss;

  /// Title for altitude chart in activity details - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Elevation profile'**
  String get historyElevationProfile;

  /// Fallback text when no altitude samples exist for an activity - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No altitude data available'**
  String get historyNoAltitudeData;

  /// Error message when tracking starts without location permission - Used in: map_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to start tracking.'**
  String get trackingPermissionRequired;

  /// Warning banner while tracking when GPS signal is temporarily unavailable - Used in: map_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No GPS signal. Recording continues and sync resumes automatically when signal returns.'**
  String get trackingGpsSignalLost;

  /// Status label when recent GPS fix is available before tracking start - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'GPS fix available'**
  String get trackingGpsReady;

  /// Status label when GPS fix is not yet available before tracking start - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Searching GPS fix'**
  String get trackingGpsSearching;

  /// Hint shown when user starts tracking without stable GPS quality lock - Used in: map_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wait for a stable GPS fix (3 consecutive good fixes) before starting.'**
  String get trackingGpsNeedStableFix;

  /// Countdown hint shown while app prepares tracking start and waits for GPS fix - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Starting in {seconds}s - {status}'**
  String trackingGpsPreparingCountdown(int seconds, String status);

  /// Action label in snackbar to retry failed upload in the background - Used in: map_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Retry in background'**
  String get trackingRetryInBackground;

  /// Dialog title shown for very short or unusual activities before keeping them - Used in: map_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save this activity?'**
  String get trackingSuspiciousSaveTitle;

  /// Dialog message shown when activity quality check flags unusual data - Used in: map_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This activity looks very short or unusual ({duration}, {distance}). Save anyway?'**
  String trackingSuspiciousSaveMessage(String duration, String distance);

  /// Action label to discard suspicious activity instead of saving - Used in: map_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get trackingDiscardAction;

  /// Snackbar shown after discarding suspicious activity - Used in: map_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Activity discarded'**
  String get trackingDiscardedActivity;

  /// Quick action label to start a new activity with last used type - Used in: tracking_controls.dart
  ///
  /// In en, this message translates to:
  /// **'Repeat last: {activity}'**
  String trackingRepeatLast(String activity);

  /// Short celebration toast shown right after a session is saved locally - Used in: map_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Activity saved'**
  String get trackingActivitySavedCelebration;

  /// Success message after uploading activity from map screen
  ///
  /// In en, this message translates to:
  /// **'Activity uploaded successfully'**
  String get trackingUploadSuccess;

  /// Status label when route is matched via OSRM - Used in: map_screen.dart, activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Route: matched'**
  String get routeStatusMatched;

  /// Status label when route matching fell back to local/raw smoothing - Used in: map_screen.dart, activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Route: raw fallback'**
  String get routeStatusFallback;

  /// Status label when route display mode is raw GPS - Used in: map_screen.dart, activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Route: raw GPS'**
  String get routeStatusRaw;

  /// Generic button label to apply current filters/settings - Used in: activity_history_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Settings tab label - Used in: app_bottom_nav.dart
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// Settings screen title - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsScreen;

  /// Server settings navigation label - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverSettings;

  /// Server settings screen title - Used in: server_settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Server settings'**
  String get serverSettingsTitle;

  /// Logged in section header - Used in: server_settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Logged in'**
  String get loggedIn;

  /// Server URL field label - Used in: login_screen.dart, server_settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// Server URL field hint text - Used in: login_screen.dart
  ///
  /// In en, this message translates to:
  /// **'https://example.com'**
  String get serverUrlHint;

  /// Tile server URL field label - Used in: server_settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Map tile server URL'**
  String get tileServerUrl;

  /// Tile server URL field hint text
  ///
  /// In en, this message translates to:
  /// **'https://tile.openstreetmap.org/...'**
  String get tileServerUrlHint;

  /// Settings save success message - Used in: server_settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get savedSuccessfully;

  /// Label for theme mode setting selector - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeMode;

  /// Theme option label for system mode - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsThemeSystem;

  /// Theme option label for light mode - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// Theme option label for dark mode - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// Label for choosing a color preset theme - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Color preset'**
  String get settingsThemePreset;

  /// Color preset option for default Endurain palette - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Endurain'**
  String get settingsThemePresetEndurain;

  /// Color preset option for ocean palette - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get settingsThemePresetOcean;

  /// Color preset option for forest palette - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get settingsThemePresetForest;

  /// Toggle label for high contrast colors - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get settingsHighContrast;

  /// Settings section header for theme controls - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsSectionTheme;

  /// Settings section header for route display options - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Route display'**
  String get settingsSectionRouteDisplay;

  /// Settings section header for server configuration - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsSectionServer;

  /// Settings section header for app metadata - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'About app'**
  String get settingsSectionAboutApp;

  /// Label for miniature current theme preview card - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Theme preview'**
  String get settingsThemePreviewTitle;

  /// Explanation for high contrast toggle impact - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'High contrast strengthens text and borders in key UI surfaces.'**
  String get settingsThemePreviewSubtitle;

  /// Label for app version/build info tile - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get settingsAppVersionTitle;

  /// Settings section title for route matching preview - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Route matching'**
  String get settingsRouteMatchingTitle;

  /// Toggle label to switch raw vs matched route preview - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Enable route matching (MVP)'**
  String get settingsRouteMatchingToggle;

  /// Explanation below route matching toggle - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Uses road matching when available and automatically falls back to smoothed/raw GPS when matching is not possible.'**
  String get settingsRouteMatchingDescription;

  /// Title for selecting how route should be displayed - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Route display mode'**
  String get settingsRouteDisplayModeTitle;

  /// Route display mode option that uses matching with fallback - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Auto (recommended)'**
  String get settingsRouteDisplayModeAuto;

  /// Route display mode option that prefers matched route - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Matched preferred'**
  String get settingsRouteDisplayModeMatched;

  /// Route display mode option that always uses raw GPS - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Raw GPS'**
  String get settingsRouteDisplayModeRaw;

  /// Title for selecting the GPS quality filter preset - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'GPS filter mode'**
  String get settingsGpsFilterModeTitle;

  /// GPS filter mode option that automatically adjusts by activity type - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Auto by activity'**
  String get settingsGpsFilterModeAuto;

  /// Description for automatic GPS filtering mode - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Walk/Run use stricter filtering, Ride stays balanced. Best default.'**
  String get settingsGpsFilterModeAutoDescription;

  /// GPS filter mode option with less strict filtering - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Normal (less strict)'**
  String get settingsGpsFilterModeNormal;

  /// Description for normal GPS filtering mode - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Accepts more GPS points in difficult signal areas. Can include more noise.'**
  String get settingsGpsFilterModeNormalDescription;

  /// GPS filter mode option with strict filtering for urban environments - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Strict (urban)'**
  String get settingsGpsFilterModeStrict;

  /// Description for strict GPS filtering mode - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Rejects noisy points more aggressively. Useful in dense city areas.'**
  String get settingsGpsFilterModeStrictDescription;

  /// Small in-map label when matched route preview is enabled - Used in: map_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Matched preview active'**
  String get settingsRouteMatchingEnabledLabel;

  /// Settings toggle label to bypass TLS certificate validation for self-hosted testing - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Allow insecure TLS (test only)'**
  String get settingsAllowInsecureTls;

  /// Settings warning text for insecure TLS toggle - Used in: settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Use only for diagnostics on self-hosted servers. Disables certificate trust checks and is not recommended for normal use.'**
  String get settingsAllowInsecureTlsDescription;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
