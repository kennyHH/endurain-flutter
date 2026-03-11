# Endurain Mobile Product Roadmap

## 1) Current State Analysis (Codebase Scan)

### Already implemented well
- **Stable tracking foundation:** Start/Pause/Resume/Stop, GPS stream handling, activity persistence, GPX export, and robust upload fallback logic for endpoints/methods.
- **Live tracking UX:** Start countdown, GPS-fix indicator, GPS-loss warning banner, retry upload flow with readable feedback.
- **Map/route UX:** Dual-stroke route line with strong contrast, start/end markers (A/B), tappable detail map with full-screen overview.
- **History:** Grouping (Today/Yesterday/This week/Older), filter/sort, rename, upload-pending state, detail map + elevation profile.
- **Theming:** System/Light/Dark, High Contrast, multiple presets, persistent settings.
- **Route display logic:** Mode-based behavior (Auto/Matched/Raw) instead of a single toggle, with fallback behavior.
- **Quality assurance:** Solid test coverage across core services and key UI flows.

### Maturity level (PM perspective)
- **Technical foundation:** strong for MVP+.
- **UX maturity:** good in core flows, still somewhat inconsistent in emotional feedback, micro-interactions, and state polish.
- **Product maturity:** still behind Strava/Komoot/Garmin in motivation, social, and sensor/offline capabilities.

---

## 2) Benchmark vs Strava / Komoot / Garmin

## Gap analysis by area

| Area | Current Endurain State | Market-Leader Level | Gap |
|---|---|---|---|
| UI/UX feedback | Solid snackbars, loading states, GPS warning, detail cards | Richer micro-feedback (haptics, celebration, progress), fully consistent value formatting | **Medium** |
| Empty/loading states | Basic empty state exists in history | High-quality illustrated states with contextual CTAs | **Medium** |
| Motivation/gamification | Nearly absent | PRs, streaks, badges, weekly goals, visual rewards | **High** |
| Core tracking features | Good base, route matching MVP/fallback, stable uploads | Auto-pause heuristics, sensor integrations (HR/cadence), offline maps | **High** |
| Sharing/community | Not implemented yet | Share cards, feed, kudos/comments, challenges | **Very high** |
| Data quality/insights | Core metrics + pace/speed per activity type | Advanced insights (splits, training load, comparative analytics) | **High** |

---

## 3) Identified Gaps

### UI/UX & feedback
- Inconsistent numeric formatting (pace/speed/units are not always perfectly consistent across all screens).
- Limited haptic/visual feedback at critical moments (start, pause, stop, save, upload success).
- Empty states are functional but not motivating (little "next best action" guidance).
- No explicit skeleton/placeholder handling during async map-matching in list/detail contexts.

### Motivation & gamification
- No personal records (PRs).
- No streak logic (for example, "x active days").
- No reward UI (badge/confetti/progress ring).

### Core features
- No automatic auto-pause behavior yet (manual pause/resume only).
- No BLE sensor support (heart rate strap, cadence, speed sensor).
- No offline maps/caching strategy.
- Map matching is still MVP-level (best effort), not yet productized with confidence/quality telemetry.

### Sharing & community
- No sharing dialog (image card or link export).
- No feed, no social interactions (kudos/comments), no groups/challenges.

---

## 4) Product Roadmap

## NOW (Quick wins)
- Focus on perceived quality improvements without architecture risk.
- Deliver 3-5 small UX upgrades with high impact (see Quick Wins below).

## NEXT (1-2 sprints)
1. **Auto-pause v1**  
   Rule-based heuristics (speed + GPS noise + timeout), with explicit UI label "Auto-paused".
2. **Map-matching productization**  
   Quality indicator ("Matched confidence"), explicit "Matching failed -> Raw" messaging, telemetry for success rates.
3. **Insights v1**  
   Splits (1 km / 1 mi), simple weekly summary, trend cards.
4. **Share card v1**  
   Local rendering of an activity card image (distance, time, route, elevation).

## LATER (Vision / architecture)
1. **BLE sensor layer** (HR/cadence/speed, abstracted device profiles, reconnect strategies).
2. **Offline maps** (tile caching, downloadable regions, storage budget/expiry).
3. **Community layer** (feed, kudos, comments, follow graph, privacy controls).
4. **Gamification engine** (PR detection, streaks, badges, challenges, goal system).

---

## 5) Quick Wins (3-5, < 1 day, low risk, high UX impact)

## Quick Win 1: Haptics at key tracking moments
- **What:** Light haptic feedback on start, pause/resume, stop, upload success/fail.
- **Effort:** 2-4 hours.
- **Risk:** Very low (UI only, no architecture changes).
- **Impact:** Immediate "sports watch" feel.

## Quick Win 2: Unified metric formatting
- **What:** Centralized formatters for pace/speed/distance/duration with consistent output (`05:30 /km`, `27.4 km/h`, `1:05:23`).
- **Effort:** 3-5 hours.
- **Risk:** Low (presentation layer only).
- **Impact:** Strongly improves perceived professionalism across screens.

## Quick Win 3: Better empty states with clear CTAs
- **What:** Upgrade history/map empty states with motivational copy and a primary action ("Start first activity"), optional illustration/icon set.
- **Effort:** 4-6 hours.
- **Risk:** Low.
- **Impact:** Better first-session experience and fewer "dead" screens.

## Quick Win 4: Explicit matching status in UI
- **What:** Small status line "Route: Matched / Raw fallback" in detail and overview maps.
- **Effort:** 2-4 hours.
- **Risk:** Low.
- **Impact:** Reduces confusion and builds trust in data quality.

## Quick Win 5: Mini celebration after successful save
- **What:** Short visual confirmation (for example animated check icon + "Activity saved") after stop/save.
- **Effort:** 3-5 hours.
- **Risk:** Low.
- **Impact:** Improves motivation without backend dependencies.

---

## 6) Prioritized recommendation for next sprint start

1. **Quick Win 2 (standardize formatters)**  
2. **Quick Win 1 (haptics)**  
3. **Quick Win 4 (visible matching status)**  
4. **Quick Win 3 (upgrade empty states)**  
5. **Quick Win 5 (mini celebration)**

This order gives the biggest perceived quality lift quickly with minimal risk.

---

## 7) Delivery Status (2026-03-11)

The following quick wins from this document have already been implemented:

- **Quick Win 1 (Haptics):** Haptic feedback on start/countdown, pause/resume, stop, upload success/fail.
- **Quick Win 2 (Formatter):** Central `MetricFormatter` for pace/speed/duration/distance; consistent display in tracking + history/detail.
- **Quick Win 3 (Empty State CTA):** History empty state includes a clear primary action to start the first activity.
- **Quick Win 4 (Matching Status):** Explicit route status display `matched` / `raw fallback` / `raw GPS` in relevant map views.
- **Quick Win 5 (Mini Celebration):** Visible save feedback immediately after storing an activity.

### Integration safety (server)

- Upload and sync behavior to the Endurain server app was intentionally not changed at protocol/schema/endpoint level.
- This implementation focuses on UI/UX, feedback, and presentation; data transfer remains compatible.

### Refined follow-up (0.0.15)

- Upload matrix for Endurain server was hardened (full exhaustion of field/method/endpoint candidates on 4xx validation responses).
- GPX `<name>` switched to human-readable activity names (`Run/Walk/Ride + date + time`) instead of numeric IDs.
- GPX timeline now clamps start/end timestamps explicitly to reduce metric drift between app and server.
- Upload error messages in the bottom feedback area were normalized to compact, readable detail text.

### Extended follow-up (0.0.16)

- Activities can now be deleted in the app (history + detail, with confirmation).
- For uploaded activities, a server delete attempt is executed before local deletion to improve app/server consistency.
- Very short or implausible sessions now trigger a safety dialog (keep vs discard).
- Redundant setting `Enable route matching` was removed; only `Route display mode` remains.

### Quick GPS patch (0.0.17)

- Stricter GPS quality filtering (accuracy) reduces outliers in urban environments.
- Activity-specific segment speed caps (Walk/Run/Ride) reduce implausible teleports.
- Tracking start now requires a stable GPS lock (multiple good fixes in sequence) for cleaner first seconds.

### GPS override expansion (Unreleased)

- Added `GPS filter mode` user override in Settings (`Auto by activity`, `Normal`, `Strict (urban)`).
- Auto default now follows clear product logic: Walk/Run stricter, Ride balanced.
- Mode is persisted and applied live to the tracking engine without app restart.
