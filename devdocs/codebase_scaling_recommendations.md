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

### 1. Introduce dependency injection and service composition - Done

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

### 2. Move auth workflow state out of `LoginScreen` - Done

`LoginScreen` still owns controllers, SSO callback listening, server settings
fetching, MFA state, provider loading, local-login state, loading state, and UI
rendering. The adaptive UI layer reduced platform duplication, but the workflow
is still tightly coupled to the widget.

Recommended changes:

- Create an `AuthController` or `LoginController` under `features/auth/`.
- Move login step state, MFA state, provider loading, and SSO callback handling
  into that controller.
- Keep `LoginScreen` focused on rendering and forwarding user intents.

### 3. Create repository and API domain boundaries - Partially done

Services currently mix HTTP transport, JSON parsing, token handling, storage, and
feature behavior. `AuthService` is the clearest example: it performs auth HTTP
calls, manages PKCE lifecycle, persists tokens, and builds auth results.

Recommended changes:

- Keep `ApiClient` responsible for HTTP, headers, auth retry, and response
  handling.
- Add feature repositories such as `AuthRepository`, `ServerSettingsRepository`,
  and `MapSettingsRepository`.
- Repositories should return typed models or results, not raw `http.Response`.

### 4. Standardize API response parsing and failures - Done

JSON decoding and `error['detail']` handling are repeated in auth, SSO, and
server settings services. As API coverage grows, that repetition will make error
handling inconsistent.

Recommended changes:

- Add an API response helper that safely decodes JSON.
- Centralize server error detail extraction.
- Map status codes and backend error codes to `AppException` / `AppErrorCode`.
- Prefer backend error codes over backend human text when the server supports it.

## Medium Priority

### 5. Strengthen models and parsing - Done

`ServerSettings` and `IdentityProvider` manually parse JSON. This is fine at the
current size, but fragile as API payloads grow.

Recommended changes:

- Add focused unit tests for every `fromJson` and `toJson` contract.
- Consider `json_serializable` later if model count or complexity grows.
- Avoid silently defaulting fields that are required by the backend contract.

### 6. Expand test coverage beyond the smoke test - Partially done

The current test suite is mostly a single widget smoke test. That is not enough
for rapid SaaS iteration.

Recommended test layers:

- Unit tests for validators, models, PKCE, storage wrappers, and error
  localization.
- Service and repository tests with mocked HTTP clients.
- Widget tests for adaptive screens in both platform modes where practical.
- Auth flow tests for server URL entry, local login, SSO provider loading, and
  MFA.

### 7. Make platform and device services mockable - Partially done

`LocationService` calls `Geolocator` statically, and `SecureStorageService` wraps
a static `FlutterSecureStorage`. That makes permission flows, storage behavior,
and device behavior harder to test.

Recommended changes:

- Introduce thin injectable adapters for storage, location, app links, URL
  launching, and HTTP.
- Keep platform plugin calls behind those adapters.
- Use fakes or mocks in unit and widget tests.

### 8. Separate map state from map rendering - Done

`MapScreen` owns location loading, compass stream handling, position stream
handling, tile settings, location lock state, map movement, and rendering.

Recommended changes:

- Add a map controller/view-model for location, tile, and lock state.
- Keep `MapScreen` focused on rendering the map and controls.
- Do this before adding activity tracking, route overlays, offline tiles, or map
  recording.

## Lower Priority, But Worth Planning

### 9. Introduce route organization before navigation grows - Done

The current `adaptivePush` helper is enough for simple navigation. Once the app
has auth subflows, activities, profile, account, billing, uploads, and nested
settings screens, route definitions should become centralized.

Recommended changes:

- Add `app_routes.dart` or a lightweight route registry.
- Consider a router package only when deep links and nested navigation become
  complex enough to justify it.

### 10. Improve theme and token structure - Done

`AppTheme` is minimal. Material 3 is enabled, but component themes are not yet
formalized.

Recommended changes:

- Add Material 3 component themes as Android UI grows.
- Keep Apple platforms on Cupertino defaults unless Flutter exposes native
  Cupertino configuration knobs.
- Keep design tokens in theme/constants, not scattered through feature screens.

### 11. Remove unused or risky secure storage methods - Done

`SecureStorageService` includes password storage helpers. If passwords are not
intentionally persisted, those methods should be removed to reduce future misuse.

Recommended changes:

- Confirm whether password persistence is required.
- Remove `getPassword`, `setPassword`, and `deletePassword` if unused.
- Keep sensitive storage limited to tokens and explicitly required settings.

### 12. Add a feature creation guide - Done

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

Remaining recommendations from the fresh codebase review are now tracked as
steps 13 onward below, while still keeping the original steps above as the
historical scaling checklist.

## Next Steps From Current Review

### 13. Promote `ApiClient` to typed response helpers - Done

`ApiClient` still returns raw `http.Response` and `http.StreamedResponse` from
its public methods. That leaves future features free to duplicate status-code
checks, JSON decoding, backend error detail extraction, and upload handling.

Recommended changes:

- Add typed helpers such as `getJsonObject`, `postJsonObject`, `putJsonObject`,
  and `deleteJsonObject` that return decoded data or throw `AppException`.
- Keep raw response escape hatches private or narrowly scoped for cases that
  truly need streaming or binary data.
- Ensure feature repositories consume typed data and return typed models or
  results, not transport responses.

### 14. Add thin adapters around remaining platform plugins

Some platform APIs still sit directly in services or screens: `Geolocator` in
`LocationService`, `AppLinks` in `LoginController`, `launchUrl` in
`LoginScreen`, and `PackageInfo.fromPlatform` in `SettingsScreen`. This is
manageable now, but it will make activity tracking, deep links, package metadata,
and browser-launch flows harder to unit test.

Recommended changes:

- Add injectable adapters for geolocation, app links, URL launching, package
  info, and multipart upload when those flows need direct tests.
- Keep plugin calls in adapter classes and pass those adapters into controllers,
  services, or repositories.
- Use fake adapters in controller and widget tests.

### 15. Extract shared auth session persistence

Token and session writes are duplicated between local login, SSO token exchange,
and refresh flows. This increases the chance that future expiry, logout,
multi-account, or refresh changes drift between auth paths.

Recommended changes:

- Add a small `TokenStore`, `SessionStore`, or `AuthSessionRepository` around
  access token, refresh token, session ID, username, and expiry persistence.
- Reuse the same persistence path for login, MFA exchange, SSO exchange, token
  refresh, authentication checks, and logout.
- Add tests for expiry thresholds, refresh persistence, and token clearing.

### 16. Add focused controller and adaptive UI tests

The current tests cover core service, parser, model, and validator contracts.
The next risk is behavior that now lives in feature controllers and adaptive
screen composition.

Recommended changes:

- Add `LoginController` tests for server URL submission, local login, MFA, SSO
  provider loading, SSO callback success, and SSO callback failure.
- Add `MapStateController` tests for location permission states, position
  updates, heading updates, tile URL loading, and lock/unlock behavior.
- Add widget tests for key adaptive screens in Material and Cupertino modes
  where practical.

### 17. Introduce an app-level session and dependency scope when navigation grows

`AppServices` is a useful lightweight composition root, but several screens
still fall back to `AppServices.instance` internally and `App` owns only a small
local authenticated flag. This is fine at the current size, but auth state,
refresh state, onboarding, account screens, and deep links will need one clearer
owner.

Recommended changes:

- Add an `AuthSessionController` or app-level state object before adding larger
  authenticated feature areas.
- Consider an inherited dependency scope so screens receive services from the app
  boundary instead of pulling directly from the singleton.
- Keep the current lightweight approach until routing, deep links, or account
  workflows make this extra structure worthwhile.

## Guiding Principle

Feature screens should describe user workflows. Shared adaptive widgets should
handle native platform rendering. Repositories should coordinate feature data.
Services and adapters should isolate platform, HTTP, and storage details. Tests
should cover the contracts between those layers before the app grows too quickly
to refactor safely.
