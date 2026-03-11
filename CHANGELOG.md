# Changelog

All notable changes to Endurain mobile app are documented in this file.

## [Unreleased]

### Added
- Added `GPS filter mode` setting with manual override options: `Auto by activity`, `Normal`, and `Strict (urban)`.
- Added user-facing explanations for each GPS filter mode in Settings (EN/PT localization).

### Changed
- `Auto by activity` now acts as intelligent default GPS behavior: stricter for Walk/Run, balanced for Ride.
- GPS filter mode is now persisted and applied live to tracking logic without requiring app restart.

## [0.0.17] - 2026-03-11

### Changed
- Improved GPS quality filtering with stricter accuracy acceptance defaults to reduce urban drift and building-crossing artifacts.
- Added activity-specific segment speed caps (walk/run/ride) to reject implausible jumps while preserving normal movement.
- Added stable GPS lock gating before tracking start (requires multiple consecutive good fixes) for cleaner first tracked points.

## [0.0.16] - 2026-03-11

### Added
- Added activity deletion flow in history/details with confirmation dialog and success/error feedback.
- Added suspicious-activity safeguard before keeping very short/unusual sessions (confirm save or discard).

### Changed
- Removed redundant `Enable route matching` setting entry and kept a single `Route display mode` control.
- Added server delete attempt for uploaded activities before local removal, so app/server state stays aligned whenever backend supports delete endpoints.

## [0.0.15] - 2026-03-11

### Fixed
- Improved upload fallback behavior for `400/404/415/422` responses so method/endpoint/file-field candidates are fully exhausted before failing.
- Improved upload error detail extraction for structured validation responses (e.g. now compact messages like `file: Field required` instead of raw JSON blobs in snackbars).
- Improved selected activity type chip contrast in tracking controls (selected text/icon now high-contrast and clearly readable).

### Changed
- GPX export now uses human-readable activity names by default (`Run|Ride|Walk YYYY-MM-DD HH:MM`) instead of numeric IDs.
- GPX export now normalizes first/last trackpoint timestamps to activity start/end to reduce metric drift (duration/pace) between app and server.

## [0.0.14] - 2026-03-11

### Added
- Added haptic feedback for key tracking moments: start (countdown + recording start), pause/resume, stop, and upload success/failure feedback.
- Added explicit route status labels in map/history/detail flows to clarify route rendering mode (`matched`, `raw fallback`, `raw GPS`).
- Added upgraded history empty-state CTA (`Start first activity`) to jump directly back to map tracking.
- Added a mini save celebration toast right after activity persistence (`Activity saved` with celebration icon).

### Changed
- Standardized metric formatting through a shared formatter utility for distance, duration, pace, and cycling speed (`km/h` for ride activities).
- Improved consistency of movement metrics across tracking panel and history/detail cards while keeping cycling explicitly speed-based.

### Compatibility
- Preserved Endurain server upload compatibility: no payload schema, endpoint, or multipart field behavior was changed in this release.
- Upload pipeline remains unchanged functionally; this release is UI/UX-focused around tracking feedback and display consistency.

## [0.0.13] - 2026-03-11

### Fixed
- Fixed Android release networking by adding missing `android.permission.INTERNET` to the main manifest.
- Resolved DNS lookup failures in release builds (`Failed host lookup`) that occurred despite valid HTTPS configuration.

## [0.0.12] - 2026-03-11

### Fixed
- Preserved original low-level TLS/network error context by rethrowing `ApiRequestException` in auth/server/SSO services instead of wrapping it into generic exceptions.
- Improved `ApiRequestException.toString()` to include the underlying `cause`, making handshake diagnostics actionable in login error dialogs.

### Changed
- Hardened debugging path for TLS failures so certificate vs. protocol/cipher/handshake issues can be distinguished with real runtime evidence.

## [0.0.11] - 2026-03-11

### Fixed
- Fixed login TLS toggle behavior by recreating default auth/network service instances after toggle changes, ensuring updated TLS mode is applied to fresh HTTP clients.
- Fixed login help UX: explanatory helper texts are no longer always visible; help content is now shown only via explicit `i`/`?` interactions.

### Changed
- Improved login step 1 guidance with contextual help icons tied to server URL, Next action, and TLS test toggle.

## [0.0.10] - 2026-03-11

### Added
- Added contextual help texts and tooltips on login step 1 for server URL, Next action, and TLS test toggle.
- Added additional help action/tooltip for insecure TLS toggle in Settings (Material and Cupertino).

### Changed
- Improved in-app guidance for TLS troubleshooting so users can understand what each login control does without leaving the screen.

## [0.0.9] - 2026-03-11

### Fixed
- Fixed TLS diagnostics usability before authentication: insecure TLS test toggle is now available directly on login step 1.
- Improved TLS error detail visibility in login flow even when lower-level exceptions are wrapped by service layers.

### Changed
- Added login-screen controls for `Allow insecure TLS (test only)` on both Material and Cupertino flows, with persisted preference.

## [0.0.8] - 2026-03-11

### Added
- Added optional Settings toggle `Allow insecure TLS (test only)` to bypass certificate validation for self-hosted diagnostics.
- Added persisted storage for insecure TLS testing mode so behavior is retained across app restarts.

### Changed
- Wired global HTTP override to apply insecure TLS mode only when the user explicitly enables it in Settings.
- Improved troubleshooting flow for HTTPS login issues on self-hosted instances where Android trust chain validation fails despite apparently valid certificates.

### Security
- Insecure TLS mode remains disabled by default and is explicitly labeled as test-only.

## [0.0.7] - 2026-03-11

### Fixed
- Improved login diagnostics for HTTPS local instances by classifying TLS handshake/certificate failures separately from generic network errors.
- Added explicit TLS-aware user error message mapping (`errorTls`) instead of reporting all handshake failures as `Network error`.
- Extended login error dialog to include low-level TLS cause details (when available) for faster troubleshooting of certificate chain/hostname trust issues.

### Changed
- Updated API request executor exception typing to distinguish `tls` vs. `network` failures.
- Added tests for TLS error mapping in `AppErrorMapper`.

## [0.0.6] - 2026-03-11

### Fixed
- Fixed login flow for self-hosted local servers by allowing `http://` URLs for localhost and private network ranges in server URL validation.
- Fixed Android connectivity for local non-HTTPS endpoints by enabling cleartext traffic support in app manifest.
- Reduced false `Network error` cases during server URL step for reachable local Docker/self-hosted instances.

### Changed
- Improved visibility of the `Next` button on login step 1 (stronger contrast, clearer visual hierarchy, explicit arrow icon).
- Added/updated validator tests to cover local HTTP server URLs and preserve HTTPS enforcement for public/external hosts.

## [0.0.5] - 2026-03-11

### Added
- Added MVP route matching preview toggle in Settings with user-facing explanation text.
- Added persistent storage for route matching preview preference.
- Added `MapMatchingPreviewService` with safe fallback to raw GPS track points.
- Added visual indicator in live map view when matched preview is active.

### Changed
- Updated map and history route rendering to support `Raw` vs `Matched preview` comparison mode.
- Extended route rendering flow in map/history/detail to use preview matching when enabled and raw points when disabled.
- Improved release discipline: version is now incremented for this release and changelog updated with shipped scope.

## [0.0.4] - 2026-03-11

### Added
- Added history filter by time range (`7d`, `30d`, `90d`, `1y`, `All time`).
- Added ability to name/rename activities from activity detail screen.
- Added bottom-sheet based History filter/sort flow, including `only unuploaded` toggle.
- Added long-press rename directly from History activity cards.
- Added pending-upload badge for activities not yet uploaded.

### Changed
- Improved history list title rendering to prefer custom activity names when available.
- Improved upload compatibility for self-hosted servers by retrying upload with `PUT` when `POST` returns `405 Method Not Allowed`.
- Improved upload feedback to include server detail text (parsed from response body when available).
- Added snackbar action to retry failed uploads in background after stopping a session.

## [0.0.3] - 2026-03-11

### Changed
- Replaced the previous green/Komoot-like accent palette with Endurain-inspired brand colors (warm orange + deep blue) across Material and Cupertino themes.
- Updated tracking semantic colors and selected-chip accents to match Endurain branding.
- Updated active route polyline color in map tracking to use the current theme primary color.
- Updated location marker blue tone to Endurain brand blue.
- Updated Android 12+ dark splash icon background color to brand orange family.
- Updated Android bottom navigation icons to outlined style for better visual consistency with Endurain UI language.

## [0.0.2] - 2026-03-11

### Added
- Added GPS signal loss handling during active recording with automatic stream re-subscribe.
- Added explicit GPS warning banner in tracking view when no location updates are received.
- Added Android 12+ splash theme resources (`values-v31` and `values-night-v31`) for consistent startup branding.
- Added activity type filters in history (`All`, `Run`, `Ride`, `Walk`).
- Added route map preview for each activity card in history.
- Added large route map view in activity detail with start/end markers.

### Changed
- Improved upload robustness with multipart field fallbacks (`file`, `gpx`, `gpx_file`, `upload`) to better match different backend expectations.
- Improved upload failure feedback with HTTP status code in snackbar when available.
- Refactored settings screen into clearer sections (Appearance, Server, App metadata).
- Added selectable light/dark/system theme mode and high contrast option in settings.
- Increased bottom navigation size (icons, labels, and tab bar height) for better usability.
- Updated history and activity detail design to a more compact metric layout.
- Improved API URL handling with strict HTTP/HTTPS validation and safer path normalization.
- Enabled release size optimizations (R8 minification + resource shrinking) in Android release build.

### Fixed
- Fixed Android build metadata key usage to align with current `--dart-define` values (`BUILD_DATE`, `GIT_SHA`).
- Fixed map tracking panel reset after stop so previous session metrics/route no longer remain visible.

## [0.0.1] - 2026-03-11

### Added
- Added pause/resume controls to the tracking UI with clear session state handling.
- Added automatic activity upload after stop, including user feedback for success/failure.
- Added manual upload retry from activity details in history.
- Added real-time history updates via repository watch stream (no app restart required).
- Added reusable `BrandLogo` widget for consistent in-app logo usage.
- Added adaptive and monochrome launcher icon pipeline for Android (including themed icon support).
- Added app branding guideline documentation in `DOCS/branding-icons-guideline.md`.

### Changed
- Updated tracking engine stop logic to support stopping from both recording and paused states.
- Updated Android splash background to show branded launcher icon during app startup.
- Updated settings UI to include a dedicated **App version** entry (version + build number).
- Improved icon generation configuration in `pubspec.yaml` and regenerated launcher assets for Android/iOS/macOS.

### Fixed
- Fixed sessions not being persisted when stop was triggered from paused state.
- Fixed activity history not refreshing after new tracked activities were saved.
- Fixed missing upload retry path for activities that failed server upload.

### Notes
- Existing tests were expanded and all current test suites pass after these updates.
