<div align="center">
  <img src="assets/logo/logo.png" width="128" height="128">

  # Endurain Mobile

  ![License](https://img.shields.io/github/license/endurain-project/endurain-flutter)
  [![GitHub release](https://img.shields.io/github/v/release/endurain-project/endurain-flutter)](https://github.com/endurain-project/endurain-flutter/releases)
  [![Trademark Policy](https://img.shields.io/badge/trademark-Endurain%E2%84%A2-blue)](TRADEMARK.md)

  **Mobile companion app for Endurain fitness tracking service**  
  Visit Endurain's [Mastodon profile](https://fosstodon.org/@endurain) and [Discord server](https://discord.gg/6VUjUq2uZR).

  <p>
    <i>Cross-platform mobile app for iOS, Android, and macOS</i>
  </p>
</div>

## Table of Contents

- [What is Endurain Mobile?](#what-is-endurain-mobile)
- [Current Features](#current-features)
- [Roadmap](#roadmap)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [SSO/OAuth Callback](#ssooauth-callback)
- [Development Workflow](#development-workflow)
- [Building from Source](#building-from-source)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)

## What is Endurain Mobile?

Endurain Mobile is the official companion app for [Endurain](https://github.com/endurain-project/endurain), a self-hosted fitness tracking service. Built with Flutter, it provides a native mobile experience for tracking your fitness activities while maintaining full control over your data.

The app is designed with privacy in mind, connecting directly to your self-hosted Endurain server without any third-party services or analytics.

## Current Features

✅ **Authentication**
- Secure login to your Endurain server with PKCE-backed token exchange
- SSO/OAuth support with PKCE (Authentik, Keycloak, Authelia, PocketID, Casdoor, etc.)
- Two-factor authentication (MFA) support
- Auto-redirect for single SSO provider configurations
- Server URL configuration with automatic settings detection
- Access-token refresh and local session restoration

✅ **Map Integration**
- Real-time location display on OpenStreetMap
- Location lock/unlock with visual indicators (filled/outline arrow icons)
- Auto-centering map when location is locked
- Configurable map tile server
- Directional compass heading indicator
- Platform-adaptive UI (Cupertino for iOS/macOS, Material for Android)

✅ **Activity Recording**
- Activity type selection for running, riding, walking, hiking, and other activities
- Start, pause, resume, stop, and discard recording controls directly on the map
- Live activity statistics for duration, distance, and speed
- GPS track capture with elapsed-time tracking across pauses and resumes
- Location permission and disabled-location error handling, including app settings shortcut
- Stop confirmation flow with discard option
- GPX 1.1 generation from completed tracks
- Upload status UI with retry/discard actions; upload transport is implemented behind configurable endpoint metadata and is not wired to a production API endpoint yet

✅ **Settings**
- Server configuration management
- Map tile server customization
- Logged-in server and username summary
- Session management with server-side logout attempt and secure local cleanup
- App version display

✅ **User Experience**
- Multi-language support (English, Portuguese)
- Dark/light theme support
- Secure local session storage
- F-Droid compatible (100% FOSS dependencies)
- Shared adaptive widget layer for Material and Cupertino controls
- Local SSO provider icon assets with remote icon fallback

## Roadmap

🚧 **Next Activity Milestones**
- Wire GPX upload to the finalized Endurain server activity import endpoint
- Add activity history and details views after recorded activity sync is available
- Expand activity statistics as server/mobile contracts mature

See the [Activity Tracking MVP Plan](devdocs/activity_tracking_mvp_plan.md) for implementation notes and remaining activity work.

## Tech Stack

- **Framework:** Flutter 3.38+ (Dart 3.10+)
- **Platforms:** iOS, Android, macOS
- **State Management:** Stateful widgets plus focused `ChangeNotifier` controllers
- **Map Provider:** OpenStreetMap with `flutter_map` 8.2.x and `latlong2`
- **Location Services:** `geolocator` 14.x, including position streams and movement heading
- **Secure Storage:** `flutter_secure_storage` 10.x
- **HTTP Client:** `http` package for Endurain API communication and multipart uploads
- **SSO/OAuth:** `app_links` for deep-link callbacks, `url_launcher` for system browser OAuth flow, `flutter_svg` for provider icons
- **App Metadata:** `package_info_plus`
- **Security:** `crypto` package for PKCE challenge generation
- **Localization:** Flutter gen-l10n from ARB files with English and Portuguese locales
- **Quality:** `flutter_lints` with strict casts, strict inference, strict raw types, and additional lint rules

**All dependencies are open-source (FOSS) to ensure F-Droid compatibility.**

## Getting Started

### Prerequisites

- Flutter SDK 3.38 or higher
- Dart SDK 3.10.3 or higher
- Xcode (for iOS/macOS development)
- Android Studio (for Android development)
- A running Endurain server instance

### Installation

1. Clone the repository:
```bash
git clone https://github.com/endurain-project/endurain-flutter.git
cd endurain-flutter
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate localization files:
```bash
flutter gen-l10n
```

4. Run the app:
```bash
# For iOS
flutter run -d ios

# For Android
flutter run -d android

# For macOS
flutter run -d macos
```

## SSO/OAuth Callback

SSO providers must redirect back to the app with this callback URL:

```text
endurain://auth/sso/callback
```

The callback currently expects a `session_id` query parameter, for example:

```text
endurain://auth/sso/callback?session_id=...
```

Register this callback URL in the Endurain server or identity provider configuration used for mobile SSO.

## Development Workflow

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Collect coverage and check a minimum line coverage threshold:

```bash
flutter test --coverage
dart run tool/check_coverage.dart --min-line-coverage 75 \
  --exclude "lib/l10n/app_localizations*.dart"
```

Regenerate localization classes after changing ARB files:

```bash
flutter gen-l10n
```

Localization source files live in `lib/l10n/app_en.arb` and `lib/l10n/app_pt.arb`. Every ARB entry must include resource attributes because `l10n.yaml` enables `required-resource-attributes`.

## Building from Source

### iOS

```bash
flutter build ios --release
```

### Android

```bash
flutter build apk --release
# or for App Bundle
flutter build appbundle --release
```

### macOS

```bash
flutter build macos --release
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # Root app widget
├── core/
│   ├── constants/            # App-wide constants (API, UI, map)
│   ├── models/               # Shared app models and exception types
│   ├── navigation/           # Route names
│   ├── services/             # API, auth, storage, links, location, package info
│   ├── theme/                # Theme configuration and tokens
│   └── utils/                # Validators, dialogs, error localization, platform helpers
├── features/
│   ├── activity/             # Recording controllers, models, services, and widgets
│   ├── auth/                 # Login, MFA, SSO, and session controllers
│   ├── map/                  # Map screen, map settings, and location state
│   └── settings/             # Settings and server configuration screens
├── shared/
│   ├── adaptive/             # Material/Cupertino adaptive components
│   └── widgets/              # Shared app widgets
└── l10n/                     # ARB files and generated localizations
test/
├── core/                     # Unit tests for services, models, and utilities
├── features/                 # Feature unit and widget tests
├── shared/                   # Adaptive widget tests
├── helpers/                  # Test fakes and widget harnesses
└── tool/                     # Tooling tests, including coverage checker tests
tool/
└── check_coverage.dart       # LCOV coverage threshold utility
```

## Contributing

Contributions are welcomed! This mobile app is part of the main Endurain project. Please:

1. Check the [Contributing Guidelines](CONTRIBUTING.md)
2. Open an issue to discuss changes before submitting a PR
3. Follow the existing code style and architecture patterns
4. Ensure all dependencies remain FOSS-compatible
5. Test on multiple platforms when possible

### Development Guidelines

- **Never hardcode strings** - use `AppLocalizations` (l10n)
- **Use constants** - avoid magic numbers, use files in `core/constants/`
- **Platform-adaptive UI** - use `PlatformUtils` for platform checks
- **Follow conventions** - see `.github/copilot-instructions.md`

## License

This project is licensed under the AGPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## Trademark Notice

Endurain® is a trademark of João Vitória Silva.  

You are welcome to self-host Endurain and use the name and logo, including for personal, educational, research, or community (non-commercial) use.  
Commercial use of the Endurain name or logos (such as offering paid hosting, products, or services) is **not permitted without prior written permission**.

See [`TRADEMARK.md`](TRADEMARK.md) for full details.

---

<div align="center">
  <sub>Built with ❤️ from Portugal | Part of the <a href="https://github.com/endurain-project">Endurain</a> ecosystem</sub>
</div>