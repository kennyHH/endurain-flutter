# ENDU-011 Tracking Session Engine Design

Datum: 2026-03-09

## Ziel

Eine UI-unabhaengige, deterministische Engine fuer Activity-Aufzeichnung mit konsistenter Distanz-/Dauerlogik.

## Session-Zustaende

- `idle`: keine aktive Session
- `recording`: Session laeuft, Punkte koennen aufgenommen werden
- `paused` (vorbereitet, optional): Session pausiert
- `stopped`: Session beendet, finale Activity vorhanden

## Inputs

- `start(activityType, startedAt?)`
- `addPoint(trackPoint)`
- `stop(endedAt?)`
- Positionsstream (optional via `PositionStreamProvider`) wird intern auf `addPoint` gemappt

## Outputs

- `snapshot` (`TrackingSessionSnapshot`) mit:
  - aktuellem Zustand
  - Distanz in Metern
  - Dauer
  - TrackPoints
  - finaler `Activity` nach `stop`
- `stream` fuer Beobachtung von Snapshot-Updates

## Engine-API

- `start(ActivityType activityType, {DateTime? startedAt}) -> Future<bool>`
- `addPoint(TrackPoint point) -> bool`
- `stop({DateTime? endedAt}) -> Future<Activity?>`
- `reset() -> Future<void>`
- `currentSessionState`/`snapshot` Getter

## Distanz-/Dauerregeln

- Distanz wird als Summe der Segmentdistanzen auf Basis Haversine berechnet.
- Segmente unter `minPointDistanceMeters` werden ignoriert (Noise-Schutz).
- Duplicate Points fallen dadurch automatisch raus.
- Out-of-order Timestamps (neuer Punkt vor letztem Punkt) werden ignoriert.
- Dauer basiert auf:
  - waehrend Recording: Punkt-Zeitstempel minus `startedAt`
  - bei Stop: `endedAt` (oder `now`) minus `startedAt`

## Validierungs-/Defensivregeln

- `addPoint` akzeptiert nur im Zustand `recording`.
- `stop` akzeptiert nur im Zustand `recording`, sonst `null`.
- `endedAt` vor `startedAt` wird defensiv auf `startedAt` geklemmt.

## Repository-Integration (MVP)

- Beim Stop wird die finale `Activity` via `ActivityRepository.create(...)` persistiert.
- Die Engine bleibt DI-faehig und austauschbar durch Interface-Kopplung.

## Edge-Case Verhalten

- 0 Punkte -> Distanz 0
- 1 Punkt -> Distanz 0
- duplicate points -> ignoriert
- out-of-order points -> ignoriert

