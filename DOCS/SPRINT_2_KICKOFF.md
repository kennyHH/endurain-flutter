# Sprint 2 Kickoff (ENDU-006 bis ENDU-009)

Datum: 2026-03-09

## Ziel

Strukturierter technischer Start fuer Sprint 2 mit inkrementeller Umsetzung ohne Big-Bang-Refactor.

## Reihenfolge, Abhaengigkeiten, Risiken

1. ENDU-006 (API-Schicht konsolidieren, Start)
   - Abhaengigkeit: keine
   - Risiko: unbeabsichtigte API-Verhaltensaenderungen bei Headern/URL-Building
2. ENDU-007 (Dependency Injection einfuehren, Start)
   - Abhaengigkeit: keine harte, profitiert aber von 006
   - Risiko: UI-Konstruktoren brechen bei Signaturaenderungen
3. ENDU-008 (Service-Testpaket erweitern, Skeletons)
   - Abhaengigkeit: Testbarkeit der Services (DI fuer HTTP/Storage) hilfreich
   - Risiko: instabile Tests durch echte Plattform-/Netzwerkpfade
4. ENDU-009 (Android Release-Konfig, Gap-Analyse)
   - Abhaengigkeit: keine
   - Risiko: versehentliche Produktionsnutzung von Debug-Signing

## Ticket-Plan

### ENDU-006 - API-Schicht konsolidieren

**Ist-Zustand**
- `AuthService`, `SsoService`, `ServerSettingsService` verwenden verteilte `http.*`-Aufrufe.
- `ApiClient` existiert, ist aber fuer authentifizierte Requests fokussiert und wird nicht breit genutzt.

**Scope (in)**
- Kleine zentrale Public-API-Struktur vorbereiten (unauthenticated GET/POST mit einheitlichen Headern).
- Mindestens ein Service nutzt diese Struktur.

**Scope (out)**
- Kein Full-Refactor aller Services.
- Keine API-Verhaltensaenderung.

**Betroffene Dateien**
- `lib/core/services/public_api_client.dart` (neu)
- `lib/core/services/server_settings_service.dart` (Startintegration)
- optional Folgeschritte fuer `sso_service.dart` in spaeteren Tasks

**Akzeptanzkriterien**
- Zentrale Public-Request-Struktur vorhanden.
- Mindestens ein Service verwendet sie.

**Teststrategie**
- Unit-Test-Skeleton fuer betroffenen Service.
- Regression ueber `flutter analyze` + `flutter test`.

### ENDU-007 - Dependency Injection einfuehren

**Ist-Zustand**
- Kernscreen `LoginScreen` erzeugt Services hart intern.

**Scope (in)**
- Constructor Injection fuer mindestens einen UI-Entrypoint (hier: `LoginScreen`) fuer `AuthService`, `SsoService`, `ServerSettingsService`.

**Scope (out)**
- Kein globales DI-Framework.
- Kein Umbau aller Screens.

**Betroffene Dateien**
- `lib/features/auth/login_screen.dart`

**Akzeptanzkriterien**
- UI-Entrypoint nicht mehr hart gekoppelt.
- Defaults bleiben rueckwaertskompatibel.

**Teststrategie**
- Bestehende Tests duerfen nicht regressieren.
- Neue Service-Tests nutzen injizierbare Abhaengigkeiten.

### ENDU-008 - Service-Testpaket erweitern

**Ist-Zustand**
- `AuthService` und mehrere Utility-Tests existieren.
- Fuer `SsoService` und `ServerSettingsService` fehlen dedizierte Tests.

**Scope (in)**
- Test-Skeletons fuer:
  - `SsoService`
  - `ServerSettingsService`
  - `Validators` (Sprint-2 Erweiterungs-Skeleton)
- Lauffaehige, deterministische Basis mit klarer Arrange/Act/Assert-Struktur.

**Scope (out)**
- Noch keine vollstaendige Abdeckung aller Edge-Cases.

**Betroffene Dateien**
- `test/core/services/sso_service_test.dart` (neu)
- `test/core/services/server_settings_service_test.dart` (neu)
- `test/core/utils/validators_sprint2_test.dart` (neu)

**Akzeptanzkriterien**
- Skeleton-Dateien vorhanden und testbar.
- Keine echten Netzwerke in Unit-Tests.

**Teststrategie**
- Mock/Fake-Ansatz fuer HTTP/Storage.
- `flutter test` muss gruen bleiben.

### ENDU-009 - Android Release-Konfiguration bereinigen

**Ist-Zustand**
- `android/app/build.gradle.kts` nutzt im Release aktuell Debug-Signing.

**Scope (in)**
- Dokumentierte Gap-Analyse + sichere Empfehlung (keine Secrets committen, Signing ueber `key.properties`/CI-Secrets).

**Scope (out)**
- Kein finales Produktionssigning in diesem Kickoff.

**Betroffene Dateien**
- `android/app/build.gradle.kts` (Analyse, ggf. spaeterer Fix)
- `DOCS/SPRINT_2_KICKOFF.md` (Gap-Doku)

**Akzeptanzkriterien**
- Release-Signing-Luecken klar benannt.
- Sichere ToDos festgelegt.

**Teststrategie**
- `flutter analyze` + `flutter test`.
- Spaeter: Dry-Run Release Build mit dokumentiertem Signing-Setup.

## ENDU-009 Gap-Analyse (konkret)

- Aktueller Gap: `release` verwendet `signingConfigs.debug`.
- Risiko: unbeabsichtigte Verteilung mit Debug-Key.
- Sichere Empfehlung:
  1. Release-Signing nur ueber `key.properties` + lokales Secret-File oder CI-Secrets.
  2. `key.properties` in `.gitignore` halten.
  3. CI-Checks fuer Release-Build nur mit gesetzten Signier-Variablen aktivieren.
  4. Dokumentierter Dry-Run (`flutter build apk --release`) mit sicheren Defaults.

## Testplan Sprint-2 Kickoff

- Pflicht:
  - `flutter gen-l10n` (falls i18n geaendert)
  - `flutter analyze`
  - `flutter test`
- Ziel fuer naechste Iteration:
  - Service-spezifische Tests je Ticket vertiefen (Sso/ServerSettings/Validators Branch-Cases).
