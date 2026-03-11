# ENDU-008 Testplan (Service-Testpaket)

Datum: 2026-03-09

## Ziel

Stabile, deterministische Unit-Tests fuer `SsoService`, `ServerSettingsService` und `Validators` ohne echte Netzwerk- oder Plattformabhaengigkeiten.

## Mocks/Fakes

- HTTP: `MockClient` aus `package:http/testing.dart`
- Storage: testinterne `FakeSecureStorageService`-Ableitungen mit in-memory Feldern
- Keine echten WebView-/Timer-Abhaengigkeiten

## ServerSettingsService

**Methoden**
- `getServerSettings({String? serverUrl})`

**Erfolgspfad**
- 200-Response wird korrekt geparst
- optionale Tile-Felder werden bei Vorhandensein gespeichert

**Fehlerpfad**
- Nicht-200-Response fuehrt zu erwartetem Fehler
- fehlende/ungueltige (leer/nicht konfiguriert) `serverUrl` fuehrt zu Fehler

**Randfaelle**
- fehlende optionale Felder nutzen Modell-Defaults
- keine Side-Effects fuer optionale Felder, wenn diese nicht gesetzt sind

## SsoService

**Methoden**
- `getEnabledProviders({String? serverUrl})`
- `initiateOAuth(String idpSlug, {String? serverUrl})`
- `exchangeSessionForTokens(String sessionId)`

**Erfolgspfad**
- `getEnabledProviders`: Liste und Objektformat mit `providers` werden verarbeitet
- `initiateOAuth`: URL enthaelt PKCE `code_challenge`, `code_challenge_method=S256`, `redirect`
- `exchangeSessionForTokens`: Tokens werden gespeichert und Erfolg geliefert

**Fehlerpfad**
- `getEnabledProviders`: unerwartetes Response-Format
- `exchangeSessionForTokens`: Non-200 fuehrt zu Fehler

**Randfaelle**
- `exchangeSessionForTokens` ohne zuvor erzeugte PKCE-Daten -> definierter Fehler

## Validators

**Methoden**
- `validateRequired`
- `validateUrl`
- `validateServerUrl` (ENDU-002 Policy-Verhalten)

**Erfolgspfad**
- `validateRequired`: gefuellter Wert -> `null`
- `validateUrl`: gueltige HTTPS-URL -> `null`

**Fehlerpfad**
- `validateRequired`: `null`, leer, whitespace -> Fehler
- `validateUrl`: ungueltige URL -> Fehler
- `validateServerUrl`: `http://` -> HTTPS-Fehler

## Flake-Schutz

- Kein `Future.delayed` in Tests
- Keine Abhaengigkeit von global mutable State
- Jede Testgruppe nutzt eigene Fake-Instanzen
- Klare Arrange/Act/Assert-Struktur
