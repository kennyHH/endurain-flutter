# Release Handover Playbook

Reusable workflow for preparing and handing over Endurain mobile changes to the repository maintainer.

## Goals

- Keep contributions reviewable and aligned with `CONTRIBUTING.md`.
- Provide maintainers with clear technical context and test evidence.
- Ship testable APK artifacts with traceable version naming.

## 1) Split work into focused PRs

Avoid one large mixed PR. Prefer small and coherent changesets:

- PR 1: Tracking flow (pause/resume, stop/save/upload, history refresh/retry)
- PR 2: Pace + elevation metrics (model, engine, UI, GPX, tests)
- PR 3: Branding/icons + settings version/build info + docs

## 2) Branch strategy

- Create one feature branch per PR topic.
- Keep each branch rebased or freshly branched from current `main`.
- Use descriptive branch names, for example:
  - `feature/tracking-upload-stabilization`
  - `feature/pace-elevation-metrics`
  - `feature/branding-version-surface`

## 3) Testing and quality gates

Before opening each PR:

1. Run full test suite:
   - `flutter test`
2. Verify no new lint issues in changed files.
3. Validate core behavior manually on Android phone (and iOS/macOS if possible).

Include test output summary in the PR description.

## 4) APK artifact naming and build metadata

Use stable and traceable naming:

- `endurain-<version>-arm64-debug-<shortsha>.apk`

Recommended build command pattern:

1. Inject build metadata:
   - `ENDURAIN_BUILD_DATE`
   - `ENDURAIN_GIT_SHA`
2. Build:
   - `flutter build apk --debug --target-platform android-arm64 --dart-define=ENDURAIN_BUILD_DATE=... --dart-define=ENDURAIN_GIT_SHA=...`
3. Copy output to versioned filename.

## 5) PR template (English)

Use this structure for each PR:

- **Summary**
  - 1-3 bullets on what changed and why.
- **Scope**
  - Explicitly list included and excluded areas.
- **Test Plan**
  - `flutter test` result
  - Manual checks performed
- **Risk / Rollback**
  - Main risks and how to back out safely
- **Artifacts**
  - APK filename and location or release link

## 6) Maintainer handover checklist

- [ ] PR links grouped by theme
- [ ] Test evidence attached
- [ ] APK artifact shared
- [ ] Known limitations listed
- [ ] Follow-up issues opened for remaining work

## 7) Suggested issue/PR labels

- `feature`
- `mobile`
- `tracking`
- `ux`
- `documentation`
- `needs-review`

## 8) Notes

- Prefer incremental delivery over one-shot large merges.
- Keep commit messages descriptive and purpose-driven.
- If major product behavior changes, open/discuss an issue before implementation.
