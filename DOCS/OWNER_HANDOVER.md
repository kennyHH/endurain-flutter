# Endurain Flutter - Owner Handover Package

This document is the maintainer-facing handover for the current mobile workstream.
It is designed to make review and merge straightforward, with clear scope, risk, and verification evidence.

## 1) Goal

Ship UX and GPS quality improvements without breaking Endurain server compatibility.

Key principle: **No backend API contract changes**.

## 2) What changed (human-readable)

### A. GPS quality and reliability
- Added an activity-aware default GPS filtering behavior:
  - Walk/Run: stricter filtering
  - Ride: balanced filtering
- Added a **manual override** in Settings:
  - Auto by activity (recommended)
  - Normal (less strict)
  - Strict (urban)
- Persisted user choice in secure storage.
- Applied mode changes live to tracking engine without app restart.

### B. Settings UX
- Added a clear explanation text for each GPS filter mode directly in Settings.
- Kept route display control (`Auto / Matched preferred / Raw GPS`) separate from GPS filtering to avoid confusion.

### C. Stability and compatibility
- Upload and sync protocol remains unchanged.
- Existing fallback behavior for upload remains intact.
- Localization added for new settings labels and descriptions.

## 3) Why this is safe for Endurain server

No changes were made to:
- Upload endpoint discovery strategy
- HTTP method fallback behavior
- Multipart field naming behavior
- GPX payload schema
- Authentication/session contract

This work is limited to client-side filtering policy and UI/settings plumbing.

## 4) Verification evidence

### Automated
- `flutter gen-l10n` passes
- `flutter test` passes (full suite)

### Functional sanity checks (manual)
1. Start app, open Settings, change GPS filter mode, restart app -> selection persists.
2. Start tracking in each mode -> recording works and saves activities.
3. Change mode while app is running -> next tracking session uses new mode.
4. Upload saved activity -> upload still succeeds with same server behavior.
5. Delete uploaded/non-uploaded activity -> app/server consistency path unchanged.

## 5) Files touched in this handover scope

- `lib/core/models/gps_filter_mode.dart` (new)
- `lib/core/services/secure_storage_service.dart`
- `lib/core/services/tracking_session_engine.dart`
- `lib/app.dart`
- `lib/shared/widgets/app_bottom_nav.dart`
- `lib/features/map/map_screen.dart`
- `lib/features/settings/settings_screen.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_pt.arb`
- generated localization files under `lib/l10n/`

## 6) Recommended PR strategy for owner review

Split into small PRs if possible:

1. **PR 1 - GPS filter mode + persistence**
   - model, storage key, app wiring, engine mode application
2. **PR 2 - Settings UI + localization**
   - settings pickers, explanatory text, EN/PT strings
3. **PR 3 - Documentation/changelog**
   - changelog entry, roadmap delta, handover doc

If a single PR is preferred, keep sections in the PR body exactly as below.

## 7) PR body template (copy/paste)

```md
## Summary
- Add activity-aware GPS filter defaults (Walk/Run stricter, Ride balanced)
- Add manual GPS filter override in Settings with explanatory text
- Persist mode in secure storage and apply mode changes live to tracking engine

## Why
- Reduce urban GPS drift/teleports while keeping UX simple by default
- Give advanced users a clear, low-friction override for difficult GPS environments

## Server compatibility
- No API contract changes (endpoints/methods/multipart schema/auth unchanged)
- Upload flow remains backward-compatible with existing Endurain server behavior

## Verification
- [x] flutter gen-l10n
- [x] flutter test
- [x] Manual sanity checks for settings persistence and upload continuity

## Risk
- Low: client-side filtering policy + settings UI only
```

## 8) Issue template to notify owner before/with PR

```md
Title: Mobile handover: GPS filter mode (auto + override), docs and validation evidence

Hi @joaovitoriasilva,

I prepared a review-ready mobile handover focused on GPS quality and UX clarity:
- Auto GPS filtering by activity type (Walk/Run stricter, Ride balanced)
- Manual override in Settings with user-facing explanations
- Persistence and live application of the selected mode

Important: no backend API contract was changed; upload compatibility remains intact.

I included:
- clear scope
- verification evidence (tests + manual checks)
- risk notes and review guidance

If you agree, I can open either:
1) one compact PR, or
2) three smaller PRs (core, UI/l10n, docs) for faster review.
```

## 9) Suggested communication path

1. Open issue first with concise context and scope.
2. Open PR linked to issue with explicit "no API contract changes" statement.
3. Request review on mobile code owners/maintainer.
4. Post one follow-up comment after tests/screenshots/artifacts are attached.

## 10) Release artifacts to include

For each test APK shared with maintainer:
- APK filename
- app version/build
- git commit SHA
- build date/time (UTC)
- SHA256 checksum
- short test notes (device + Android version)

Suggested artifact line format:

`endurain-mobile-vX.Y.Z+N.apk | sha: <shortsha> | built: <UTC> | sha256: <checksum> | tested: <device/os>`

## 11) Rollback plan

If unexpected GPS behavior is reported:
1. Set mode to `Normal (less strict)` as immediate mitigation.
2. If needed, ship hotfix defaulting to `Normal` while keeping override available.
3. Keep upload path untouched; no server-side rollback needed for this scope.

