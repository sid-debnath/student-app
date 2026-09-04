# Brand packs

Each customer / institution gets its own folder here (`brands/<id>/`). A **brand
pack** is the set of images + metadata that one build ships. The app runs **one
active brand at a time** — the pack that has been copied into `assets/branding/`.

## Available brands

| Brand id | Display name | Notes |
|----------|--------------|-------|
| `default` | Student App | Demo brand — currently the active one |
| `_template` | Your Institution | Starter pack — copy it to create a new brand |

The **active** brand (the one the next build ships) is the `id` recorded in
`assets/branding/brand.json`.

## Folder layout

```
brands/
  _template/          ← copy this to start a new brand
    brand.json
    logo.png
    background.png
    app_icon.png
    splash.png
  default/            ← the demo brand ("Student App")
  <your_institution>/ ← a customer's pack
```

## Files (exact names are required)

| File | Purpose | Size | Aspect |
|------|---------|------|--------|
| `brand.json` | Display name, tagline, primary color (`#RRGGBB`), asset file names | — | — |
| `logo.png` | In-app logo (login + home header) | 1024×1024 | square |
| `background.png` | Login screen backdrop | 1024×1536 | 2:3 portrait |
| `app_icon.png` | Android / iOS / web launcher icon | 1024×1024 | square, no rounded-rect frame |
| `splash.png` | Native + web launch screen image | 1024×1024 | square |

> `flutter_launcher_icons` and `flutter_native_splash` downscale these to every
> platform size, so always supply the largest (1024) source. The filenames above
> are what the tools and code expect — keep them exact.

## `brand.json`

```json
{
  "id": "your_institution",
  "displayName": "Your Institution",
  "tagline": "A short one-liner.",
  "primaryColor": "#0F6A8A",
  "logo": "logo.png",
  "background": "background.png",
  "appIcon": "app_icon.png",
  "splash": "splash.png"
}
```

Optional (production / remote overrides, applied after login): `logoUrl`,
`backgroundUrl`.

## Add a new brand

```bash
cp -R brands/_template brands/<customer_id>
# replace the placeholder PNGs with the customer's artwork,
# then edit brands/<customer_id>/brand.json
dart run tool/apply_brand.dart <customer_id>
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

- `apply_brand.dart` copies the pack into `assets/branding/` and writes the
  display name + primary color into the platform metadata and the
  `flutter_native_splash` color in `pubspec.yaml`.
- `flutter_native_splash:create` rebuilds the native/web splash.
- `flutter_launcher_icons` rebuilds the launcher icon.

## Build for a specific brand

```bash
# 1. Make the brand active
dart run tool/apply_brand.dart <id>

# 2. Regenerate the platform art
dart run flutter_native_splash:create
dart run flutter_launcher_icons

# 3. Build (no-cost edition is the default)
flutter build web   # or: flutter build apk / flutter build ios

# Production / Blaze edition:
flutter build web --dart-define=APP_EDITION=production
```

The Firebase project and the Android `applicationId` / iOS bundle ID are
separate from the brand pack — see `README.md` → "New customer onboarding" and
`AGENTS.md`.

## What NOT to edit by hand

These are **generated** by the commands above. Edit the source files in
`brands/<id>/` instead, then re-run the commands:

- `assets/branding/` (the active copy)
- `android/app/src/main/res/drawable-*`, `values-v31/`, `values-night-v31/`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset`,
  `LaunchBackground.imageset`, `AppIcon.appiconset`, and
  `Base.lproj/LaunchScreen.storyboard`
- `web/splash/`, `web/icons/`, `web/favicon.png`

## Switch back to the demo brand

```bash
dart run tool/apply_brand.dart default
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```
