# ENDU-012 Tracking UI Design Notes

## Zielbild
- Tracking-UI im Map-Kontext modernisieren, ohne das Endurain-Produktgefuehl zu verlieren.
- Start/Stop-Flow weiterhin simpel und robust, aber visuell klarer priorisiert.
- States (`idle`, `recording`, `stopped`) sofort erkennbar machen.

## Endurain-Orientierungspunkte
- Funktionale Klarheit vor Dekoration: Start/Stop und Live-Metriken bleiben im Fokus.
- Reduzierte, sportorientierte Sprache (Status + Metriken + Aktivitaetstyp).
- Bestehender Map-Overlay-Ansatz bleibt erhalten (keine neue Navigationslogik).

## Modernisierung (Design Bridge)
- Statusdarstellung:
  - Neuer Status-Pill mit semantischer Farbe und deutlichem Kontrast.
  - `recording` ist visuell am prominentesten (warnender Rotton).
- Aktivitaetstyp-Auswahl:
  - Android: moderne `ChoiceChip`-Auswahl statt Dropdown (direkter, weniger Klicks).
  - Apple-Plattformen: `CupertinoSlidingSegmentedControl` beibehalten, visuell aufgewertet.
- Primäraktion:
  - Start/Stop als klar dominanter, vollbreiter CTA mit groesserer Touch-Flaeche.
  - Farbe folgt Zustand (Start=Success, Stop=Error), dadurch schnelleres Scannen.
- Metriken:
  - Dauer/Distanz als zwei klar getrennte Metric-Cells fuer bessere Lesbarkeit.

## Kleine Design-Tokens
- Datei: `lib/core/constants/tracking_ui_tokens.dart`
- Enthalten:
  - Spacing-Scale (`xs..xl`)
  - Radius-Scale (`sm..pill`)
  - Semantic Colors (`success`, `warning`, `error`, `info`)
  - Typographic Levels (`title`, `body`, `meta`)

## Accessibility / UX
- Touch Targets vergroessert (Start/Stop Button min. Hoehe 52).
- State ist nicht nur farblich, sondern auch textlich markiert.
- Kontraststarke Statusfarben und klare Label-Hierarchie.
- Material/Cupertino jeweils nativ gehalten, aber mit konsistentem Produkt-Ton.

## Vorher/Nachher (stichpunktartig)
- Vorher:
  - Dropdown-lastige Typauswahl (Android), weniger direkte Interaktion.
  - Status als einfacher Text ohne starke visuelle Gewichtung.
  - Metriken als einfache Zeilen mit geringerer Informationshierarchie.
- Nachher:
  - Chip-/Segment-Auswahl, schnellere Bedienung.
  - Prominenter Status-Pill je State.
  - Strukturiertes Metrics-Layout + klarere CTA-Priorisierung.

## ENDU-013 Testmatrix (Widget)
- `idle`:
  - Start-CTA sichtbar
  - Stop nicht sichtbar
  - Statusanzeige = `Idle`
- `recording`:
  - Stop-CTA sichtbar
  - Start nicht sichtbar
  - Statusanzeige = `Recording`
  - Aktivitaetstyp-Chips deaktiviert
- `stopped`:
  - Statusanzeige = `Stopped`
  - CTA springt auf Start zurueck
- Interaktionen:
  - kompletter Flow `idle -> recording -> stopped`
  - Aktivitaetstyp-Auswahl `run/ride/walk` inklusive UI-Reaktion (`selected`)
  - selektierter Typ wird bei Start korrekt weitergereicht

Stabilitaetsregeln:
- Keine echten GPS-/Engine-Streams (nur kontrollierte Snapshots/Harness).
- Keine zeitbasierte Logik oder Delays.
- Deterministische Assertions ueber Keys und feste, lokalisierte Labels (EN).

## Sprint 3 Review Gate - Design Bridge Check

Bewertung: **PASS**

- Endurain-Produktgefuehl: erhalten (funktionale, sportorientierte Overlay-Logik ohne Branding-Bruch).
- Modernisierung: klare visuelle Hierarchie (Status-Pill, Metrics-Cells, dominante CTA, konsistente Tokens).
- States: `idle` / `recording` / `stopped` visuell und textlich unterscheidbar.
- Primäraktion: Start/Stop ueber eindeutigen Key/Button klar auffindbar und zustandsbasiert.
- Typauswahl: touch-friendly (ChoiceChips / Cupertino Segmented Control) und im Recording-Mode gesperrt.
- Accessibility/Lesbarkeit: hinreichende Kontraststufen, Text+Farbe fuer Zustand, Touch-Target 52px.
- L10n: keine hardcoded User-Texte im Tracking-Surface; Distanz-Einheit ueber `trackingDistanceUnitKm` lokalisiert.

## ENDU-016 History UI Ergaenzung (MVP)

- Ziel:
  - Tracking-MVP um eine klare Rueckschau erweitern: abgeschlossene Activities schnell finden und in einer kompakten Detailansicht pruefen.
- Design-Bridge Konsistenz:
  - Reduzierte, sportorientierte Informationsdarstellung (Typ, Datum, Dauer, Distanz).
  - Karten-/Listen-Logik ohne Brand-Bruch: sachliche Karten/Listen statt dekorativer Effekte.
  - Zustandsklarheit analog ENDU-012: Loading, Empty, Error jeweils explizit und visuell getrennt.
- UX-Entscheidungen:
  - Empty-State mit klarer Erwartungshaltung ("erst Tracking starten, dann Historie").
  - Error-State mit direkter Recovery-Aktion (`Retry`) am Ort des Problems.
  - Detailansicht fokussiert auf Kernmetriken + Track-Point-Anzahl (MVP, ohne komplexe Analyseansichten).
- Touch/Lesbarkeit:
  - Listen-Items mit voller Tap-Area (`ListTile`) und deutlichem Drilldown-Indikator.
  - Kompakte, gut scannbare Metrik-Karten in der Detailansicht.
