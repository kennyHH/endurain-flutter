# Sprint 3 Kickoff (Activity Tracking MVP Teil 1)

Datum: 2026-03-09

## Ziel

MVP-first Einfuehrung von Activity Tracking in vier inkrementellen Tickets:

- ENDU-010 Activity Domain Model + Repository
- ENDU-011 Tracking Session Engine
- ENDU-012 UI Start/Stop + Aktivitaetstyp
- ENDU-013 Widget Tests Tracking UI

## Aktuelle Basis (Ist-Analyse)

- `MapScreen` hat bereits:
  - Standortanzeige via `LocationService.getCurrentPosition()`
  - laufenden Positionsstream via `LocationService.getPositionStream()`
  - Stream-Lifecycle-Handling (`_positionSubscription` cancel in `dispose`)
- Wiederverwendbare Grundlage:
  - `LocationService` mit Permission-/Service-Checks
  - bestehende DI-Muster (optionale Constructor-Parameter) aus Sprint 2
  - bestehende Testinfrastruktur mit Fakes/Mocks (`MockClient`, Fake-Services)

## Datenmodell (ENDU-010)

- `ActivityType`: `run`, `ride`, `walk`
- `TrackPoint`: `latitude`, `longitude`, `timestamp`
- `Activity`:
  - `id`
  - `activityType`
  - `startTime`, `endTime`
  - `duration` (abgeleitet)
  - `distanceMeters`
  - `trackPoints`

Repository:

- `ActivityRepository` Interface (`save`, `getAll`, `getById`)
- MVP-Implementierung: `InMemoryActivityRepository`
- Persistenz-faehig erweiterbar ohne API-Bruch

## Session-Lifecycle (ENDU-011)

- Zustandsmaschine:
  - `idle` -> `recording` -> `paused` (optional) -> `stopped`
- Engine-Aufgaben:
  - `start(activityType)`: Session initialisieren + Stream abonnieren
  - Positionsupdates verarbeiten
  - Distanz akkumulieren (Haversine)
  - GPS-Rauschen filtern (Mindestdistanz)
  - `stop()`: Stream sauber beenden + Activity erzeugen/speichern

## UI-States & Events (ENDU-012)

- Sichtbarer Tracking-Status: Idle/Recording/Paused/Stopped
- Activity-Type Auswahl: Run/Ride/Walk
- Buttons: Start/Stop
- Live-Metriken: Dauer/Distanz
- Permission-Edgecase:
  - Start ohne Standortfreigabe -> klare User-Meldung, kein Start

## Teststrategie (ENDU-013)

- Unit:
  - `Activity` Model (Serialisierung + Dauer)
  - Repository-Basis
  - Session Engine (start/stop, Distanz, noisy points, 0/1 Punkt Edgecases)
- Widget:
  - Tracking Controls: idle -> recording -> stopped
  - Activity-Type Auswahl wird an Start-Event uebergeben
- Determinismus:
  - keine echten GPS- oder Netzwerkabhaengigkeiten
  - fake stream provider, in-memory repository

## Risiken & Gegenmassnahmen

- Battery/CPU Last durch hohe Update-Frequenz
  - Gegenmassnahme: Mindestdistanz-Filter, inkrementeller Umfang
- GPS Noise / Drift
  - Gegenmassnahme: `minPointDistanceMeters` Filter in Engine
- Permission-Edgecases
  - Gegenmassnahme: Start-Guard in UI + klare Fehlermeldung
- Datenschutz/Location-Sicherheit
  - Gegenmassnahme:
    - nur notwendige Felder speichern (lat/lng/timestamp pro TrackPoint)
    - keine Hintergrund-/Cloud-Übertragung in MVP Teil 1
    - keine unnötige Datensammlung außerhalb aktiver Session

## Umsetzungsstand (Kickoff-Iteration)

- ENDU-010: MVP implementiert (Model + Repository + Unit-Tests)
- ENDU-011: MVP implementiert (Engine + Unit-Tests)
- ENDU-012: MVP implementiert (Map UI Controls + Status + Metriken)
- ENDU-013: MVP implementiert (Widget-Tests fuer Kerninteraktionen)
