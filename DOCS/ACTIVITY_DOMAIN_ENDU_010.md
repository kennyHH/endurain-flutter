# ENDU-010 Activity Domain Design

Datum: 2026-03-09

## Entities / Value Objects

- `Activity`
  - Zentrale Domain-Entity fuer eine Tracking-Session.
- `TrackPoint`
  - Value Object fuer einzelne GPS-Punkte.
- `ActivityType`
  - Enum: `run`, `ride`, `walk` (erweiterbar).

## Felder + Datentypen

### Activity

- `id` (`String`)
- `activityType` (`ActivityType`)
- `startedAt` (`DateTime`)
- `endedAt` (`DateTime?`)
- `durationSeconds` (`int`, abgeleitet)
- `distanceMeters` (`double`)
- `trackPoints` (`List<TrackPoint>`)
- Status-Helfer:
  - `isInProgress` (`bool`)
  - `isCompleted` (`bool`)

### TrackPoint

- `latitude` (`double`)
- `longitude` (`double`)
- `timestamp` (`DateTime`)

## Repository Interface

`ActivityRepository` (MVP-neutral, austauschbar):

- `create(Activity activity)`
- `update(Activity activity)`
- `getById(String id)`
- `listAll()`
- `delete(String id)`

## InMemory Initial-Implementierung

- `InMemoryActivityRepository`
  - speichert in einer in-memory Map (`id -> Activity`)
  - `listAll` liefert sortiert nach `startedAt`
  - geeignet fuer MVP/Tests, spaeter durch persistente Implementierung ersetzbar

## Serialisierung

- `toJson`/`fromJson` fuer `Activity` und `TrackPoint`
- Zeitfelder via ISO-8601

## Validierungsregeln

- `TrackPoint.latitude` muss in `[-90, 90]` liegen
- `TrackPoint.longitude` muss in `[-180, 180]` liegen
- `Activity.id` darf nicht leer sein
- `Activity.distanceMeters` darf nicht negativ sein
- `Activity.endedAt` darf nicht vor `startedAt` liegen

## Scope-Hinweis

- Keine GPX-/Upload-Logik in ENDU-010
- Keine DB-Migration/Persistenz in ENDU-010
