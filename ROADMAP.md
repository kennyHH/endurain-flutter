# Endurain Mobile Support Backlog

This file is intentionally lightweight and support-oriented.
For permanent release history, use `CHANGELOG.md` as the single long-term source.

## Current Support Priorities

1. **GPS quality in dense urban areas**
   - Validate `Auto by activity` behavior on real devices.
   - Collect edge cases where strict filtering drops too many valid points.

2. **App vs server metric alignment**
   - Re-check duration/elevation/speed consistency after upload on longer sessions.
   - Track reproducible mismatch examples with GPX and screenshots.

3. **Upload robustness**
   - Continue monitoring 4xx/5xx fallback behavior on self-hosted server variants.
   - Keep error feedback concise and actionable.

4. **Deletion consistency**
   - Verify local + remote deletion flow across endpoint variants.
   - Confirm behavior when server delete is unavailable.

## Next Support Improvements (Small, Low Risk)

- Add one troubleshooting section in app/docs for GPS quality expectations in cities.
- Add a short QA checklist for every support release (track/save/upload/delete/regression).
- Add one integration test for GPS filter mode persistence and live mode switching.

## Done Recently

- Added `GPS filter mode` (`Auto by activity`, `Normal`, `Strict`) with persistent setting and live engine updates.
- Kept server API compatibility unchanged for upload/auth contracts.
- Added maintainer handover note for review and merge clarity.
