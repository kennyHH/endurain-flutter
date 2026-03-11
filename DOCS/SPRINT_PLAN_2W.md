# Endurain Flutter - 2-Wochen Sprintplan (Cursor/Trae ready)

Stand: 2026-03-09

Dieses Dokument ist so aufgebaut, dass du die Tickets direkt mit Cursor/Trae umsetzen kannst:

- klare Sprintziele
- konkrete Tickets mit Akzeptanzkriterien und Testfaellen
- vorgeschlagene Reihenfolge
- copy/paste Prompt-Vorlagen fuer Agentenarbeit
- Verweis auf CSV Importdatei fuer Tracking-Tools

CSV Importdatei: `DOCS/SPRINT_PLAN_2W.csv`

---

## 1) Arbeitsmodus mit Cursor/Trae

### Empfohlene Ausfuehrung pro Ticket

1. Ticket in kleinem Branch umsetzen
2. Nach jeder groesseren Aenderung:
   - Analyze/Lint laufen lassen
   - Tests laufen lassen
3. PR mit:
   - kurzer Problem-/Loesungsbeschreibung
   - Testnachweis
   - Security/Regression-Check

### Standard-Definition of Done (DoD)

- Akzeptanzkriterien vollstaendig erfuellt
- Keine neuen Lint-Fehler
- Relevante Tests vorhanden und gruen
- Kein Secret/Token/Key im Commit
- Doku aktualisiert (wenn Verhalten/Setup betroffen)

---

## 2) Sprint 1 (Woche 1-2): Stabilisierung + Security-Basis

### Sprintziel

- Build-/Qualitaetsgates einziehen
- kritische Security-Hardening Punkte schliessen
- testbare Baseline schaffen

### Ticket ENDU-001 - CI Pipeline einfuehren

- **Prioritaet:** Hoch
- **Schaetzung:** 2 PT
- **Beschreibung:** GitHub Actions fuer `analyze`, `test`, Android Build Smoke.
- **Akzeptanzkriterien:**
  - PR startet Pipeline automatisch
  - Pipeline failt bei Lint/Test-Fehlern
  - Erfolgreiche PR ist nachvollziehbar gruen
- **Testfaelle:**
  - absichtlicher Lint-Fehler -> Pipeline rot
  - saubere Aenderung -> Pipeline gruen
- **Cursor/Trae Prompt (copy/paste):**
  - "Erstelle in diesem Flutter-Repo einen GitHub Actions Workflow mit analyze, test und Android debug build. Nutze Cache fuer pub dependencies und fail-fast Verhalten. Achte auf klare Jobnamen und kommentiere kurz die Schritte."

### Ticket ENDU-002 - HTTPS Enforcement

- **Prioritaet:** Hoch
- **Schaetzung:** 1 PT
- **Beschreibung:** In Production nur HTTPS Server-URLs erlauben.
- **Akzeptanzkriterien:**
  - `http://` wird in Release-Flow blockiert
  - `https://` bleibt erlaubt
  - User sieht klare lokalisierte Fehlermeldung
- **Testfaelle:**
  - URL `http://example.com` -> Validation Error
  - URL `https://example.com` -> naechster Schritt moeglich
- **Cursor/Trae Prompt:**
  - "Implementiere HTTPS-Only Validierung fuer Server-URL im Login/Settings Flow fuer Production-Builds. Halte die Loesung lokalisiert (EN/PT) und fuege Unit-Tests fuer Validatoren hinzu."

### Ticket ENDU-003 - SSO WebView Host-Allowlist

- **Prioritaet:** Hoch
- **Schaetzung:** 2-3 PT
- **Beschreibung:** Navigation in SSO-WebView auf erlaubte Hosts begrenzen.
- **Akzeptanzkriterien:**
  - unbekannte Hosts werden blockiert
  - nur validierte Callback-URLs triggern Session Exchange
  - sichere Fehlermeldung statt Roh-Exception
- **Testfaelle:**
  - erlaubter Host + success callback -> Login erfolgreich
  - fremder Host -> Abbruch + UI Hinweis
- **Cursor/Trae Prompt:**
  - "Haerte SSO WebView Navigation: implementiere Host-Allowlist, sichere Callback-Pruefung und defensive Fehlerbehandlung. Ergaenze Tests fuer erlaubte und blockierte Redirects."

### Ticket ENDU-004 - Fehler-Mapping

- **Prioritaet:** Hoch
- **Schaetzung:** 2 PT
- **Beschreibung:** Keine direkten `e.toString()` Meldungen im UI.
- **Akzeptanzkriterien:**
  - standardisierte User-Fehlertexte fuer Netzwerk/Auth/Server
  - technische Details bleiben intern
  - i18n in EN/PT abgedeckt
- **Testfaelle:**
  - 401/403/500/Timeout -> jeweils definierte Meldung
- **Cursor/Trae Prompt:**
  - "Fuehre ein Error-Mapping fuer API/Auth Fehler ein, ersetze rohe Exception-Anzeigen im UI und nutze lokalisierte Schluesseltexte in app_en.arb/app_pt.arb."

### Ticket ENDU-005 - Auth Service Unit Tests

- **Prioritaet:** Hoch
- **Schaetzung:** 2-3 PT
- **Beschreibung:** Unit Tests fuer Login/MFA/Refresh/Logout mit Mock HTTP.
- **Akzeptanzkriterien:**
  - Erfolgs- und Fehlerpfade getestet
  - mind. 70% Coverage fuer Auth Service
- **Testfaelle:**
  - Login Erfolg mit session exchange
  - MFA required flow
  - Refresh erfolgreich/nicht erfolgreich
  - Logout success/failure
- **Cursor/Trae Prompt:**
  - "Schreibe Unit-Tests fuer AuthService inkl. Login, MFA, Refresh und Logout. Mocke HTTP Responses und SecureStorage. Achte auf reproduzierbare Tests ohne echte Netzwerkzugriffe."

---

## 3) Sprint 2 (Woche 3-4): Architektur-Haertung + Testbarkeit

### Sprintziel

- doppelte Infrastruktur abbauen
- DI/Testbarkeit verbessern
- Services breit absichern

### Ticket ENDU-006 - API Schicht konsolidieren

- **Prioritaet:** Hoch
- **Schaetzung:** 3 PT
- **Beschreibung:** Einheitliche Request-Logik statt verteilter direkter HTTP-Calls.
- **Akzeptanzkriterien:**
  - zentrale Header/Timeout/Error-Strategie
  - kein redundanter Call-Code in mehreren Services
- **Testfaelle:**
  - 200/401/500 Verhalten konsistent
  - Header pro Endpoint korrekt

### Ticket ENDU-007 - DI einfuehren

- **Prioritaet:** Hoch
- **Schaetzung:** 3 PT
- **Beschreibung:** Services injizierbar machen (Provider/Riverpod oder schlanke Abstraktion).
- **Status:** In Umsetzung (minimalistische Constructor-DI in Kernscreens gestartet)
- **Akzeptanzkriterien:**
  - UI instanziiert Kernservices nicht mehr hart
  - Widget-Tests mit Mocks moeglich
- **Testfaelle:**
  - LoginScreen mit Mock AuthService verhaelt sich korrekt

### Ticket ENDU-008 - Service Testpaket erweitern

- **Prioritaet:** Mittel
- **Schaetzung:** 3 PT
- **Beschreibung:** Tests fuer `SsoService`, `ServerSettingsService`, `Validators`.
- **Status:** Umgesetzt (Service-Testpaket erweitert, deterministische Unit-Tests aktiv)
- **Akzeptanzkriterien:**
  - Parsing/Fehlerpfade getestet
  - Validatoren robust
- **Testfaelle:**
  - unterschiedliche Response-Formate bei IDP List
  - fehlende Felder in ServerSettings -> Defaults

### Ticket ENDU-009 - Android Release Build Konfiguration

- **Prioritaet:** Mittel
- **Schaetzung:** 1 PT
- **Beschreibung:** Release Signing sauber vorbereiten und dokumentieren.
- **Status:** Umgesetzt (sicherer Signing-Default + Setup-Doku ohne Secrets)
- **Akzeptanzkriterien:**
  - keine produktive Release-Nutzung mit Debug-Signing
  - nachvollziehbare Setup-Doku
- **Testfaelle:**
  - dokumentierter Dry-Run Build

---

## 4) Backlog danach (Featurekiste / Activity Tracking)

- ENDU-010 Activity Domain Model + Repository (Status: umgesetzt fuer MVP Teil 1)
- ENDU-011 Tracking Session Engine (Status: umgesetzt fuer MVP Teil 1, Engine-Regeln + Edge-Case-Tests vorhanden)
- ENDU-012 UI Start/Stop + Aktivitaetstyp (Sprint 3 umgesetzt, inkl. UI Design Bridge)
- ENDU-013 Widget Tests Tracking (Sprint 3 gestartet, MVP Teil 1 umgesetzt)
- ENDU-014 GPX Export (Status: DONE - MVP umgesetzt inkl. Unit-Tests)
- ENDU-015 Upload + Retry (Status: DONE - MVP umgesetzt inkl. Retry-Tests)
- ENDU-016 Activity History (Status: DONE - MVP Liste + Detailansicht inkl. empty/loading/error und Widget-Tests)
- ENDU-017 Integration Smoke Flow (Status: DONE - stabiler, netzwerkfreier End-to-End-naher Smoke-Test)

Sprint-4-Gate Hinweis: Aktuell kein Blocker aus ENDU-017 identifiziert.
Sprint-4-Review-Gate Ergebnis: PASS (ENDU-014..017 geprueft, analyze/test gruen, keine High-Severity Blocker).

---

## 5) Import in Jira/Linear

Nutze die Datei `DOCS/SPRINT_PLAN_2W.csv`.

Empfohlene Feldzuordnung:

- `Title` -> Titel
- `Description` -> Beschreibung
- `Priority` -> Prioritaet
- `Estimate` -> Aufwand
- `Sprint` -> Sprintname
- `Labels` -> Tags
- `AcceptanceCriteria` -> Akzeptanzkriterien
- `TestCases` -> Testfaelle

---

## 6) Fast-Start Checkliste (morgen umsetzbar)

- [ ] ENDU-001 zuerst umsetzen (CI)
- [ ] ENDU-002 + ENDU-003 direkt danach (Security)
- [ ] ENDU-004 parallel vorbereiten (Error mapping + l10n)
- [ ] ENDU-005 als Test-Sicherheitsnetz
- [ ] Sprint Review mit Metrics: Pipeline pass rate, Testcount, offene High Risks

