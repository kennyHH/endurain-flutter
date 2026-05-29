# Codebase Scaling Recommendations

## Context

After the l10n/i18n and adaptive UI improvements, the next scaling risks are in
state ownership, dependency construction, API boundaries, testing, and feature
workflow organization. The app is still small, but these areas will become
expensive quickly if Endurain grows into a SaaS-backed mobile client with many
rapidly added features.

## Implementation Status

The first scaling pass has now been implemented in six focused commits, one per
step:

- `0ba913e` - `refactor: add service composition root`
- `4e77968` - `refactor: centralize API response parsing`
- `f88e614` - `refactor: split login workflow state`
- `fcbce0d` - `test: add service and model coverage`
- `4ef99fa` - `refactor: extract map state controller`
- `f5571df` - `refactor: organize routes and theme tokens`

What changed:

- Added `AppServices` as the lightweight composition root for shared service
  instances.
- Added constructor injection to auth, SSO, server settings, API, storage, app,
  login, settings, and map boundaries.
- Added `ApiResponse` to centralize JSON object decoding and backend error
  detail extraction.
- Added `AuthRepository` and `LoginController` so `LoginScreen` delegates server
  URL, MFA, SSO provider, SSO callback, and loading state.
- Added focused tests for API parsing, auth service success/failure flows,
  validators, and model parsing.
- Added `MapStateController` so `MapScreen` focuses on map rendering and map
  camera movement.
- Added route constants and stable tab route keys.
- Added theme tokens used by Material and Cupertino theme configuration.

Validation run after the implementation:

- `flutter analyze` passed with no Dart issues.
- Full test suite passed: 13 tests.
- At the time of that refactor, Flutter reported Swift Package
  Manager/CocoaPods migration warnings for `flutter_compass` and the macOS
  project. `flutter_compass` was later removed in favor of `geolocator` movement
  heading.

## Highest Priority

### 1. Introduce dependency injection and service composition

Services currently instantiate their own dependencies directly. For example,
`ApiClient`, `AuthService`, and `SsoService` create or own storage and HTTP
access internally. This makes testing harder and can create duplicated service
instances.

Recommended changes:

- Add a lightweight service locator or constructor injection pattern.
- Let `AuthService`, `SsoService`, `ApiClient`, and future controllers receive
  dependencies.
- Keep the approach simple for now; avoid a heavy framework until the app needs
  it.

### 2. Move auth workflow state out of `LoginScreen`

`LoginScreen` still owns controllers, SSO callback listening, server settings
fetching, MFA state, provider loading, local-login state, loading state, and UI
rendering. The adaptive UI layer reduced platform duplication, but the workflow
is still tightly coupled to the widget.

Recommended changes:

- Create an `AuthController` or `LoginController` under `features/auth/`.
- Move login step state, MFA state, provider loading, and SSO callback handling
  into that controller.
- Keep `LoginScreen` focused on rendering and forwarding user intents.

### 3. Create repository and API domain boundaries

Services currently mix HTTP transport, JSON parsing, token handling, storage, and
feature behavior. `AuthService` is the clearest example: it performs auth HTTP
calls, manages PKCE lifecycle, persists tokens, and builds auth results.

Recommended changes:

- Keep `ApiClient` responsible for HTTP, headers, auth retry, and response
  handling.
- Add feature repositories such as `AuthRepository`, `ServerSettingsRepository`,
  and `MapSettingsRepository`.
- Repositories should return typed models or results, not raw `http.Response`.

### 4. Standardize API response parsing and failures

JSON decoding and `error['detail']` handling are repeated in auth, SSO, and
server settings services. As API coverage grows, that repetition will make error
handling inconsistent.

Recommended changes:

- Add an API response helper that safely decodes JSON.
- Centralize server error detail extraction.
- Map status codes and backend error codes to `AppException` / `AppErrorCode`.
- Prefer backend error codes over backend human text when the server supports it.

## Medium Priority

### 5. Strengthen models and parsing

`ServerSettings` and `IdentityProvider` manually parse JSON. This is fine at the
current size, but fragile as API payloads grow.

Recommended changes:

- Add focused unit tests for every `fromJson` and `toJson` contract.
- Consider `json_serializable` later if model count or complexity grows.
- Avoid silently defaulting fields that are required by the backend contract.

### 6. Expand test coverage beyond the smoke test

The current test suite is mostly a single widget smoke test. That is not enough
for rapid SaaS iteration.

Recommended test layers:

- Unit tests for validators, models, PKCE, storage wrappers, and error
  localization.
- Service and repository tests with mocked HTTP clients.
- Widget tests for adaptive screens in both platform modes where practical.
- Auth flow tests for server URL entry, local login, SSO provider loading, and
  MFA.

### 7. Make platform and device services mockable

`LocationService` calls `Geolocator` statically, and `SecureStorageService` wraps
a static `FlutterSecureStorage`. That makes permission flows, storage behavior,
and device behavior harder to test.

Recommended changes:

- Introduce thin injectable adapters for storage, location, app links, URL
  launching, and HTTP.
- Keep platform plugin calls behind those adapters.
- Use fakes or mocks in unit and widget tests.

### 8. Separate map state from map rendering

`MapScreen` owns location loading, compass stream handling, position stream
handling, tile settings, location lock state, map movement, and rendering.

Recommended changes:

- Add a map controller/view-model for location, tile, and lock state.
- Keep `MapScreen` focused on rendering the map and controls.
- Do this before adding activity tracking, route overlays, offline tiles, or map
  recording.

## Lower Priority, But Worth Planning

### 9. Introduce route organization before navigation grows

The current `adaptivePush` helper is enough for simple navigation. Once the app
has auth subflows, activities, profile, account, billing, uploads, and nested
settings screens, route definitions should become centralized.

Recommended changes:

- Add `app_routes.dart` or a lightweight route registry.
- Consider a router package only when deep links and nested navigation become
  complex enough to justify it.

### 10. Improve theme and token structure

`AppTheme` is minimal. Material 3 is enabled, but component themes are not yet
formalized.

Recommended changes:

- Add Material 3 component themes as Android UI grows.
- Keep Apple platforms on Cupertino defaults unless Flutter exposes native
  Cupertino configuration knobs.
- Keep design tokens in theme/constants, not scattered through feature screens.

### 11. Remove unused or risky secure storage methods

`SecureStorageService` includes password storage helpers. If passwords are not
intentionally persisted, those methods should be removed to reduce future misuse.

Recommended changes:

- Confirm whether password persistence is required.
- Remove `getPassword`, `setPassword`, and `deletePassword` if unused.
- Keep sensitive storage limited to tokens and explicitly required settings.

### 12. Add a feature creation guide

The project now has useful rationale docs, but a short operational guide would
help future rapid feature work stay consistent.

Recommended contents:

- How to add l10n keys.
- How to use adaptive UI primitives.
- How to split controller, repository, service, and model responsibilities.
- What tests are expected for a new feature.

## Suggested Implementation Order

1. Add dependency injection and mockable adapters. Done.
2. Consolidate API response and error handling. Done.
3. Split auth into controller/repository/service boundaries. Done.
4. Add tests for auth, storage, API parsing, models, and adaptive UI. Partially
   done; core service/model/validator coverage was added, while deeper adaptive
   UI matrix tests remain future work.
5. Extract map state from `MapScreen`. Done.
6. Introduce route organization and richer theme tokens when navigation/UI grows.
   Done as a lightweight foundation.

## Post-Implementation Review

The new structure is materially more scalable than the starting point. The app
now has clearer ownership boundaries:

- `AppServices` owns default dependency composition.
- Feature screens render UI and forward user intent.
- Controllers own workflow state and plugin stream lifecycles.
- Repositories coordinate feature behavior.
- Services isolate HTTP, storage, and platform access.
- Shared adaptive widgets continue to enforce native Material/Cupertino output.

Remaining recommendations from the fresh codebase review:

- Remove `SecureStorageService` password helpers if password persistence is not a
  product requirement. They are currently unused and could invite accidental
  credential storage later.
- Add thinner adapters for `Geolocator`, URL launching, and multipart upload if
  those flows need unit tests. The public services are injectable now, but some
  plugin/static calls still live one layer below them.
- Consider moving all authenticated API feature calls through `ApiClient` as new
  endpoints are added. Auth and public settings still use dedicated services,
  which is fine now, but future authenticated feature modules should avoid
  recreating request/refresh/error handling.
- Add tests for `LoginController`, `MapStateController`, PKCE edge cases,
  storage expiration behavior, localized error messages, and native adaptive UI
  rendering on Apple vs Material platforms.
- Introduce feature creation guidance before adding activity tracking, uploads,
  profile/account settings, or route history screens.

## Guiding Principle

Feature screens should describe user workflows. Shared adaptive widgets should
handle native platform rendering. Repositories should coordinate feature data.
Services and adapters should isolate platform, HTTP, and storage details. Tests
should cover the contracts between those layers before the app grows too quickly
to refactor safely.
