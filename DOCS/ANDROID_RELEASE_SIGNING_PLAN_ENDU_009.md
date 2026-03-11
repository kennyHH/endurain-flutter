# ENDU-009 Android Release Signing Plan

Datum: 2026-03-09

## Current state

- `android/app/build.gradle.kts` hat `release` bisher implizit mit `debug` signiert.
- Dadurch bestand das Risiko, dass ein Release-Artefakt mit Debug-Key erzeugt/verwendet wird.
- `android/.gitignore` enthielt bereits Schutzregeln fuer `key.properties` und Keystore-Dateien, aber die Build-Strategie war noch nicht fail-safe.
- Es gab keine dedizierte Setup-Doku fuer reproduzierbares, lokales Release-Signing ohne Secrets im Repo.

## Risiken im Ausgangszustand

- Unsicherer Produktivdefault (Debug-Signing im Release-Build).
- Unklare Developer-Experience fuer Release-Setup (fehlende Schritt-fuer-Schritt-Anleitung).
- Erhoehte Wahrscheinlichkeit fuer lokale Fehlkonfigurationen.

## Zielbild (sicherer Default)

- Release-Signing wird nur aktiviert, wenn `android/key.properties` und referenzierte Keystore-Datei vorhanden sind.
- Ohne Signing-Setup failt ein angeforderter Release-Task mit klarer Fehlermeldung.
- Optionaler Debug-Fallback ist nur explizit per Flag moeglich (`-PallowDebugSigningForLocalRelease=true`) und ausschliesslich fuer lokale Diagnose.
- Keine Secrets in Versionskontrolle, stattdessen lokales Setup via Dokumentation + Template.

## Umsetzungsartefakte

- Sichere Gradle-Konfiguration in `android/app/build.gradle.kts`
- Gitignore-Verstaerkung in `android/.gitignore`
- Setup-Doku: `DOCS/ANDROID_RELEASE_SIGNING.md`
- Optionales Template ohne Secrets: `android/key.properties.example`
