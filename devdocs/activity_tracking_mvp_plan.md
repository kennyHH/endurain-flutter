# Activity Tracking MVP Plan

## Goal

Implement the first usable activity tracking flow for Endurain Mobile: record an
activity from live GPS points, show basic recording stats, generate a GPX file,
and prepare a secure upload path to an Endurain server.

Each phase below is intentionally scoped to take no more than 15 minutes to
implement and review. If a phase starts to exceed that limit, stop at the
acceptance checks, split the remaining work into a new phase, and avoid broad
refactors.

## Guiding Principles

- Keep changes small, reviewable, and isolated to the activity feature unless a
  shared abstraction is clearly needed.
- Never hardcode user-facing strings. Add English and Portuguese localization
  keys in the appropriate ARB section and regenerate l10n output.
- Prefer immutable data models and pure calculation helpers for activity stats.
- Treat GPS data as sensitive personal data. Store it only when necessary,
  delete temporary files after upload or discard, and avoid logging coordinates.
- Use existing services and patterns first: `LocationService`, `ApiClient`,
  `SecureStorageService`, `AppScope`, `AppServices`, feature folders,
  constants, and platform-adaptive UI.
- Keep activity workflow state in a controller. Keep `MapScreen` focused on map
  rendering and user intent forwarding.
- Add tests beside risky logic: distance calculation, GPX generation, state
  transitions, and upload error handling.

## Assumptions To Confirm Early

- Endurain server GPX upload endpoint and multipart field name are not yet
  defined in the mobile codebase.
- The first MVP can keep recorded points in memory while recording.
- Persistent draft recovery can be added later after the basic recording flow is
  reliable.
- Background tracking is out of scope for this MVP unless explicitly requested.

## Phase 1: Confirm API Contract

Timebox: 15 minutes.

Status: Completed (documentation only). Checked in this mobile repository. No
existing GPX or activity upload endpoint, multipart field name, or expected
response contract is defined in `lib/` or `devdocs/`. Upload implementation
remains optional and blocked until the server contract is confirmed. The
authenticated multipart path is available through `ApiClient.uploadFile`, which
applies the existing auth bearer token and mobile client header.

Implementation:
- Check Endurain server docs or backend code for the activity upload endpoint.
- Confirm multipart field name, supported file extension, required headers, and
  expected response status codes.
- Record unresolved API details in this document before coding upload behavior.

Security and reliability checks:
- Confirm uploads use the existing authenticated `ApiClient` path.
- Confirm the app does not need to send credentials outside existing auth
  headers.
- Confirm server errors can be shown without exposing raw token or URL details.

Acceptance checks:
- Endpoint, field name, and expected responses are known, or upload remains
  explicitly marked as blocked.
- No mobile code changes are made in this phase unless they are documentation
  only.

## Phase 2: Add Activity Feature Skeleton

Timebox: 15 minutes.

Status: Completed. `lib/features/activity/` exists with `models/`,
`services/`, `controllers/`, `widgets/`, and a placeholder `repositories/`.

Implementation:
- Create `lib/features/activity/` with `models/`, `services/`, `repositories/`,
  `controllers/`, and `widgets/` subfolders as they become needed.
- Add placeholder files only where needed for the next phase.
- Keep all classes unexported until they are used.

Security and reliability checks:
- Avoid adding dependencies.
- Keep the feature independent from auth and map UI until contracts are clear.

Acceptance checks:
- The project still analyzes cleanly.
- No user-facing strings are introduced.

## Phase 3: Add Track Point Model

Timebox: 15 minutes.

Status: Completed. `ActivityTrackPoint` with `fromPosition` factory and tests.

Implementation:
- Add an immutable `ActivityTrackPoint` model with latitude, longitude,
  elevation, speed, heading, accuracy, and timestamp fields where available.
- Add a factory that converts from `geolocator` `Position`.
- Keep serialization out of this model for now unless directly needed.

Security and reliability checks:
- Do not implement `toString` with raw coordinates.
- Use `final` fields and `const` constructors where possible.
- Validate nullable GPS attributes rather than forcing default values that could
  corrupt stats.

Acceptance checks:
- Unit tests cover conversion from representative `Position` data.
- Null optional fields are handled safely.

## Phase 4: Add Activity Recording State Model

Timebox: 15 minutes.

Status: Completed. `ActivityRecordingState` with status enum, `copyWith`, tests.

Implementation:
- Add an immutable `ActivityRecordingState` model.
- Include status values for idle, recording, paused, stopping, completed, and
  failed.
- Store activity type, started timestamp, ended timestamp, points, and last
  error key/message reference.

Security and reliability checks:
- Keep raw exception details out of user-facing state.
- Avoid mutable lists escaping the state object.

Acceptance checks:
- State copy/update behavior is covered by unit tests.
- Empty point lists and completed-without-points cases are valid states.

## Phase 5: Add Stats Calculation Helper

Timebox: 15 minutes.

Status: Completed. `ActivityStatsCalculator` (latlong2) with tests.

Implementation:
- Add a pure helper for distance, duration, average speed, and current speed.
- Use `latlong2` distance calculations rather than custom trigonometry.
- Ignore invalid point pairs with missing timestamps where duration is required.

Security and reliability checks:
- Never log coordinates while calculating stats.
- Guard against divide-by-zero and negative duration.
- Keep units explicit in names, such as meters and seconds.

Acceptance checks:
- Unit tests cover zero points, one point, multiple points, duplicate points,
  and non-monotonic timestamps.
- Calculations are deterministic and independent of Flutter widgets.

## Phase 6: Add Recording Service Contract

Timebox: 15 minutes.

Status: Completed. `ActivityRecordingService` with start/pause/resume/stop/
discard and a broadcast state stream, plus tests.

Implementation:
- Add `ActivityRecordingService` with start, pause, resume, stop, discard, and
  state stream APIs.
- Do not connect it to location yet.
- Keep the constructor injectable so tests can provide fake dependencies.
- Keep UI-facing orchestration in a later `ActivityRecordingController` rather
  than letting widgets coordinate service lifecycle directly.

Security and reliability checks:
- Define lifecycle behavior for duplicate start/stop calls.
- Ensure discard clears all in-memory points.

Acceptance checks:
- Tests cover invalid transitions and idempotent discard.
- Public API remains small and easy to reason about.

## Phase 7: Connect Recording To Location Stream

Timebox: 15 minutes.

Status: Completed. Service subscribes to `LocationService.getPositionStream()`
while recording and cancels on stop/discard/failure, with fake-stream tests.

Implementation:
- Subscribe to `LocationService.getPositionStream()` only while recording.
- Convert each `Position` to an `ActivityTrackPoint`.
- Cancel the subscription on stop, discard, failure, and service dispose.

Security and reliability checks:
- Do not keep collecting points while paused.
- Handle permission loss or stream errors gracefully.
- Avoid duplicate subscriptions after rapid start/stop taps.

Acceptance checks:
- Tests with a fake stream prove subscription starts and cancels correctly.
- Recording state updates when stream errors occur.

## Phase 8: Add Activity Type Constants

Timebox: 15 minutes.

Status: Completed. `ActivityType` enum (run/ride/walk/hike/other) with
`apiValue`, localized labels, and EN/PT ARB entries.

Implementation:
- Define supported MVP activity types: run, ride, walk, hike, and other.
- Keep API values separate from localized display labels.
- Add localization keys for labels in English and Portuguese.

Security and reliability checks:
- Avoid accepting arbitrary activity type strings from UI.
- Keep unknown/future server values mapped safely to other.

Acceptance checks:
- Generated l10n files compile.
- Tests or simple assertions cover API value mapping.

## Phase 9: Add Recording Control Widget

Timebox: 15 minutes.

Status: Completed. `ActivityRecordingControls` overlay with adaptive,
state-driven controls and tests.

Implementation:
- Add a compact map overlay widget for start, pause/resume, and stop actions.
- Use Material controls on Android and Cupertino controls on Apple platforms if
  consistent with existing map UI.
- Keep the widget stateless where possible and drive it from recording state.

Security and reliability checks:
- Disable unsafe actions during stopping/uploading.
- Use localized button labels/tooltips.
- Ensure controls are reachable and do not overlap existing map buttons.

Acceptance checks:
- Widget test verifies visible actions for idle, recording, paused, and stopping
  states.
- Text fits on small screens.

## Phase 10: Add Activity Type Picker

Timebox: 15 minutes.

Status: Completed. `ActivityTypePicker` with a Material dropdown on Android and
a Cupertino action sheet on Apple platforms.

Implementation:
- Add a small type picker before starting recording.
- Default to the last selected type only if it is stored safely and not required
  for the MVP.
- Keep the picker accessible from the recording control widget.

Security and reliability checks:
- Store only non-sensitive preferences if persistence is added.
- Validate selected type before starting.

Acceptance checks:
- Picker uses localized labels.
- Invalid or missing selection cannot start an inconsistent recording.

## Phase 11: Integrate Controls Into Map Screen

Timebox: 15 minutes.

Status: Completed. `MapScreen` owns and disposes `ActivityRecordingController`
and renders the recording overlay above the map.

Implementation:
- Instantiate an `ActivityRecordingController` from `MapScreen` using
  dependencies resolved through `AppScope.servicesOf(context, listen: false)` or
  constructor injection for tests.
- Render the recording control overlay above the map.
- Keep existing location lock behavior unchanged.

Security and reliability checks:
- Dispose the recording controller and all owned subscriptions from
  `MapScreen.dispose`.
- Avoid starting recording automatically when the map opens.
- Avoid logging position updates.

Acceptance checks:
- Existing map behavior still works.
- The app analyzes cleanly.

## Phase 12: Add Live Stats Display

Timebox: 15 minutes.

Status: Completed. `ActivityStatsDisplay` with `ActivityStatsFormatter` and
tests for empty and populated stats.

Implementation:
- Display elapsed duration, distance, and current or average pace/speed while
  recording.
- Reuse the pure stats helper.
- Keep formatting logic separate from calculation logic.

Security and reliability checks:
- Handle missing speed values without showing misleading data.
- Avoid showing stale stats after discard.

Acceptance checks:
- Widget tests cover empty and populated stats.
- Formatting is localized where necessary.

## Phase 13: Add Stop Confirmation

Timebox: 15 minutes.

Status: Completed. `showActivityStopConfirmationDialog` (adaptive) returning
`ActivityStopAction` with cancel/stop/discard, plus tests.

Implementation:
- Show a platform-adaptive confirmation before ending an activity.
- Include stop and discard paths.
- Keep dialog text localized.

Security and reliability checks:
- Avoid accidental data loss by confirming discard separately if needed.
- Ensure dialog cannot trigger duplicate stop operations.

Acceptance checks:
- Widget test covers cancel, stop, and discard actions.
- State remains recording when cancel is selected.

## Phase 14: Add GPX Builder

Timebox: 15 minutes.

Status: Completed. `ActivityGpxBuilder` produces escaped GPX 1.1 XML with
timestamps and elevation, covered by tests.

Implementation:
- Add a pure GPX builder that converts a completed recording to GPX XML.
- Include timestamps and elevation when available.
- Escape XML values through a structured XML approach or safe escaping helper.

Security and reliability checks:
- Do not include tokens, server URLs, or device identifiers in GPX metadata.
- Validate that generated XML is well formed.
- Avoid hand-concatenating unescaped user-controlled values.

Acceptance checks:
- Unit tests cover valid points, missing elevation, empty tracks, and XML
  escaping.
- Output imports into a basic GPX validator or parser if available.

## Phase 15: Add Temporary GPX File Writer

Timebox: 15 minutes.

Status: Completed. `ActivityGpxFileWriter` writes to the temp directory with a
unique prefix/suffix and provides a delete path, plus tests.

Implementation:
- Write generated GPX to the app temporary directory only when upload/export is
  requested.
- Use a deterministic temporary file prefix and unique suffix.
- Return the path to the caller without exposing it in user-facing errors.

Security and reliability checks:
- Delete temporary files after successful upload or explicit discard.
- Avoid storing GPX in shared public storage for the MVP.
- Handle file write failures with localized errors.

Acceptance checks:
- Unit or integration test verifies file creation and cleanup path where
  practical.
- No coordinates are printed to logs during failures.

## Phase 16: Add Upload Service Contract

Timebox: 15 minutes.

Status: Completed (pending server endpoint). `ActivityUploadService` uses
`ApiClient.uploadFile`; the endpoint/field name are config-driven and the
service stays blocked via `AppException` until configured. The endpoint is not
yet hardcoded in `ApiConstants` because the server contract is unconfirmed.

Implementation:
- Add `ActivityUploadService` or an activity repository method that accepts a GPX
  file path and activity metadata.
- Use `ApiClient.uploadFile` for authenticated multipart upload.
- Keep endpoint and multipart field in `ApiConstants` once confirmed.

Security and reliability checks:
- Never pass tokens manually outside `ApiClient`.
- Treat 401 through existing refresh behavior where available.
- Normalize user-visible errors and avoid exposing raw server responses.

Acceptance checks:
- Tests use a fake API client or injectable upload function.
- Upload service handles success, auth failure, validation failure, and network
  failure paths.

## Phase 17: Wire Completion To GPX Generation

Timebox: 15 minutes.

Status: Completed. The controller builds a completed recording and generates
GPX on stop while keeping upload optional, with tests.

Implementation:
- On stop, build a completed recording object.
- Generate GPX from the completed recording.
- Keep upload optional until the endpoint is confirmed.

Security and reliability checks:
- Do not generate a GPX file for discarded recordings.
- Ensure completed state cannot continue accepting GPS points.

Acceptance checks:
- Stop path produces a completed state and GPX content for valid recordings.
- Empty recordings show a safe localized error or discard path.

## Phase 18: Add Upload UI State

Timebox: 15 minutes.

Status: Completed. `ActivityUploadStatusPanel` shows uploading/uploaded/failed
with retry and discard actions, plus tests.

Implementation:
- Show uploading, uploaded, and upload failed states after recording stops.
- Provide retry and discard actions.
- Keep the user on the map for the MVP.

Security and reliability checks:
- Disable retry while an upload is already running.
- Delete temporary GPX only after confirmed upload or discard.
- Do not show raw file paths in errors.

Acceptance checks:
- Widget tests cover uploading, success, failure, retry, and discard.
- UI remains usable after network failure.

## Phase 19: Add Permission And Service Error UX

Timebox: 15 minutes.

Status: Completed. Permission denied, denied-forever (open settings), service
disabled, and stream failure states are surfaced via localized error UX.

Implementation:
- Surface location permission denied, denied forever, and service disabled states
  before recording starts.
- Reuse existing `LocationService.openAppSettings()` for denied forever flows.
- Localize all messages and actions.

Security and reliability checks:
- Do not request permissions repeatedly in a loop.
- Keep the user in control of opening settings.

Acceptance checks:
- Widget or service tests cover permission result handling.
- Recording cannot start without a valid location stream.

## Phase 20: Add Localization Pass

Timebox: 15 minutes.

Status: Completed. All new activity strings have EN and PT ARB entries and
`flutter analyze` reports no l10n issues.

Implementation:
- Review all new user-facing strings.
- Add or adjust English and Portuguese ARB entries in the correct feature
  section.
- Run `flutter gen-l10n`.

Security and reliability checks:
- Avoid including technical secrets, paths, or raw exceptions in localized
  messages.
- Keep descriptions clear with usage context.

Acceptance checks:
- Generated localization files are updated.
- `flutter analyze` reports no l10n issues.

## Phase 21: Add Unit Test Pass

Timebox: 15 minutes.

Status: Completed. Unit tests cover models, stats, state transitions, GPX
generation, and upload error mapping.

Implementation:
- Add focused tests for models, stats, state transitions, GPX generation, and
  upload error mapping.
- Prefer fakes over real GPS, storage, or network.

Security and reliability checks:
- Do not store real location samples from users in tests.
- Use synthetic coordinates and timestamps.

Acceptance checks:
- Relevant tests pass with `flutter test`.
- Coverage exists for the highest-risk logic.

## Phase 22: Add Widget Test Pass

Timebox: 15 minutes.

Status: Completed. Widget tests cover recording controls, stats display, stop
confirmation, and upload states, including a Cupertino-shell regression test.

Implementation:
- Add widget tests for recording controls, type picker, stop confirmation, and
  upload states.
- Mock localization and platform behavior according to existing test patterns.

Security and reliability checks:
- Verify destructive actions require explicit user choice.
- Verify disabled states prevent duplicate actions.

Acceptance checks:
- Widget tests pass consistently.
- Tests do not require real platform permissions.

## Phase 23: Manual Android Review

Timebox: 15 minutes.

Status: Blocked locally on 2026-05-30. `flutter devices` reported macOS and an
iPhone only, and `flutter emulators` reported no emulator sources. Android
manual review remains a follow-up when an Android device or AVD is available.

Implementation:
- Run the app on Android or an emulator.
- Start, pause, resume, stop, discard, and retry upload if available.
- Check map controls and recording controls do not overlap.

Security and reliability checks:
- Confirm permission prompts are understandable.
- Confirm no coordinates, tokens, or GPX content appear in console logs.

Acceptance checks:
- Main recording flow works on Android.
- Any platform issue is captured as a follow-up item.

## Phase 24: Manual Apple Platform Review

Timebox: 15 minutes.

Status: Partially completed locally on 2026-05-30. `flutter build macos --debug`
succeeded and produced `build/macos/Build/Products/Debug/endurain.app`. Manual
GUI interaction for start, pause, resume, stop, discard, and upload retry still
needs a human pass on macOS or iOS.

Implementation:
- Run on iOS or macOS depending on available local tooling.
- Review Cupertino layout, dialogs, and map overlay spacing.
- Confirm compass/map behavior remains stable.

Security and reliability checks:
- Confirm location permission copy and settings behavior are platform suitable.
- Confirm no sensitive data is logged.

Acceptance checks:
- Main recording flow works on the reviewed Apple platform.
- Unsupported platform gaps are documented.

## Phase 25: Final Quality Gate

Timebox: 15 minutes.

Status: Completed. `dart format`, `flutter analyze` (no issues), and the
activity test suite pass; the diff remains scoped to activity tracking.

Implementation:
- Run `dart format .`.
- Run `flutter analyze`.
- Run `flutter test`.
- Review `git diff` for accidental unrelated changes.

Security and reliability checks:
- Search for accidental coordinate logs, token logs, raw exception display, and
  hardcoded strings.
- Confirm temporary GPX cleanup is covered.
- Confirm upload endpoint constants are not secrets.

Acceptance checks:
- Formatting, analysis, and tests pass, or failures are documented with clear
  follow-up items.
- Diff is scoped to activity tracking and required localization/test updates.

## Backlog After MVP

- Background tracking with platform-specific permission and battery review.
- Persistent in-progress activity recovery after app restart.
- Activity history and details screen.
- Manual GPX export/share action.
- Elevation smoothing and advanced pace metrics.
- Offline upload queue with retry policy.
- Privacy setting to control local retention of completed GPX files.