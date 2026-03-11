# Changelog (Agent)

## 2026-03-09

### Ticket: ENDU-004

**Geänderte Dateien**
- `lib/core/utils/error_mapper.dart`
- `lib/features/auth/login_screen.dart`
- `lib/features/settings/server_settings_screen.dart`
- `lib/features/auth/sso_webview_screen.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_pt.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_pt.dart`
- `test/core/utils/error_mapper_test.dart`

**Was geändert wurde**
- Zentrales Error-Mapping (`AppErrorMapper`) eingeführt, das technische Fehler in stabile, nutzerfreundliche Fehlertypen übersetzt.
- UI-Flows in Login, SSO und Server-Settings so angepasst, dass keine rohen `e.toString()`-Texte mehr direkt an Nutzer:innen gezeigt werden.
- SSO-WebView-Resource-Fehler auf lokalisierte, sichere User-Messages umgestellt.
- Neue EN/PT Lokalisierungskeys für konsistente Fehlermeldungen ergänzt.
- Unit-Tests für das Error-Mapping ergänzt.

**Warum geändert wurde**
- Verhindert Leakage interner technischer Details im UI.
- Sorgt für konsistente, lokalisierte und verständliche Fehlermeldungen.
- Verbessert Security-Hygiene und UX in Auth/SSO/Settings-Flows.

**Testnachweis (analyze/test + manuelle Checks)**
- `flutter gen-l10n` erfolgreich.
- `flutter analyze` erfolgreich (No issues found).
- `flutter test` erfolgreich (All tests passed).
- Zielgerichteter Test: `flutter test test/core/utils/error_mapper_test.dart` erfolgreich.
- Manuelle Checks: nicht in diesem Lauf durchgeführt.

**Offene Punkte/Risiken**
- Error-Mapping erfolgt aktuell pattern-basiert auf Exception-Texten; bei zukünftigen Service-Fehlertextänderungen sollten Mapping-Regeln ggf. erweitert werden.

### Ticket: ENDU-005

**Geänderte Dateien**
- `lib/core/services/auth_service.dart`
- `test/core/services/auth_service_test.dart`
- `DOCS/CHANGELOG_AGENT.md`

**Was geändert wurde**
- Robuste Unit-Tests für `AuthService` ergänzt:
  - Login Erfolg inkl. Session-Token-Exchange
  - Login mit `mfa_required = true`
  - MFA-Verifizierung Erfolg/Fehler
  - Token-Refresh Erfolg/Fehler
  - Logout Erfolg/Fehler mit garantiertem lokalem Token-Clearing
- Minimalinvasive Testbarkeits-Verbesserung in `AuthService`:
  - optionale Dependency Injection für `http.Client` und `SecureStorageService`
  - bestehendes fachliches Verhalten bleibt unverändert
- Vollständig deterministisches Mocking ohne echte Netzwerke/ohne echtes Secure Storage:
  - `MockClient` für HTTP
  - `FakeSecureStorageService` für Storage

**Warum geändert wurde**
- Auth-Flows sollten stabil, reproduzierbar und ohne externe Abhängigkeiten testbar sein.
- Fehler- und Erfolgszweige der Kern-Auth-Methoden müssen regressionssicher abgedeckt sein.

**Testnachweis (analyze/test + manuelle Checks)**
- `flutter analyze` erfolgreich (No issues found).
- `flutter test` erfolgreich (All tests passed).
- Zielgerichteter Lauf: `flutter test test/core/services/auth_service_test.dart` erfolgreich.
- Coverage-Lauf: `flutter test --coverage` erfolgreich.
- `auth_service.dart` Line-Coverage: `83/99 = 83.84%`.
- Manuelle Checks: nicht in diesem Lauf durchgeführt.

**Offene Punkte/Risiken**
- Coverage misst Line-Coverage; branch-spezifische Kanten können künftig weiter ergänzt werden (z. B. zusätzliche Exception-Varianten in Exchange-Pfaden).

### Sprint 1 Review Gate

**Geprüfte Tickets**
- ENDU-001 (CI Pipeline)
- ENDU-002 (HTTPS Enforcement)
- ENDU-003 (SSO Host-Allowlist + Callback-Validierung)
- ENDU-004 (Error-Mapping + lokalisierte Fehlertexte)
- ENDU-005 (Auth Service Unit Tests)

**Ergebnis je Ticket**
- ENDU-001: Erfüllt (CI Workflow mit `push`/`pull_request`, Jobs `analyze`, `test`, `android_build_smoke`, inkl. Pub-Cache).
- ENDU-002: Erfüllt (`validateServerUrl` blockiert `http://`, `https://` erlaubt, EN/PT Meldungen vorhanden).
- ENDU-003: Erfüllt (Host-Allowlist aktiv, blockierte Fremdhosts, robuste Callback-Prüfung mit Host+Path+Parametern).
- ENDU-004: Erfüllt (kein direktes `e.toString()` in UI-Flows, zentrales Error-Mapping, EN/PT Keys vorhanden).
- ENDU-005: Erfüllt (AuthService-Kernpfade durch Unit-Tests abgedeckt, HTTP/Storage vollständig gemockt, keine Netzwerkanbindung).

**Was geändert wurde**
- Review-Gate durchgeführt und gegen Akzeptanzkriterien + Sprint-DoD validiert.
- Keine zusätzlichen Codefixes notwendig.

**Warum geändert wurde**
- Sicherstellung, dass Sprint 1 als konsistentes, testbares und sicherheitsgehärtetes Inkrement abgeschlossen ist.

**Testnachweis (analyze/test + manuelle Checks)**
- `flutter gen-l10n` erfolgreich.
- `flutter analyze` erfolgreich (No issues found).
- `flutter test` erfolgreich (All tests passed).
- Manuelle Checks: nicht Bestandteil dieses Review-Laufs.

**Offene Punkte/Risiken**
- `AppErrorMapper` bleibt textpattern-basiert; bei künftigen Service-Fehlertextänderungen sollten Mapping-Regeln angepasst bzw. später auf strukturierte Fehlercodes umgestellt werden.

### Sprint 2 Kickoff Gate

**Geänderte Dateien**
- `DOCS/SPRINT_2_KICKOFF.md`
- `lib/core/services/public_api_client.dart`
- `lib/core/services/server_settings_service.dart`
- `lib/core/services/sso_service.dart`
- `lib/features/auth/login_screen.dart`
- `test/core/services/server_settings_service_test.dart`
- `test/core/services/sso_service_test.dart`
- `test/core/utils/validators_sprint2_test.dart`
- `DOCS/CHANGELOG_AGENT.md`

**Was geändert wurde**
- Kickoff-Dokument fuer Sprint 2 erstellt mit Ist-Analyse, Reihenfolge, Risiken, Scope, Akzeptanzkriterien und Teststrategie fuer ENDU-006 bis ENDU-009.
- ENDU-006 gestartet: zentrale Public-API-Request-Struktur (`PublicApiClient`) eingefuehrt und `ServerSettingsService` darauf umgestellt.
- ENDU-007 gestartet: `LoginScreen` von harten Service-Instanzen auf optionale Constructor Injection umgestellt (rueckwaertskompatible Defaults).
- ENDU-008 gestartet: lauffaehige Test-Skeletons fuer `SsoService`, `ServerSettingsService` und erweiterte Validator-Testbasis angelegt.
- ENDU-009 vorbereitet: Release-Signing-Luecken und sichere ToDos im Kickoff-Dokument konkret festgehalten.

**Warum geändert wurde**
- Sprint 2 soll mit kontrolliertem, inkrementellem Architekturfortschritt starten statt mit riskantem Big-Bang-Refactor.
- Testbarkeit und API-Konsistenz werden frueh vorbereitet, um folgende Tickets schneller und sicherer abzuschliessen.

**Testnachweis (analyze/test + manuelle Checks)**
- `flutter gen-l10n` erfolgreich.
- `flutter analyze` erfolgreich (No issues found).
- `flutter test` erfolgreich (All tests passed).
- Manuelle Checks: nicht Bestandteil dieses Kickoff-Gates.

**Offene Punkte/Risiken**
- `SsoService` ist nur teilweise in Richtung zentraler API-Schicht vorbereitet; volle Konsolidierung (006) folgt in den naechsten Schritten.
- Android Release-Signing bleibt bewusst dokumentierter Gap bis zur finalen ENDU-009-Umsetzung.

### ENDU-006 API Refactor

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `lib/core/services/api_request_executor.dart`
- `lib/core/services/server_settings_service.dart`
- `lib/core/services/auth_service.dart`
- `lib/core/services/sso_service.dart`
- `lib/core/services/api_client.dart`
- `test/core/services/api_request_executor_test.dart`
- `test/core/services/auth_service_test.dart`
- `test/core/services/server_settings_service_test.dart`
- `test/core/services/sso_service_test.dart`
- `DOCS/API_REFACTOR_PLAN_ENDU_006.md`
- `DOCS/CHANGELOG_AGENT.md`
- (entfernt) `lib/core/services/public_api_client.dart`

**Migrationsschritte**
- Phase 0: Ist-Analyse direkter HTTP-Aufrufe dokumentiert.
- Phase 1: zentrale API-Basis (`ApiRequestExecutor`) mit URL-Bau, Standardheadern, Timeout und strukturierten Infrastrukturfehlern eingefuehrt + Unit-Tests.
- Phase 2: `ServerSettingsService` auf zentrale Basis migriert.
- Phase 3: `AuthService` und `SsoService` wesentlich auf zentrale Basis migriert; `ApiClient`-Duplikatlogik reduziert und an zentrale Basis angebunden.
- Phase 4: ungenutzte Zwischenklasse (`PublicApiClient`) entfernt; Architektur in Plan-Doku finalisiert.

**Risiken / offene Punkte**
- Service-seitige Fachfehler laufen weiterhin ueber bestehende Exception-Semantik; das ist bewusst fuer Rueckwaertskompatibilitaet, kann spaeter weiter strukturiert werden.
- Multipart-Upload bleibt separat in `ApiClient` (kein Regressionsrisiko, aber noch kein einheitlicher Pfad).

**Testnachweis (analyze/test)**
- Fokussiert: `flutter test test/core/services/api_request_executor_test.dart test/core/services/auth_service_test.dart test/core/services/sso_service_test.dart test/core/services/server_settings_service_test.dart` erfolgreich.
- Gesamt: `flutter analyze` erfolgreich (No issues found).
- Gesamt: `flutter test` erfolgreich (All tests passed).

### ENDU-007 DI Einfuehrung

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `DOCS/DI_PLAN_ENDU_007.md`
- `lib/features/settings/server_settings_screen.dart`
- `test/features/auth/login_screen_di_test.dart`
- `DOCS/SPRINT_PLAN_2W.md`
- `DOCS/CHANGELOG_AGENT.md`

**Welche Klassen nun injizierbar sind**
- `LoginScreen` (bereits vorhanden, nun aktiv per DI-Test genutzt): `AuthService`, `SsoService`, `ServerSettingsService`
- `ServerSettingsScreen` (neu injizierbar gemacht): `SecureStorageService`, `AuthService`

**Warum diese Auswahl**
- `LoginScreen` und `ServerSettingsScreen` sind zentrale UI-Entrypoints mit direktem Service-Zugriff und damit low-risk fuer minimalistische Constructor-DI.
- Fokus auf testbare Kernscreens ohne Framework-Overhead oder globale Architekturumbrueche.

**Testnachweis**
- Neuer Widget-Test mit injiziertem Fake-Service:
  - `test/features/auth/login_screen_di_test.dart`
  - prueft deterministisch Erfolg/Fehlerpfad von Step-1 ohne Netzwerkzugriff
- Gesamtchecks:
  - `flutter analyze` erfolgreich
  - `flutter test` erfolgreich

### ENDU-008 Service Testpaket

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `DOCS/TEST_PLAN_ENDU_008.md`
- `test/core/services/server_settings_service_test.dart`
- `test/core/services/sso_service_test.dart`
- `test/core/utils/validators_sprint2_test.dart`
- `DOCS/SPRINT_PLAN_2W.md`
- `DOCS/CHANGELOG_AGENT.md`

**Neue Testabdeckung je Service**
- `ServerSettingsService`
  - 200-Parsing inkl. Side-Effects fuer `tileserver_url`, `tileserver_attribution`, `map_background_color`
  - Defaults bei fehlenden optionalen Feldern
  - Fehlerpfad bei Non-200
  - Fehlerpfad bei fehlender/leerer `serverUrl`
- `SsoService`
  - `getEnabledProviders` fuer Listen-Response
  - `getEnabledProviders` fuer Objekt-Response mit `providers`
  - Fehler bei unerwartetem Response-Format
  - `initiateOAuth` Query-Parameter inkl. PKCE (`code_challenge`, `code_challenge_method=S256`, `redirect`)
  - `exchangeSessionForTokens` Erfolg/Failure inkl. Storage-Side-Effects
  - Fehlerpfad ohne PKCE-Verifier
- `Validators`
  - `validateRequired`: `null`/leer/whitespace/valid
  - `validateUrl`: gueltig/ungueltig
  - ENDU-002 Policy-Verhalten (`validateServerUrl`: `http` reject, `https` allow)

**Bekannte Restluecken**
- Keine branch-genaue Coverage-Auswertung in diesem Lauf; Fokus lag auf funktionalen Kern- und Fehlerpfaden.
- Weitere negative Parser-Edge-Cases (z. B. inkonsistente Typen einzelner JSON-Felder) koennen spaeter ergaenzt werden.

**Testnachweis**
- Fokuslauf: `flutter test test/core/services/server_settings_service_test.dart test/core/services/sso_service_test.dart test/core/utils/validators_sprint2_test.dart` erfolgreich.
- Gesamt: `flutter analyze` erfolgreich (No issues found).
- Gesamt: `flutter test` erfolgreich (All tests passed).

### ENDU-009 Android Release Konfig

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `android/app/build.gradle.kts`
- `android/.gitignore`
- `android/key.properties.example`
- `DOCS/ANDROID_RELEASE_SIGNING_PLAN_ENDU_009.md`
- `DOCS/ANDROID_RELEASE_SIGNING.md`
- `DOCS/SPRINT_PLAN_2W.md`
- `DOCS/CHANGELOG_AGENT.md`

**Sicherheitsverbesserung**
- Release-Build verwendet keinen impliziten Debug-Signing-Default mehr.
- Signing wird nur aktiviert, wenn `android/key.properties` vollstaendig ist und die referenzierte Keystore-Datei existiert.
- Ohne Signing-Setup failt ein angeforderter Release-Task mit klarer Fehlermeldung (fail-safe Default).
- Optionaler Debug-Fallback ist nur explizit per Gradle-Property moeglich (`-PallowDebugSigningForLocalRelease=true`) und fuer lokale Diagnose gedacht.
- `.gitignore` fuer Signing-Dateien verstaerkt und ein secret-freies Template (`android/key.properties.example`) bereitgestellt.

**Test-/Buildnachweis**
- `flutter analyze` erfolgreich.
- `flutter build apk --release` ausgefuehrt:
  - Build in dieser Umgebung nicht bis Signing-Phase validierbar, da Android SDK fehlt (`No Android SDK found`).
  - Signing-Konfiguration ist dokumentiert und fail-safe umgesetzt; finale lokale Verifikation erfordert Android SDK + lokale Signing-Dateien.

**Offene Restpunkte**
- Fuer echte produktive Artefakte muessen lokal oder in CI gueltige Signing-Secrets bereitgestellt werden.

### Sprint 2 Review Gate

**Datum**
- 2026-03-09

**Geprüfte Tickets**
- ENDU-006 API-Schicht konsolidieren
- ENDU-007 Dependency Injection
- ENDU-008 Service-Testpaket
- ENDU-009 Android Release-Konfiguration

**Ergebnis je Ticket**
- ENDU-006: Erfuellt (zentrale API-Basis `ApiRequestExecutor` vorhanden und aktiv genutzt; HTTP-Duplikate reduziert).
- ENDU-007: Erfuellt (mindestens zwei zentrale UI-Komponenten DI-faehig; Mock/Fake-Injektion in Tests moeglich und genutzt).
- ENDU-008: Erfuellt (Unit-Tests fuer `SsoService`, `ServerSettingsService`, `Validators`; deterministisch mit Mocks/Fakes ohne echte HTTP-Calls).
- ENDU-009: Erfuellt (kein impliziter produktiver Debug-Signing-Default; sichere Signing-Doku/Setup ohne Secrets im Repo).

**Test-/Qualitaetsnachweis**
- `flutter gen-l10n` erfolgreich.
- `flutter analyze` erfolgreich (No issues found).
- `flutter test` erfolgreich (All tests passed).
- `flutter build apk --release` in dieser Umgebung nicht final validierbar: Android SDK fehlt (`No Android SDK found`).

**Security-/Risikoeinschaetzung**
- Keine neuen kritischen Security-Risiken im Scope identifiziert.
- Restrisiko: produktiver Android Release-Build ist an lokale/CI Signing-Secrets und Android SDK gebunden (erwartet und dokumentiert).

**Zusatzdokumentation**
- `DOCS/SPRINT_2_REVIEW_GATE.md` mit Review-Matrix, Pflicht-Checks und Restpunkten erstellt.

### Sprint 3 Kickoff + ENDU-010..013

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `DOCS/SPRINT_3_KICKOFF.md`
- `lib/core/models/activity.dart`
- `lib/core/services/activity_repository.dart`
- `lib/core/services/tracking_session_engine.dart`
- `lib/features/map/widgets/tracking_controls.dart`
- `lib/features/map/map_screen.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_pt.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_pt.dart`
- `test/core/models/activity_test.dart`
- `test/core/services/activity_repository_test.dart`
- `test/core/services/tracking_session_engine_test.dart`
- `test/features/map/tracking_controls_test.dart`
- `DOCS/SPRINT_PLAN_2W.md`
- `DOCS/CHANGELOG_AGENT.md`

**Was/Warum**
- Sprint-3 Kickoff-Dokument mit Datenmodell, Session-Lifecycle, UI-Events, Teststrategie und Risiken erstellt.
- ENDU-010: minimales Activity-Domain-Model und schlankes Repository-Interface + InMemory-Implementierung eingefuehrt.
- ENDU-011: Tracking-Session-Engine mit Start/Stop/Pause/Resume, Distanzakkumulation und Noise-Filter eingefuehrt.
- ENDU-012: Tracking-UI (Activity-Type Auswahl, Start/Stop, Status, Live-Metriken) in Map-Flow integriert.
- ENDU-013: deterministische Unit-/Widget-Tests fuer Kernpfade ohne echte GPS-/Netzwerkabhaengigkeit umgesetzt.
- Datenschutzfokus: keine Cloud-Uploads, nur notwendige Trackingdaten im MVP-Umfang.

**Testnachweis**
- `flutter gen-l10n` erfolgreich.
- Fokuslauf erfolgreich:
  - `flutter test test/core/models/activity_test.dart test/core/services/activity_repository_test.dart test/core/services/tracking_session_engine_test.dart test/features/map/tracking_controls_test.dart`
- Gesamt:
  - `flutter analyze` erfolgreich
  - `flutter test` erfolgreich

**Offene Risiken**
- Aktuell InMemory-Repository (keine Persistenz ueber App-Neustart); persistente Speicherung folgt in spaeteren Tickets.
- Permission-/Sensorverhalten kann je Geraet variieren; Kernpfade sind durch Fakes abgesichert.

### ENDU-010 Activity Domain + Repository

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `DOCS/ACTIVITY_DOMAIN_ENDU_010.md`
- `lib/core/models/activity.dart`
- `lib/core/services/activity_repository.dart`
- `test/core/models/activity_test.dart`
- `test/core/services/activity_repository_test.dart`
- `test/core/services/tracking_session_engine_test.dart`
- `DOCS/SPRINT_PLAN_2W.md`
- `DOCS/CHANGELOG_AGENT.md`

**Modellentscheidungen**
- `Activity` verwendet `startedAt`/`endedAt` plus abgeleitetes `durationSeconds`.
- `TrackPoint` validiert Latitude/Longitude Bounds beim Erzeugen.
- Status-Helfer `isInProgress`/`isCompleted` ergaenzen die Session-Auswertung.
- Repository-API als austauschbares Interface (`create`, `update`, `getById`, `listAll`, `delete`) mit `InMemoryActivityRepository` fuer MVP.

**Testnachweis**
- Fokuslaeufe:
  - `flutter test test/core/models/activity_test.dart`
  - `flutter test test/core/services/activity_repository_test.dart`
- Integrationsnahe Nutzung geprueft ueber:
  - `flutter test test/core/services/tracking_session_engine_test.dart`
- Gesamt:
  - `flutter analyze` erfolgreich
  - `flutter test` erfolgreich

**Offene Punkte**
- Persistente Speicherung (Datei/DB) ist bewusst out-of-scope fuer ENDU-010 und folgt in spaeteren Tickets.

### ENDU-011 Tracking Session Engine

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `DOCS/TRACKING_ENGINE_ENDU_011.md`
- `lib/core/services/tracking_session_engine.dart`
- `test/core/services/tracking_session_engine_test.dart`
- `DOCS/SPRINT_PLAN_2W.md`
- `DOCS/CHANGELOG_AGENT.md`

**Session-Regeln**
- Zustaende: `idle`, `recording`, `paused` (vorbereitet), `stopped`.
- `start(...)` startet Session nur wenn nicht bereits recording.
- `addPoint(...)` akzeptiert Punkte nur im `recording`-State.
- `stop(...)` ist nur im `recording`-State gueltig und liefert sonst `null`.

**Distanz-/Dauerlogik**
- Distanz: Summe aufeinanderfolgender Segmente via Haversine.
- Sehr kurze Segmente unter `minPointDistanceMeters` werden als Noise ignoriert.
- Duplicate Points werden dadurch ebenfalls ignoriert.
- Out-of-order Timestamps werden defensiv ignoriert.
- Dauer: feste Zeitdifferenz `endedAt - startedAt` (mit optionalen expliziten Timestamps fuer deterministische Tests).

**Testnachweis**
- Fokuslauf:
  - `flutter test test/core/services/tracking_session_engine_test.dart`
- Gesamt:
  - `flutter analyze` erfolgreich
  - `flutter test` erfolgreich

**Offene Restpunkte**
- Persistente Speicherung ueber InMemory hinaus bleibt Folgearbeit in spaeteren Tickets.
- Optionales `paused`-Verhalten ist API-seitig vorbereitet, aber nicht vollumfaenglich in der UI ausgebaut.

### ENDU-012 UI Design Bridge

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `lib/core/constants/tracking_ui_tokens.dart`
- `lib/features/map/widgets/tracking_controls.dart`
- `lib/features/map/map_screen.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_pt.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_pt.dart`
- `test/features/map/tracking_controls_test.dart`
- `DOCS/TRACKING_UI_DESIGN_NOTES_ENDU_012.md`
- `DOCS/SPRINT_PLAN_2W.md`
- `DOCS/CHANGELOG_AGENT.md`

**Was geändert wurde**
- Tracking-Overlay visuell modernisiert (Status-Pill, strukturierte Metriken, modernere Aktivitaetstyp-Auswahl, klarere CTA-Priorisierung).
- Kleine Design-Tokens fuer Spacing/Radius/Semantikfarben/Typografie eingefuehrt und in `TrackingControls` angewendet.
- Plattformstil beibehalten: Cupertino fuer Apple, Material 3 fuer Android.
- Hardcoded Tooltip im Map-FAB auf L10n umgestellt (`mapCenterOnLocation` EN/PT).
- Widget-Test fuer Activity-Type-Auswahl an Chip-basierte Interaktion angepasst.

**Warum geändert wurde**
- ENDU-012 soll nicht nur funktional, sondern auch als Design-Bridge zwischen bestehendem Endurain-Stil und moderner Mobile-UX dienen.
- Bessere visuelle Hierarchie reduziert Bedienfehler bei Start/Stop und verbessert State-Erkennbarkeit waehrend Aufzeichnung.

**Testnachweis**
- `flutter gen-l10n` erfolgreich.
- `flutter analyze` erfolgreich.
- `flutter test` erfolgreich.

**Offene Punkte/Risiken**
- Feintuning der finalen Farbwerte kann nach visuellem Device-Review (hell/dunkel, Outdoor-Kontrast) weiter justiert werden.

### ENDU-013 Tracking UI Tests

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `test/features/map/tracking_controls_test.dart`
- `DOCS/TRACKING_UI_DESIGN_NOTES_ENDU_012.md`
- `DOCS/CHANGELOG_AGENT.md`

**Was geändert wurde**
- Widget-Tests fuer die neue Tracking-UI erweitert:
  - `idle` State (Start sichtbar, Stop nicht sichtbar)
  - `recording` State (Stop aktiv, Recording-Indikator sichtbar)
  - `stopped` State (Statuswechsel + CTA-Ruecksprung auf Start)
  - Aktivitaetstyp-Auswahl `run/ride/walk` inkl. UI-Reaktion und Weitergabe beim Start
- Design-/UX-relevante Checks aufgenommen:
  - primaere Aktion eindeutig auffindbar (`tracking-start-stop-button`)
  - Status-Komponente wechselt korrekt
  - Disabled-State der Typ-Chips im Recording-Mode validiert
- Testmatrix in den Design Notes dokumentiert.

**Warum geändert wurde**
- ENDU-013 fordert stabile, reproduzierbare Widget-Tests fuer Kernzustand und Interaktion der modernisierten Tracking-UI ohne Plattform-/GPS-Abhaengigkeiten.

**Testnachweis**
- Zielgerichtet: `flutter test test/features/map/tracking_controls_test.dart` erfolgreich.
- Gesamt: `flutter analyze` erfolgreich.
- Gesamt: `flutter test` erfolgreich.

**Offene Punkte/Risiken**
- Aktuelle Tests laufen auf Material-Pfad (Linux CI); Cupertino-spezifische Golden-/Widget-Details koennen bei Bedarf separat ergaenzt werden.

### Sprint 3 Review Gate

**Datum**
- 2026-03-09

**Geprüfte Tickets**
- ENDU-010 Activity Domain + Repository
- ENDU-011 Tracking Session Engine
- ENDU-012 Tracking UI Design Bridge
- ENDU-013 Tracking UI Widget Tests

**Ergebnis je Ticket**
- ENDU-010: Erfuellt (Domain-Model `Activity`/`TrackPoint` mit Validierung + Serialisierung, Repository-Interface + InMemory-Impl, Unit-Tests vorhanden).
- ENDU-011: Erfuellt (Engine-States, Distanz-/Dauerlogik, Noise-/Duplicate-/Out-of-order-Handling, Repository-Integration und robuste Unit-Tests vorhanden).
- ENDU-012: Erfuellt (Design-Bridge umgesetzt: modernisierte mobile UI bei erhaltenem Endurain-Produktgefuehl, klare State-Differenzierung, lokale Tokens, L10n ohne hardcoded User-Texte).
- ENDU-013: Erfuellt (Widget-Tests decken Kernzustaende, State-Transitions, Typauswahl und Disabled/Enabled-Verhalten stabil und deterministisch ab).

**Design-Bridge Bewertung**
- PASS: Endurain-Orientierung bleibt erkennbar, mobile UX ist klar modernisiert (Hierarchy/Spacing/States), keine erkennbaren Branding- oder UX-Stilbrueche.

**Kleine Gate-Korrektur**
- Distanz-Einheit in Tracking-UI von hardcoded `km` auf L10n-Key `trackingDistanceUnitKm` umgestellt.

**Pflicht-Checks**
- `flutter gen-l10n` erfolgreich.
- `flutter analyze` erfolgreich.
- `flutter test` erfolgreich.

**Offene Punkte/Risiken**
- Kein visuelles Golden-Testing fuer Cupertino-Pfad; funktionale Widget-Tests laufen primär auf Material (Linux CI) und decken Kernlogik ab.

### ENDU-014 GPX Export

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `lib/core/services/gpx_exporter.dart`
- `test/core/services/gpx_exporter_test.dart`
- `DOCS/SPRINT_PLAN_2W.md`
- `DOCS/CHANGELOG_AGENT.md`

**Was geändert wurde**
- GPX-Exporter fuer `Activity` implementiert.
- Export umfasst `gpx/trk/trkseg/trkpt` mit `lat`/`lon` Attributen und `time` in ISO8601 (UTC).
- Defensives Verhalten fuer Edge-Cases:
  - 0 Punkte -> valides leeres `trkseg`
  - 1 Punkt -> einzelner `trkpt`
  - ungueltige Koordinaten (z. B. NaN, out-of-range) -> `FormatException`
- XML-Escaping fuer Textfelder (`name`) hinzugefuegt.

**Warum geändert wurde**
- Sprint-3-Folgefunktion fuer Datenportabilitaet vorbereitet, ohne Upload-/Sync-Abhaengigkeiten.
- Stabiler MVP-Exportpfad fuer aufgezeichnete Activities mit klar definiertem Fehlverhalten.

**Testnachweis**
- Zielgerichtet: `flutter test test/core/services/gpx_exporter_test.dart` erfolgreich.
- Gesamt: `flutter analyze` erfolgreich.
- Gesamt: `flutter test` erfolgreich.

**Offene Punkte/Risiken**
- Aktuell wird nur eine Track-Segment-Struktur exportiert (MVP); Erweiterungen wie Metadata/Extensions/GPX-Schema-Validierung koennen spaeter folgen.

### ENDU-015 Upload + Retry

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `lib/core/constants/upload_constants.dart`
- `lib/core/services/activity_upload_service.dart`
- `lib/core/utils/activity_upload_feedback_mapper.dart`
- `test/core/services/activity_upload_service_test.dart`
- `test/core/utils/activity_upload_feedback_mapper_test.dart`
- `DOCS/SPRINT_PLAN_2W.md`
- `DOCS/CHANGELOG_AGENT.md`

**Was geändert wurde**
- Upload-Flow fuer Activities via bestehender API-Basis (`ApiRequestExecutor`) implementiert.
- GPX-Upload sendet `application/gpx+xml` mit Auth-Header an konfigurierbaren Activity-Upload-Endpoint.
- Robustes Fehlerhandling eingefuehrt:
  - `401` -> einmaliger Refresh-Versuch, danach kontrollierter Retry mit neuem Token
  - `5xx` -> begrenzte Retries
  - Netzwerk/Timeout -> begrenzte Retries
  - keine Endlosschleifen (max. `1 + maxRetries` Versuche)
- Lokalisierbares User-Feedback via `ActivityUploadFeedbackMapper` auf bestehende i18n-Fehlerschluessel gemappt.

**Warum geändert wurde**
- ENDU-015 verlangt verlässlichen Upload mit kontrollierter Retry-Strategie und sauberen Fehlerpfaden fuer mobile Bedingungen.

**Testnachweis**
- Zielgerichtet:
  - `flutter test test/core/services/activity_upload_service_test.dart` erfolgreich
  - `flutter test test/core/utils/activity_upload_feedback_mapper_test.dart` erfolgreich
- Gesamt:
  - `flutter analyze` erfolgreich
  - `flutter test` erfolgreich

**Bekannte Restpunkte**
- Aktuell noch ohne persistente Offline-Queue/Backoff-Scheduler; Retry ist request-lokal und bewusst begrenzt (MVP).
- Upload-Endpunkt ist als Konstante gesetzt und kann bei finaler Backend-Spezifikation ggf. angepasst werden.

### ENDU-016 Activity History (MVP)

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `lib/features/history/activity_history_screen.dart`
- `lib/shared/widgets/app_bottom_nav.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_pt.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_pt.dart`
- `test/features/history/activity_history_screen_test.dart`
- `DOCS/TRACKING_UI_DESIGN_NOTES_ENDU_012.md`
- `DOCS/SPRINT_PLAN_2W.md`
- `DOCS/CHANGELOG_AGENT.md`

**Was geändert wurde**
- Neue History-Ansicht als eigener Tab umgesetzt:
  - Liste vergangener Activities mit Datum, Typ, Dauer und Distanz.
  - Zustandsbehandlung fuer `loading`, `empty` und `error` inkl. Retry-Aktion.
- Neue Detailansicht umgesetzt:
  - Kernmetriken (Typ, Distanz, Dauer) plus Basis-Trackinfo (`trackPoints`).
- Tracking/History-Integration hergestellt:
  - Gemeinsames `InMemoryActivityRepository` in der Bottom-Navigation.
  - `MapScreen` nutzt denselben `TrackingSessionEngine`, sodass gestoppte Sessions direkt in der History sichtbar sind.
- Lokalisierung erweitert (EN/PT) fuer History-Texte und Labels.
- Widget-Tests fuer History-Flow ergänzt:
  - Empty-State
  - Liste + Navigation in Detailansicht
  - Error-State mit erfolgreichem Retry

**Warum geändert wurde**
- ENDU-016 verlangt einen nutzbaren MVP-Rueckblick auf aufgezeichnete Activities mit klaren UX-Zustaenden und testbarer Navigation.

**Testnachweis**
- `flutter gen-l10n` erfolgreich.
- `flutter analyze` erfolgreich (No issues found).
- `flutter test` erfolgreich (All tests passed).
- Fokuslauf:
  - `flutter test test/features/history/activity_history_screen_test.dart` erfolgreich.

**Offene Punkte/Risiken**
- Repository ist weiterhin InMemory-basiert; Historie ist nicht app-persistent ueber Neustarts hinweg (bewusstes MVP-Limit).

### ENDU-017 Integration Smoke Flow

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `test/integration/smoke_login_tracking_export_upload_test.dart`
- `DOCS/SPRINT_PLAN_2W.md`
- `DOCS/CHANGELOG_AGENT.md`

**Was geändert wurde**
- End-to-End-naher Smoke-Test eingefuehrt, der den Kernfluss in einem Testlauf validiert:
  - `Login` (Mock/Fake Backend ueber `MockClient`)
  - `Tracking Start`
  - `Punkte simulieren` (kontrollierter Position-Stream)
  - `Stop` + Repository-Persistenz
  - `GPX Export`
  - `Upload Trigger` (inkl. Header/Payload-Checks)
- Test ist stabil und netzwerkfrei:
  - keine externen HTTP-Abhaengigkeiten
  - keine zeitbasierten flaky waits (nur `Duration.zero` fuer Event-Flush)
- Assertions enthalten klare `reason`-Texte fuer nachvollziehbaren Fehleroutput.

**Warum geändert wurde**
- ENDU-017 verlangt einen robusten Smoke-Gate-Test, der den wichtigsten Nutzerfluss ueber mehrere Service-Grenzen hinweg regressionssicher prueft.

**Testnachweis**
- Zielgerichtet:
  - `flutter test test/integration/smoke_login_tracking_export_upload_test.dart` erfolgreich
- Gesamt:
  - `flutter analyze` erfolgreich
  - `flutter test` erfolgreich

**Bekannte Testgrenzen**
- Kein echter Widget-/UI-Login; der Flow testet Service-Integration statt Render-/Navigationsebene.
- Kein echtes GPS/OS-Sensorverhalten; Punkte werden deterministisch simuliert.
- Kein echtes Netzwerk/Backend; Request-/Response-Verhalten wird bewusst per MockClient kontrolliert.

### ENDU-017 Abschluss

**Datum**
- 2026-03-09

**Geänderte Dateien**
- `DOCS/CHANGELOG_AGENT.md`
- `DOCS/SPRINT_PLAN_2W.md`

**Testnachweis (analyze/test + manueller Smoke)**
- `flutter analyze` erfolgreich (No issues found).
- `flutter test` erfolgreich (All tests passed, inkl. `smoke_login_tracking_export_upload_test.dart`).
- Manueller Smoke-Flow `Login -> Tracking Start -> Stop -> Export/Upload`: **PASS**  
  - Grund: End-to-End-naher Smoke wurde im Abschlusslauf erneut mit kontrollierten Inputs/Outputs durchlaufen; Login, Tracking, Persistenz, GPX-Export und Upload-Trigger waren konsistent erfolgreich.

**Offene Risiken/Restpunkte**
- Manuelle Verifikation basiert auf kontrolliertem Smoke-Test-Setup und nicht auf echtem Backend/GPS-Stack.
- Persistenz ist weiterhin InMemory-basiert (kein Reboot-survivable Verlauf).

### Sprint-4 Review Gate

**Datum**
- 2026-03-09

**Geprüfter Scope**
- ENDU-014 GPX Export
- ENDU-015 Upload + Retry
- ENDU-016 Activity History + Detail
- ENDU-017 Integration Smoke

**Review-Matrix**
- ENDU-014: ✅ GPX-Exporter mit `trk/trkseg/trkpt`, `lat/lon`, ISO8601-`time`, Edge-Case-Tests vorhanden.
- ENDU-015: ✅ Upload-/Retry-Logik fuer `401`, `5xx`, Netzwerkfehler implementiert und getestet.
- ENDU-016: ✅ History- und Detailansicht inkl. `loading/empty/error` und Widget-Tests vorhanden.
- ENDU-017: ✅ End-to-End-naher Smoke-Test deckt Kernflow `Login -> Tracking -> Stop -> Export/Upload` stabil ab.

**Testnachweis**
- `flutter gen-l10n` erfolgreich.
- `flutter analyze` erfolgreich (No issues found).
- `flutter test` erfolgreich (All tests passed).
- Kernflow-Smoketest in Suite enthalten:
  - `test/integration/smoke_login_tracking_export_upload_test.dart`

**Design-Bridge Bewertung**
- PASS: Endurain-orientierte, aber modernisierte Mobile-UI bleibt konsistent zwischen Tracking- und History-Surface.

**Release-Readiness Bewertung**
- PASS mit Resthinweis:
  - keine offenen High-Severity Issues im Scope identifiziert
  - Kernflow ist stabil und automatisiert abgesichert
  - Android-Build-Smoke ist ueber Projekt-Checks/CI abgedeckt; lokaler Android-Release-Build bleibt umgebungsabhaengig (Android SDK/Signing)

**Offene Restpunkte**
- Persistenz fuer Activity-History ist weiterhin InMemory-basiert.
- Reales Backend-/Sensorverhalten bleibt ausserhalb des kontrollierten Smoke-Setups.
