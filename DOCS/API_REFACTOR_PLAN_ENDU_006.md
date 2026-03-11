# ENDU-006 API Refactor Plan

Datum: 2026-03-09

## Current state

### Direkte HTTP-Aufrufe (Ist-Analyse)

- `lib/core/services/auth_service.dart`
  - nutzt direkte POST-Aufrufe fuer:
    - `/api/v1/auth/login`
    - `/api/v1/auth/mfa/verify`
    - `/api/v1/public/idp/session/{session_id}/tokens`
    - `/api/v1/auth/refresh`
    - `/api/v1/auth/logout`
  - Header je Call:
    - immer `X-Client-Type: mobile`
    - je nach Endpoint `Content-Type: application/json` oder `application/x-www-form-urlencoded`
    - Logout zusaetzlich `Authorization: Bearer <refresh_token>`

- `lib/core/services/sso_service.dart`
  - nutzt direkte GET/POST-Aufrufe fuer:
    - `/api/v1/public/idp`
    - `/api/v1/public/idp/session/{session_id}/tokens`
  - Header je Call:
    - `X-Client-Type: mobile`
    - bei POST zusaetzlich `Content-Type: application/json`

- `lib/core/services/server_settings_service.dart`
  - nutzt bereits `PublicApiClient.get()` fuer:
    - `/api/v1/public/server_settings`
  - Header:
    - `X-Client-Type: mobile`

- `lib/core/services/api_client.dart`
  - hat eigene interne Request-Engine (`_executeRequest`) mit GET/POST/PUT/DELETE
  - setzt Header:
    - `Authorization: Bearer <access_token>`
    - `X-Client-Type: mobile`
    - `Content-Type: application/json`
  - hat eigene 401-Retry-Logik via `AuthService.refreshToken()`

### Fehlerbehandlung (Ist)

- Services werfen aktuell viele rohe `Exception(...)` Strings.
- Netzwerk-/Timeoutbehandlung ist nicht zentralisiert.
- HTTP-Statusbehandlung ist je Service verteilt.
- `api_client.dart` hat eigene Retry-Semantik, andere Services nicht.

### Duplikate

- Wiederholtes Setzen von `X-Client-Type` in mehreren Services.
- Wiederholtes URL-Bauen (`Uri.parse('$serverUrl$endpoint')`).
- Wiederholte POST-Logik inkl. Header/Body-Encoding.

## Zielbild (fuer Umsetzung)

- Eine kleine zentrale Request-Basis fuer URL-Bau, Standardheader, Timeout und strukturierte Infrastrukturfehler.
- Inkrementelle Migration:
  1. ServerSettingsService (low risk)
  2. AuthService (schrittweise)
  3. SsoService
  4. ApiClient interne Duplikate reduzieren

## Final design

### Zentrale API-Basis

- Neue zentrale Komponente: `lib/core/services/api_request_executor.dart`
  - baut URL zentral: `buildUri(serverUrl, endpoint)`
  - setzt Standardheader zentral:
    - immer `X-Client-Type: mobile`
  - unterstuetzt Timeout (Default: 15s, optional pro Request)
  - liefert strukturierte Infrastrukturfehler:
    - `ApiRequestExceptionType.timeout`
    - `ApiRequestExceptionType.network`
    - `ApiRequestExceptionType.invalidRequest`

### Migrationsstand

- `ServerSettingsService`: auf `ApiRequestExecutor` migriert (GET ueber zentrale Basis).
- `AuthService`: wesentliche HTTP-Calls auf `ApiRequestExecutor` migriert:
  - login
  - verifyMfa
  - session token exchange
  - refresh token
  - logout
- `SsoService`: wesentliche HTTP-Calls auf `ApiRequestExecutor` migriert:
  - enabled providers (GET)
  - session token exchange (POST)
- `ApiClient`: interne `_executeRequest`-Duplikatlogik entfernt, Request-Pfade nutzen nun `ApiRequestExecutor`.

### Bewusst beibehalten (Stabilitaet)

- Service-spezifische Fachfehler und Rueckgabesemantik bleiben unveraendert (z. B. 401-Retry in `ApiClient`, spezifische Exception-Texte in Services).
- Multipart-Upload in `ApiClient.uploadFile()` bleibt als separater Spezialpfad bestehen.

### Test- und Sicherheitsaspekte

- Neue Unit-Tests fuer die API-Basis:
  - URL-Bau
  - Standardheader
  - Timeout-Fehlerpfad
- Migration wurde mit bestehenden Service-Tests validiert.
- Keine Secrets/Keys eingefuehrt, keine neuen ungesicherten Endpunkte.
