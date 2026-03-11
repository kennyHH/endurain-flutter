# Sprint 2 Review Gate (ENDU-006 bis ENDU-009)

Datum: 2026-03-09

## Review-Matrix

- ENDU-006 (API-Schicht): ✅  
  Zentrale API-Basis `ApiRequestExecutor` existiert und wird in `AuthService`, `SsoService`, `ServerSettingsService` und `ApiClient` genutzt; HTTP-Duplikate reduziert.
- ENDU-007 (DI): ✅  
  Mindestens zwei zentrale Screens DI-faehig (`LoginScreen`, `ServerSettingsScreen`) via Constructor-Injection mit kompatiblen Defaults; DI wird in Widget-Tests aktiv genutzt.
- ENDU-008 (Service-Testpaket): ✅  
  Unit-Tests fuer `SsoService`, `ServerSettingsService`, `Validators` vorhanden; deterministisch mit `MockClient`/Fakes ohne echte Netzwerkaufrufe.
- ENDU-009 (Android Release-Konfig): ✅  
  Kein stiller produktiver Debug-Signing-Default mehr; sichere Signing-Logik und lokale Setup-Doku vorhanden; keine Secrets im Repo.

## Pflicht-Checks

- `flutter gen-l10n`: erfolgreich.
- `flutter analyze`: erfolgreich (`No issues found`).
- `flutter test`: erfolgreich (`All tests passed`).
- `flutter build apk --release`: in dieser Umgebung nicht voll pruefbar, da Android SDK fehlt (`No Android SDK found`).

## DoD Sprint 2

- API-Duplikate reduziert / zentrale API-Logik sichtbar: erfuellt.
- DI in zentralen Screens eingefuehrt und testbar: erfuellt.
- Service-Tests erweitert und stabil (ohne Netzwerk): erfuellt.
- Android Release-Konfig sicher vorbereitet: erfuellt.

## Offene Restpunkte / Risiko

- Fuer End-to-End-Verifikation von Release-Artefakten fehlt in dieser Umgebung das Android SDK.
- Produktiver Release-Build erfordert lokal/CI bereitgestellte Signing-Secrets (`android/key.properties` + Keystore), wie dokumentiert.
