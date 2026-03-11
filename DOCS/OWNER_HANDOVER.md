# Maintainer Note (Support Handover)

## Scope

This change introduces GPS filter mode controls and keeps backend compatibility intact.

## Included in this support update

- Activity-aware default GPS filtering:
  - Walk/Run -> stricter filtering
  - Ride -> balanced filtering
- Manual override in Settings:
  - `Auto by activity` (recommended)
  - `Normal`
  - `Strict (urban)`
- Persisted mode in storage.
- Live mode application in tracking engine (no app restart required).
- EN/PT localization for new settings labels and descriptions.

## Compatibility statement

No server API contract changes:
- no endpoint changes
- no auth/session changes
- no multipart schema changes
- no GPX schema changes

## Verification

- `flutter analyze` passed (no issues)
- `flutter gen-l10n` passed
- `flutter test` passed
- Manual checks:
  1. GPS mode persists after restart
  2. Tracking/save works in all modes
  3. Upload behavior remains unchanged

## Rollback

If tracking becomes too aggressive in some environments, switch mode to `Normal`.
If required, set default to `Normal` in a small hotfix; server-side rollback is not needed.

## Documentation policy

- `CHANGELOG.md` is the permanent historical source.
- This file is an operational handover note and can be updated/replaced per support cycle.

