# ENDU-007 DI Plan

Datum: 2026-03-09

## Aktueller Zustand (direkte Instanziierungen)

- `lib/features/auth/login_screen.dart`
  - instanziiert Services aktuell bereits mit Defaultinstanzen, bietet aber optionale Constructor-Injection.
- `lib/features/settings/server_settings_screen.dart`
  - instanziiert aktuell direkt:
    - `SecureStorageService`
    - `AuthService`
- `lib/features/map/map_screen.dart`
  - instanziiert aktuell direkt:
    - `LocationService`
    - `SecureStorageService`
  - bleibt fuer dieses Ticket out-of-scope (higher migration risk).

## Low-Risk Reihenfolge

1. `LoginScreen` validieren/absichern (bereits injizierbar, jetzt aktiv per Test genutzt)
2. `ServerSettingsScreen` injizierbar machen (Constructor Injection mit Defaults)
3. Ein Widget-Test mit injizierten Fakes fuer deterministisches Verhalten

## Testnutzen durch DI

- UI-Tests koennen Services faken, ohne echtes Netzwerk/Secure Storage.
- Fehler-/Erfolgspfade werden deterministisch und reproduzierbar.
- Keine Seiteneffekte durch externe Plattformabhaengigkeiten.

## Scope fuer ENDU-007

- Minimalistische Constructor-DI, keine Framework-Einfuehrung.
- Rueckwaertskompatible Defaults (Produktionsverhalten unveraendert).
- Fokus auf testbare Kernscreens statt globalem Umbau.
