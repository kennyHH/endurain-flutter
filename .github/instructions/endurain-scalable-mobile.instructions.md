---
description: "Use when changing Endurain Flutter features, architecture, adaptive UI, localization, tests, platform integrations, security, release configuration, or mobile best practices. Preserves the scaling rationale from the refactors."
name: "Endurain Scalable Mobile Guidelines"
applyTo: "lib/**, test/**, android/**, ios/**, macos/**, devdocs/**, pubspec.yaml, l10n.yaml, analysis_options.yaml"
---
# Endurain Scalable Mobile Guidelines

Keep new work aligned with the current scaling rationale in `devdocs/`:

- `devdocs/l10n_i18n_scaling_rationale.md`
- `devdocs/adaptive_ui_scaling_rationale.md`
- `devdocs/codebase_scaling_recommendations.md`
- `devdocs/feature_creation_guide.md`

## Architecture

- Keep feature code under `lib/features/<feature_name>/`.
- Screens render UI and forward user intent; they should not own complex workflow orchestration.
- Controllers own workflow state, loading state, stream lifecycles, and async transitions.
- Repositories coordinate feature data and return typed models or typed results.
- Services isolate HTTP, secure storage, auth/session behavior, and platform APIs.
- Wire shared dependencies through `AppServices`, `AppScope`, and constructor injection instead of creating new service instances inside widgets.
- Add abstractions only when they remove real duplication or protect a boundary that is already repeated.

## API, Auth, And Security

- Use typed `ApiClient` helpers and `ApiResponse` parsing instead of passing raw HTTP responses into features.
- Map failures to `AppException` and `AppErrorCode`; localize user-facing errors at the UI boundary.
- Keep token/session persistence centralized through the auth session store path.
- On refresh failure, clear the auth session consistently.
- Never store raw passwords or secrets in the repo.
- Keep Android signing secrets in ignored `android/key.properties` or CI environment variables.
- Preserve F-Droid compatibility: do not add Firebase, Google Maps, Google Play Services, or proprietary SDK dependencies.

## Localization

- Never hardcode user-facing strings in widgets, dialogs, validators, snack bars, errors, or button labels.
- Add English and Portuguese ARB entries together.
- Include ARB metadata descriptions with usage context such as `Used in: activity_screen.dart`.
- Keep service-layer errors language-free and map them to localized text near the UI.
- Run `flutter gen-l10n` after ARB changes when generated files need refreshing.

## Adaptive UI

- Use shared adaptive primitives from `lib/shared/adaptive/` before adding platform branches.
- Android should render through Flutter Material or Material 3 widgets.
- iOS and macOS should render through Flutter Cupertino widgets where supported.
- Do not hand-roll platform visual effects, custom glass/blur surfaces, or platform-lookalike widgets when native Flutter families do not expose that behavior.
- Add a new adaptive primitive only when the pattern repeats across features.

## Platform And Mobile Best Practices

- Put plugin calls behind injectable adapters before they appear in controllers or screens.
- Handle permissions, denial states, unavailable services, and platform exceptions gracefully.
- Keep permission declarations aligned with actual behavior. Do not request or describe background location until background activity tracking exists.
- Keep release identifiers production-looking and consistent across Android, iOS, and macOS.
- Do not sign Android release builds with debug keys.

## Testing And Validation

- Add tests at the layer where behavior lives: model parsing, repository/service contracts, controller state transitions, and important widget states.
- Use fake adapters instead of live platform channels in unit and controller tests.
- For new features, include focused tests for success, failure, loading, and cleanup paths.
- Before finishing meaningful changes, run `flutter analyze` and relevant tests.
- Run platform builds when platform config changes and the local SDKs are available.

## Documentation

- Update `devdocs/feature_creation_guide.md` or the relevant rationale doc when introducing a new architecture pattern, adapter, route pattern, release convention, or test helper.
