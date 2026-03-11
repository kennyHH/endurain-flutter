# Endurain Icon & Logo Guideline

This document defines the source-of-truth assets, export sizes, and update workflow for app icons and in-app logos.

## Source assets

- Master app icon: `assets/logo/app_icon_master_1024.png`
- Adaptive foreground: `assets/logo/app_icon_foreground.png`
- Adaptive monochrome: `assets/logo/app_icon_monochrome.png`
- In-app brand logo: `assets/logo/logo.png`

## Platform outputs

- Android launcher icons (generated): `android/app/src/main/res/mipmap-*`
- Android adaptive config (generated):
  - `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
  - `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml`
  - `android/app/src/main/res/mipmap-anydpi-v33/ic_launcher_monochrome.xml`
- iOS app icons (generated): `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`
- macOS app icons (generated): `macos/Runner/Assets.xcassets/AppIcon.appiconset/*`

## Safe zone and visual balance

- Keep primary glyph inside the center 72% of canvas to survive rounded masks.
- Avoid tiny details near corners; they get clipped on Android launchers.
- Monochrome icon must preserve silhouette clarity at small sizes.
- Keep contrast high between glyph and background.

## Do / Don't

- Do keep one canonical master icon and regenerate outputs.
- Do keep icon geometry consistent across colored and monochrome variants.
- Do test launcher icon on Android dark/light and themed icon mode.
- Don't edit generated `mipmap-*` or AppIcon files manually.
- Don't swap logo files ad-hoc without re-running generator.

## Update process

1. Replace source assets in `assets/logo/`.
2. Verify `flutter_launcher_icons` config in `pubspec.yaml`.
3. Run:
   - `flutter pub run flutter_launcher_icons`
4. Validate:
   - Android: launcher icon, themed icon, splash transition
   - iOS: home-screen icon
   - macOS: dock icon
5. Build and smoke-test:
   - `flutter build apk --debug --target-platform android-arm64`

## In-app usage

- Use `BrandLogo` (`lib/shared/widgets/brand_logo.dart`) in UI instead of raw `Image.asset(...)`.
- Prefer semantic labels for accessibility.
