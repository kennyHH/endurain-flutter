# Android Release Signing Setup

Diese Anleitung beschreibt ein sicheres, lokales Release-Signing fuer Android ohne Secrets im Repository.

## 1) Keystore lokal erzeugen

Beispiel (JKS):

```bash
keytool -genkeypair \
  -v \
  -storetype JKS \
  -keystore android/app/upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

Hinweis: Die abgefragten Passwoerter/Namen sind lokal und duerfen nicht committed werden.

## 2) `key.properties` lokal anlegen

Datei: `android/key.properties`

Inhalt:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=app/upload-keystore.jks
```

- `storeFile` ist relativ zum `android/` Verzeichnis.
- `key.properties` ist per `.gitignore` ausgeschlossen.

## 3) Erwartete Dateipfade

- `android/key.properties`
- `android/app/upload-keystore.jks` (oder eigener Pfad aus `storeFile`)

## 4) Release-Build lokal starten

```bash
flutter build apk --release
```

Optional fuer lokale Diagnose ohne produktives Signing (explizit, nicht default):

```bash
flutter build apk --release -- -PallowDebugSigningForLocalRelease=true
```

Nur fuer lokale Tests verwenden. Nicht fuer produktive Artefakte.

## 5) Typische Fehler & Troubleshooting

- **Fehler:** `Release signing is not configured ...`
  - Ursache: `android/key.properties` fehlt oder ist unvollstaendig, oder Keystore-Pfad existiert nicht.
  - Fix: Datei erstellen, Werte pruefen, Keystore-Pfad verifizieren.

- **Fehler:** `Keystore was tampered with, or password was incorrect`
  - Ursache: Falsches `storePassword`/`keyPassword`.
  - Fix: Passwoerter in `key.properties` korrigieren.

- **Fehler:** `Cannot find key with alias ...`
  - Ursache: `keyAlias` passt nicht zum Keystore.
  - Fix: Alias aus Keystore mit `keytool -list -v -keystore <file>` pruefen.

## 6) Sicherheitsregeln

- Niemals `key.properties`, `.jks` oder `.keystore` ins Repo committen.
- Keine Signatur-Passwoerter in Klartext-Doku, Code, CI-Logs oder Screenshots.
- Fuer CI nur Secret-Variablen/Secret-Files nutzen.
