# Changelog

All notable changes to Endurain mobile app are documented in this file.

## [Unreleased]

## [0.0.34] - 2026-03-19

### Fixed
- Triggered first-run tracking permissions onboarding independently from server login/auth state after app unlock.
- Added a tracking start first-run permission gate so users are guided into location/battery setup before recording.
- Updated permission onboarding completion handling to remain pending until location access is actually granted.
- Improved server-side activity deletion by prioritizing persisted numeric server IDs (`server_activity_id`) over local client IDs.
- Improved delete error reporting by preserving the first non-405 server failure detail instead of surfacing a later fallback 405 message.
- Persisted `server_activity_id` from successful upload responses to support robust follow-up delete operations.
- Prevented delete calls with out-of-range local IDs (timestamp-style IDs) to avoid backend `500 Internal Server Error` from integer overflow.
- Added explicit user-facing error when no backend-compatible server ID is available for server-side deletion.
- Fixed Activity Details upload retry CTA to disappear immediately after successful retry upload without requiring navigation away.
- Updated Activity Details GPX export to share a real file using naming-convention filenames.
- Improved pace chart rendering for very short runs so pace appears before the ~10m mark.
- Added average speed metric to Activity Details for run/walk in addition to pace.
- Tuned run/walk start-window min-distance filtering to accept high-confidence ~4m early segments during the first seconds.
- Aligned run/walk pace display with server-compatible track-geometry pacing for closer parity after imports.
- Added app-wide proactive session refresh on resume and periodic lifecycle intervals to reduce unexpected re-logins.
- Added token-expiry-aware refresh gating so silent refresh runs near expiry instead of on every wake cycle.
- Added single-flight refresh deduplication to prevent parallel refresh races from concurrent API requests.
- Added upload eligibility policy matrix to block empty/meaningless activities before server upload attempts.
- Updated Activity Details to replace retry CTA with a clear non-uploadable hint when activity quality is below upload thresholds.
- Hydrated History card metrics from full activities when summaries omit track data, improving pace/elevation consistency with details.
- Persisted server-returned distance, duration, and elevation metrics locally after successful upload for closer app/server parity.
- Fixed History hydration gate to reload full activity data when summary metrics are implausible (e.g., 0s/0.00km despite route preview points).
- Fixed stale History metric snapshots by allowing timed re-hydration retries while summary rows remain implausible, preventing persistent 0s/0.00km cards for pending uploads.

### Testing
- Added controller regression coverage ensuring first-run onboarding is shown even when not authenticated.
- Added controller regression coverage for permission onboarding completion behavior when location permission stays denied.
- Added upload/delete regression tests for `server_activity_id` persistence, server-ID-first delete routing, and delete failure prioritization (non-405 over 405).
- Added regression coverage for out-of-range local IDs to ensure delete requests are not sent with overflow-prone IDs.
- Added UI regression coverage for immediate hiding of `Retry Upload` button in Activity Details after success.
- Added regression coverage for GPX naming convention output and very short-distance pace chart start behavior.
- Added tracking engine regression coverage for high-confidence early run warmup segments around 4m.
- Added metric formatter regression coverage for server-compatible pace calculation and distance fallback behavior.
- Added auth/session regression coverage for refresh deduplication and token-fresh skip behavior in resume coordinator.
- Added upload policy regression coverage for blocked short/empty activities and valid activity pass-through.
- Added regression coverage for hydration-based History pace consistency and server-metric persistence after upload.
- Added regression coverage ensuring History hydrates full metrics even when summary rows contain trackpoints but zero duration/distance.
- Added regression coverage for stale-snapshot refresh behavior when summary rows stay implausible across repository emissions.

## [0.0.33] - 2026-03-18

### Changed
- Updated GPX export filename convention to a clear, human-readable format: `YYYY-MM-DD_HH-mm_Type[_Name].gpx`.
- Improved tracking start UX by keeping `Start tracking` visible but disabled until a stable GPS fix is available, with explicit user guidance.
- Added explicit upload visibility metadata (`hidden=false` / `visibility=public` variants) to align with server defaults and reduce hidden imports.
- Added stable upload idempotency signaling via `Idempotency-Key` and `X-Upload-Activity-Id`.

### Fixed
- Fixed duplicate upload race windows for the same activity with in-flight deduplication per activity id.
- Fixed repeated re-uploads after successful transfers by persisting upload success (`uploaded=true`) and short-circuiting already-uploaded activities.
- Fixed queue replay behavior by persisting upload success after queued retries and removing stale queued ids.

### Testing
- Added regression tests for multipart upload metadata, in-flight deduplication, already-uploaded short-circuiting, and queue success persistence.

## [0.0.32] - 2026-03-12

### Changed
- Introduced improved map navigation and camera behavior with heading-up and north-up workflows.
- Updated tracking controls and activity selection to support full activity catalog usage.
- Added configurable GPS filter modes (`Auto by activity`, `Normal`, `Strict`) with persisted settings.

### Fixed
- Corrected app version display and stabilized map camera behavior during movement.
- Removed remaining analyzer issues in tracking/map flows and aligned tests with the updated selector interaction.


## [0.0.31] - 2026-03-12

### Added
- **Login Screen Footer:** Added "Powered by Endurain" footer with heart icon and copyright year.
- **GPX Export:** Added "Export GPX" button to Activity Details screen, allowing users to share or save their recorded tracks.
- **Settings Tooltips:** Added descriptive tooltips to all settings items for better usability.
- **Map Compass Improvements:** Added tooltips to map controls and refined compass logic (North Up vs. Heading Up).
- **Map Editable Fields:** Changed the edit indicator icon to a "+" symbol for clearer affordance.

### Changed
- **Settings UI:** Removed the Theme Preview component to clean up the layout.
- **Map UI:** Ensured user location dot remains centered above the bottom information panel.

### Fixed
- **App Version:** Corrected version display in Settings and build artifacts.
- **UI Consistency:** Standardized tooltip behavior across Material and Cupertino widgets where possible.

## [0.0.28] - 2026-03-12

### Added
- **UI Overhaul (Map & Tracking):**
  - **Grid Layout:** New bottom sheet design with a 2x2 metric grid (Distance, Elevation, Speed, Avg Speed) and pagination for additional stats.
  - **Floating Controls:** Moved Compass, Layer Selector, and Location Lock to a floating column on the right side of the map.
  - **Compass Logic:** Tap compass to reset heading to North (0°).
  - **Activity Selector:** Split bottom bar layout in Idle state (Selector + Large Start Button).
- **Robust Audio Feedback:**
  - **Engine-Driven:** Moved audio logic (Countdown, Splits, GPS) to the background-aware Tracking Engine, ensuring announcements work even when the screen is locked.
  - **GPS Status:** Added "Signal Lost/Recovered" announcements with a 60s debounce to prevent spam.
  - **Countdown:** "6, 5, 4, 3, 2, 1, Go!" sequence handled by the engine.
- **Color Presets:**
  - **New Palette:** Replaced "Custom Pastel" with 6 professional presets: Ocean, Forest, Slate, Twilight, Ember, Berry.
  - **Accessibility:** Optimized contrast for both Light and Dark modes.

### Changed
- **Codebase:** Refactored `TrackingSessionEngine` to support dependency injection for better testing.
- **Testing:** Updated all unit and integration tests to use a mocked Audio Service, fixing CI failures.

### Fixed
- **App Version:** Corrected version display in Settings and build artifacts.
- **Countdown:** Fixed issue where countdown audio might stop if the app was backgrounded immediately.

## [0.0.27] - 2026-03-12

### Added
- **Audio Feedback (Voice Coach):**
  - Added voice announcements for Start Countdown (6s), "Let's go" confirmation, and KM splits (Pace).
  - Added Speaker Toggle button to Map Screen (Top-Left) to mute/unmute announcements.
  - Added Audio Settings section in Settings Screen.
- **Custom Theming:**
  - Added "Custom (Pastel)" theme preset with a color picker.
  - Removed "Endurain" preset in favor of "Ocean" (default), "Forest", and "Custom".
  - Custom pastel colors are applied to high-contrast boxes (History, Tracking) and Primary elements.

### Changed
- **Elevation Profile:** Applied moving average smoothing to the elevation chart in Activity Details to reduce visual noise ("zackig" lines).
- **Map UI:** Relocated GPS centering button to accommodate the new Audio Toggle button.
- **APK Size:** Maintained split APK configuration for optimal download size (~19MB).

### Testing
- `flutter analyze` passed.
- `flutter test` passed.

## [0.0.26] - 2026-03-12

### Added
- Added pastel color palettes for Forest, Ocean, and Endurain presets to `EndurainColors`.
- Implemented high-contrast theme overrides that use preset-specific pastel backgrounds instead of harsh black/white.

### Changed
- Updated `AppTheme` to dynamically map surface colors to pastel tones when High Contrast mode is active.
- Refactored `TrackingControls`, `ActivityHistoryScreen`, and `ActivityDetailScreen` to use theme-aware surface colors, ensuring cards match the selected preset (Green/Blue/Teal) in both Light and Dark modes.
- Reverted APK build configuration to generate split APKs (arm64-v8a) by default, reducing download size from ~55MB to ~19MB.

### Testing
- `flutter analyze` passed.
- `flutter test` passed.

## [0.0.25] - 2026-03-12

### Added
- Added high-contrast semantic color tokens to the design system (`EndurainColors.highContrastSurface`, `highContrastBorder`).
- Added transparent-background metric tiles with distinct borders for cleaner list visuals.

### Changed
- Refactored all high-contrast UI elements to use centralized theme tokens instead of hardcoded values.
- Polished `ActivityDetailScreen` to match the new History card aesthetics (Black surface, white borders, compact metrics).
- Unified card styling across History and Detail screens for consistent visual hierarchy.

### Testing
- `flutter analyze` passed.
- `flutter test` passed.

## [0.0.24] - 2026-03-12

### Added
- Added Android background location permissions and foreground service configuration for reliable tracking.
- Added "Get Last Known Position" logic to map initialization for instant location feedback.
- Added structured layout to Server Settings screen with grouped cards and clearer typography.

### Changed
- Refactored `ServerSettingsScreen` to match the main Settings design language (Cards, Section Headers).
- Optimized GPS fixing time by prioritizing last known location before waiting for satellite lock.
- Configured Android foreground notification to prevent tracking termination by the OS.

### Testing
- `flutter analyze` passed.
- `flutter test` passed.

## [0.0.23] - 2026-03-12

### Added
- Added high-contrast tracking metrics (White text on Black background) for better readability in sunlight.
- Added responsive single-line metric layout for History list items (no horizontal scrolling required).

### Changed
- Increased font size for tracking metric values (36/48pt) for immediate legibility.
- compacted vertical spacing in tracking controls to maximize map visibility.
- Enforced high-contrast styling for History cards (Black background with visible borders).
- Enabled map interaction (pinch/zoom/pan) in Activity Details screen.
- Tuned GPS settings for maximum responsiveness (zero distance filter) to improve track accuracy.

### Fixed
- **App Version:** Corrected version display in Settings and build artifacts.
- Fixed layout overflow in History list items by using flexible sizing for metrics.

### Testing
- `flutter analyze` passed.
- `flutter test` passed.

## [0.0.22] - 2026-03-12

### Added
- Added persistent upper-half user positioning while location lock is active in map tracking, keeping the GPS marker visible above panel-heavy UI.
- Added metric paging refinements in tracking panel to prioritize tap targets and maintain swipe discoverability.

### Changed
- Moved tracking panel lower and reduced internal whitespace so Start/Pause/Stop controls stay visible without clipping.
- Increased activity-type selector touch area (larger icon and vertical hitbox) for easier interaction.
- Tightened spacing between metric block, activity-type selector, and action buttons in map tracking.
- Reworked Activity History cards to a denser header layout (activity + date/time range + uploaded badge in one row) to free map space.
- Removed top summary text row in history cards and moved core metrics into a single horizontal line under the map preview.
- Increased History card and metric contrast with stronger surface/border separation.
- Removed route status badge from history list map previews; route status remains in detail view.
- Enabled pinch/pan interaction on Activity Details route map.
- Reduced vertical footprint of elevation profile in details and moved profile block closer to metric cards.
- Moved elevation min/max values from right header into left Y-axis labels beside the profile chart.

### Fixed
- **App Version:** Corrected version display in Settings and build artifacts.
- Fixed cryptic successful-save/upload feedback by suppressing server detail formatting on success and showing clean user-facing success text.
- Fixed jagged elevation profile rendering by switching to smoothed curve drawing.
- Fixed stale settings UX by removing High Contrast toggle section while keeping high-contrast rendering active.

### Testing
- `flutter analyze` passed.
- `flutter test` passed.

## [0.0.21] - 2026-03-12

### Added
- Added horizontal metric paging in live map tracking panel: swipe left/right between two metric sets.
- Added upload-success localization key for activity upload feedback (`trackingUploadSuccess`, EN/PT).

### Changed
- Increased tracking overlay height factors to prevent action button clipping on compact map screens.
- Moved `Current speed` from action area into the second metrics page to keep Start/Pause/Stop always visible.
- Refined Activity History card contrast with stronger container/background separation and subtle primary-accent border.
- Enabled interactive route map in Activity Details (pinch-zoom and pan) while preserving initial full-route fit on open.
- Updated activity upload success snackbar text on map screen to a clear activity-focused confirmation.

### Fixed
- **App Version:** Corrected version display in Settings and build artifacts.
- Fixed missing uploaded-state badge by showing explicit states for both pending and uploaded activities in History.
- Fixed missing readability of elevation context by adding min/max elevation summary near the profile header.
- Fixed test regressions introduced by tracking panel metric layout changes.

### Testing
- `flutter analyze` passed.
- `flutter test` passed.

## [0.0.20] - 2026-03-12

### Added
- Added uploaded-state badge in Activity History (`Uploaded`) with cloud check icon for sessions already synced to server.
- Added distance scale under the elevation profile (start/mid/end km markers) in Activity Details.

### Changed
- Removed secondary route-overview drilldown from Activity Details map tap to keep a single details view.
- Activity Details map now opens already fitted to the full route bounds so the complete track is visible without manual pinch/zoom.
- Increased Activity Details map height and enlarged key metric values for better readability.
- Compressed elevation profile block to free vertical space for map and metrics while keeping elevation trend visibility.
- Removed drag-handle/drag-resize behavior from live tracking overlay to keep controls always stable and visible.
- Removed `Repeat last ...` shortcut from live map tracking controls.
- Merged `Idle` status and GPS state (`Searching GPS fix`/ready) into a single top row in the tracking panel.
- Moved GPS recenter action from bottom-right to top-right in map view and shifted tracking panel lower to expose more map area.
- Tuned tracking panel compact layout so sport selector and Start/Pause/Stop controls remain visible with larger numbers.
- Set current-speed value emphasis to match primary metric size hierarchy in the live tracking panel.

### Fixed
- **App Version:** Corrected version display in Settings and build artifacts.
- Improved route visibility defaults so route geometry is consistently visible in Activity Details on open.
- Kept user position centered/visible during live map tracking by favoring location lock behavior.

### Testing
- `flutter analyze` passed.
- `flutter test` passed.

## [0.0.19] - 2026-03-12

### Added
- Added visible drag handle at the top of the tracking overlay (Material + Cupertino) to clarify manual panel resizing.
- Added live `Current speed` metric to tracking controls, computed from the most recent GPS segment and localized (EN/PT).

### Changed
- Reworked tracking overlay sizing behavior for small screens with automatic compact mode based on available height.
- Added manual overlay height control via vertical swipe gestures (swipe up/down) plus double-tap reset back to automatic sizing.
- Compressed tracking card spacing and action-area layout so Start/Pause/Stop controls remain visible on constrained viewports.
- Improved activity type selector compactness (padding/icon spacing) to prevent clipping on small devices.
- Increased key metric number size while preserving fit behavior.

### Testing
- `flutter analyze` passed.
- `flutter test test/features/map/tracking_controls_test.dart` passed.
- `flutter test` passed.

## [0.0.18] - 2026-03-12

### Added
- Added a dedicated Theme preview tile in Settings with a miniature card showing active background, surface, and accent colors for the current theme preset.
- Added clear Settings section headers across platforms: Theme, Route display, Server, and About app.
- Added new localization keys (EN/PT) for section titles and app metadata labels in the updated Settings layout.

### Changed
- Refined Settings information architecture for both Material and Cupertino conventions using sectioned grouped lists.
- Improved high-contrast behavior in key list widgets by increasing subtitle and icon readability in light and dark themes.
- Polished history/detail micro-interactions and metric presentation from prior support work as part of release hardening.

### Security
- Re-validated release security baseline: no hard-coded secrets introduced in current release changes and release signing remains explicit in Gradle configuration.

### Testing
- `flutter analyze` passed.
- `flutter test` passed.

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
- **App Version:** Corrected version display in Settings and build artifacts.
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
- **App Version:** Corrected version display in Settings and build artifacts.
- Fixed Android release networking by adding missing `android.permission.INTERNET` to the main manifest.
- Resolved DNS lookup failures in release builds (`Failed host lookup`) that occurred despite valid HTTPS configuration.

## [0.0.12] - 2026-03-11

### Fixed
- **App Version:** Corrected version display in Settings and build artifacts.
- Preserved original low-level TLS/network error context by rethrowing `ApiRequestException` in auth/server/SSO services instead of wrapping it into generic exceptions.
- Improved `ApiRequestException.toString()` to include the underlying `cause`, making handshake diagnostics actionable in login error dialogs.

### Changed
- Hardened debugging path for TLS failures so certificate vs. protocol/cipher/handshake issues can be distinguished with real runtime evidence.

## [0.0.11] - 2026-03-11

### Fixed
- **App Version:** Corrected version display in Settings and build artifacts.
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
- **App Version:** Corrected version display in Settings and build artifacts.
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
- **App Version:** Corrected version display in Settings and build artifacts.
- Improved login diagnostics for HTTPS local instances by classifying TLS handshake/certificate failures separately from generic network errors.
- Added explicit TLS-aware user error message mapping (`errorTls`) instead of reporting all handshake failures as `Network error`.
- Extended login error dialog to include low-level TLS cause details (when available) for faster troubleshooting of certificate chain/hostname trust issues.

### Changed
- Updated API request executor exception typing to distinguish `tls` vs. `network` failures.
- Added tests for TLS error mapping in `AppErrorMapper`.

## [0.0.6] - 2026-03-11

### Fixed
- **App Version:** Corrected version display in Settings and build artifacts.
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
- Replaced the previous green/industry standard-like accent palette with Endurain-inspired brand colors (warm orange + deep blue) across Material and Cupertino themes.
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
- **App Version:** Corrected version display in Settings and build artifacts.
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
- **App Version:** Corrected version display in Settings and build artifacts.
- Fixed sessions not being persisted when stop was triggered from paused state.
- Fixed activity history not refreshing after new tracked activities were saved.
- Fixed missing upload retry path for activities that failed server upload.

### Notes
- Existing tests were expanded and all current test suites pass after these updates.
