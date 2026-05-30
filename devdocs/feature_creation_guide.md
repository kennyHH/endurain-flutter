# Feature Creation Guide

Use this guide when adding a new Endurain mobile feature. The goal is to keep
feature work fast while preserving clear ownership boundaries, localization,
adaptive UI behavior, and testable contracts.

## 1. Choose the Feature Boundary

Create new feature code under `lib/features/<feature_name>/` using snake_case
file names.

Recommended structure:

```text
lib/features/<feature_name>/
├── <feature_name>_screen.dart
├── <feature_name>_controller.dart
├── <feature_name>_repository.dart
└── widgets/
```

Keep feature screens responsible for rendering and forwarding user intent. Put
workflow state, loading state, stream subscriptions, and async orchestration in a
controller. Put feature data coordination in a repository.

## 2. Use Existing App Services

Start dependency wiring from `AppServices` or from constructor injection on the
screen/controller being added. Prefer passing dependencies into constructors over
creating service instances inside methods.

Use these ownership rules:

- Controllers own UI workflow state and plugin stream lifecycles.
- Repositories coordinate feature behavior and return typed models or results.
- Services isolate HTTP, storage, and platform APIs.
- Shared adaptive widgets handle native Material and Cupertino rendering.

Avoid adding a new global singleton unless the dependency is genuinely shared
application infrastructure.

## 3. Add Localized Strings

Never hardcode user-facing strings in widgets, dialogs, validators, snack bars,
or button labels.

When adding a string:

1. Add the key to `lib/l10n/app_en.arb` in the matching feature section.
2. Add the Portuguese translation to `lib/l10n/app_pt.arb`.
3. Include a description with usage context, for example
   `Used in: activity_screen.dart`.
4. Run `flutter gen-l10n` if generated localization files need refreshing.
5. Use `final l10n = AppLocalizations.of(context)!;` in widgets.

## 4. Build Adaptive UI First

Use shared adaptive widgets from `lib/shared/adaptive/` before adding platform
branches in a feature screen.

Prefer these primitives:

- `AdaptiveScaffold` for screens.
- `AdaptiveButton` for actions.
- `AdaptiveTextFormField` for forms.
- `AdaptiveListSection` and `AdaptiveListTile` for settings-style lists.
- `AdaptiveLoadingIndicator` for loading states.
- `adaptivePush` for simple navigation.

Use Material and Cupertino icons through `AdaptiveIcon` or adaptive widget
parameters where possible.

## 5. Add API and Model Contracts

For backend-backed features:

- Add typed models under `lib/core/models/` only when shared across features.
- Keep feature-specific models inside the feature folder if they are not shared.
- Parse JSON through shared API helpers and return typed models from
  repositories.
- Map failures to `AppException` and `AppErrorCode` before they reach widgets.
- Keep authenticated feature calls behind `ApiClient` so token refresh and
  standard headers stay centralized.

Avoid passing raw `http.Response` objects into screens or controllers.

## 6. Make Platform Calls Testable

Put platform/plugin calls behind services or thin adapters before they appear in
controllers or screens. This applies to location, app links, URL launching,
package info, file picking, uploads, camera, notifications, and secure storage.

Inject fakes in tests instead of relying on live platform channels.

## 7. Add Focused Tests

Add tests near the layer where behavior lives:

- Model tests for `fromJson` and `toJson` contracts.
- Repository/service tests with mocked HTTP clients or fake adapters.
- Controller tests for workflow state, loading state, error paths, and stream
  cleanup.
- Widget tests for important screen states and adaptive rendering where
  practical.
- Validator and localization/error-message tests when user input or failures are
  involved.

Before finishing a feature, run:

```sh
flutter analyze
flutter test
```

## 8. Update Documentation When the Pattern Changes

If a feature introduces a new architecture pattern, platform adapter, route
pattern, or test helper, update this guide or the relevant `devdocs/` rationale
file in the same change.
