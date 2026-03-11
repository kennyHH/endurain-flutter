# Endurain Flutter - Vollstaendige Projektanalyse

Stand: 2026-03-09  
Repository: `endurain-flutter`

## 1. Projektueberblick

- **Zweck:** Mobile Companion App fuer Endurain (self-hosted Fitness Tracking) mit Fokus auf Datenschutz und FOSS.
- **Hauptfeatures:**
  - Login mit Username/Passwort
  - MFA-Unterstuetzung
  - SSO/OAuth mit PKCE
  - Kartenansicht (OpenStreetMap) mit Live-Position + Kompass
  - Server-/Tile-Settings und Logout
  - i18n (EN/PT), Dark/Light Theme
- **Zielgruppe:** Privacy-orientierte Nutzer:innen mit eigenem Endurain-Server.

## 2. Tech-Stack Analyse

| Bereich | Stack/Befund |
|---|---|
| Framework | Flutter (>= 3.38.4 laut lockfile) |
| Sprache | Dart 3.10.x |
| Plattformen | Android, iOS, macOS |
| State Management | `setState` |
| Networking | `http` |
| Storage | `flutter_secure_storage` |
| Auth | Passwort + MFA + SSO/OAuth (PKCE) |
| Map/GPS | `flutter_map`, `latlong2`, `geolocator`, `flutter_compass` |
| WebView | `webview_flutter` |
| i18n | ARB + `flutter_localizations` |
| Tests | `flutter_test` (aktuell minimal) |
| Linting | `flutter_lints` + striktere Analyzer-Regeln |
| CI/CD | Keine `.github/workflows` vorhanden |
| Build | Gradle Kotlin DSL (Android), CocoaPods (iOS/macOS) |

### Wichtige Build-Konfigurationsbefunde

- `android/app/build.gradle.kts`: Release nutzt aktuell Debug-Signing (TODO).
- Keine CI-Pipeline fuer Analyze/Test/Build.
- Kein `tool/`-Ordner, keine Build-Skripte/Fastlane/Makefile.

## 3. Architektur Analyse

### Struktur

- `lib/core`: constants, services, utils, theme
- `lib/features`: auth, map, settings
- `lib/shared`: gemeinsame Widgets

### Bewertung

- **Wartbarkeit:** mittel (bei aktuellem Umfang okay).
- **Skalierbarkeit:** mittel bis niedrig ohne Architekturupgrade.
- **Clean Architecture:** teilweise; Ordnerstruktur gut, Layer-Trennung unvollstaendig.
- **SOLID:** nur teilweise; starke Kopplung UI <-> konkrete Services.

## 4. Code Quality Review

### Positiv

- Konsistente Benennung/Dateistruktur.
- Viele zentrale Konstanten.
- Lokalisierung sauber etabliert.

### Auffaellige Punkte

- Duplizierte HTTP-Logik in mehreren Services.
- `ApiClient` existiert, wird aber nicht im restlichen Code genutzt.
- Harte UI-Verzweigung Cupertino/Material fuehrt zu Wartungsduplikation.
- Fragiler Test (`test/widget_test.dart`) mit Sprach-Textabhaengigkeiten.

## 5. Security Analyse

### Befunde

- Keine offensichtlichen API Keys/Secrets im Repo.
- Token liegen in Secure Storage (gut).
- PKCE-Flow implementiert (gut).
- URL-Validierung erlaubt auch `http` (kein HTTPS-Zwang).
- WebView mit `JavaScriptMode.unrestricted` und ohne strikte Host-Allowlist.
- Teilweise direkte Ausgabe technischer Fehlermeldungen im UI.

### Empfehlungen

1. HTTPS in Release erzwingen.
2. Host-Allowlist fuer SSO-WebView umsetzen.
3. Fehler-Mapping einfuehren (keine Roh-Exceptions im UI).
4. Token-Lifecycle und Logout-Contract dokumentieren/vereinheitlichen.
5. Sicherheitschecks in CI integrieren.

## 6. Performance Analyse

- Hauefige Rebuilds in `MapScreen` durch Kompass-/Positionsupdates.
- Kein einheitliches Timeout/Retry/Backoff fuer HTTP.
- Kaum Caching ausser Tile-URL.
- Streams werden korrekt disposed (positiv).

## 7. Testing Analyse

- Nur 1 Widget-Test vorhanden.
- Keine Unit-Tests fuer Core-Services.
- Keine Integrationstests/E2E.
- Testbarkeit durch direkte Service-Instanziierung eingeschraenkt.

## 8. Feature Analyse

### Vorhanden

- Auth, MFA, SSO
- Map + Location + Heading
- Basic Settings

### Geplant/halbfertig

- Activity Tracking (README: Coming Soon)
- `ApiClient.uploadFile(...)` deutet auf spaeteren GPX/Datei-Upload hin.
- `ServerSettings` modelliert mehr Felder als aktuell im UI genutzt.

## 9. Technical Debt

### High

- Fehlende CI/CD
- Sehr geringe Testabdeckung
- Security Hardening unvollstaendig (HTTPS/WebView/Error handling)
- Android Release Signing noch TODO

### Medium

- Keine klare Domain/UseCase/Repository-Schicht
- Doppelte HTTP-Implementierungen
- Enge Kopplung zwischen UI und Services

### Low

- UI-Duplikation Cupertino/Material
- Kleinere Naming-Inkonsistenzen

## 10. Roadmap (Phasen)

### Phase 1 - Stabilisierung

- CI fuer Analyze/Test/Build
- Security-Hardening (HTTPS, WebView-Allowlist, Error-Mapping)
- Erste Service-Unit-Tests

### Phase 2 - Architekturverbesserung

- API-Layer konsolidieren
- DI + besseres State Management (Provider/Riverpod)
- Testbarkeit der UI erhoehen

### Phase 3 - Feature Ausbau

- Activity Tracking MVP
- GPX Export/Upload
- Activity History + Details

### Phase 4 - Skalierung

- Performance-Tuning
- robuste Offline-Sync-Strategie
- erweiterte Contributor- und QA-Standards

## 11. Developer Task Breakdown (Kurzfassung)

| Task | Prioritaet | Aufwand |
|---|---|---|
| CI Pipeline aufsetzen | Hoch | 1-2 PT |
| HTTPS Enforcement | Hoch | 1 PT |
| SSO WebView Allowlist | Hoch | 2-3 PT |
| Auth Service Unit-Tests | Hoch | 2-3 PT |
| API-Layer vereinheitlichen | Mittel | 2-3 PT |
| DI + Testbarkeit verbessern | Hoch | 3-5 PT |
| Activity Tracking MVP | Hoch | 8-15 PT |

## 12. Verbesserungsstrategie

- Architektur inkrementell in Richtung Feature + Domain + Data ziehen.
- Einheitliche Netzwerkabstraktion einfuehren (Timeout/Retry/Error contract).
- State granularisieren (weniger globale Rebuilds).
- DX verbessern durch CI-Gates + klare lokale Commands.

## 13. Risikoanalyse

- **Technisch:** Skalierungsgrenze mit reinem `setState`.
- **Security:** WebView/Transport ohne volle Haertung.
- **Maintenance:** geringe Tests + fehlende CI.
- **Dependencies/Community:** F-Droid/FOSS-Auflagen reduzieren Auswahl, aber sind strategisch sinnvoll.

## 14. Executive Summary

- Projekt hat ein gutes Fundament und klare Produktvision.
- Hauptluecken liegen bei CI, Testabdeckung, Security-Hardening und Architektur fuer kommende Features.
- Groesste Chance: geordneter Ausbau Richtung Activity Tracking bei gleichzeitiger Qualitaetssicherung.
- Wichtigste naechste Schritte:
  1. CI + Testbasis
  2. Security-Hardening
  3. Architektur-Refactor vor groesseren Features

---

## Anhang: Vorgeschlagene 2-Wochen Sprintplanung

- Sprint 1: Stabilisierung + Security + Testfundament
- Sprint 2: API/DI Refactor + erweiterte Tests
- Sprint 3: Activity Tracking MVP Teil 1
- Sprint 4: GPX/Upload + History + E2E Smoke

