# Student management app

Flutter + Firebase. **One app**, two editions:

| Edition | How to run / ship | Google billing |
|---------|-------------------|----------------|
| **Spark (default)** | `flutter run -d chrome` | Free: Auth + Firestore only |
| **Production** | `flutter build web --dart-define=APP_EDITION=production` plus Blaze deploy | Functions, Storage, server FCM |

See `AGENTS.md` for architecture and the build/deploy switch (`lib/core/app_config.dart`).

Roles: **admin**, **teacher**, **viewer** (parent and student share viewer).

## No-cost setup

1. Email/password Auth and Firestore on project `student-mgmt-sdd2011-bddf7` (already done).
2. `flutter pub get && flutter run -d chrome`
3. **First-time setup** creates the institution admin.

Do **not** deploy Functions on Spark.

## Production (optional)

1. Upgrade the Firebase project to **Blaze** and set a budget alert.
2. Storage → Get started, then `firebase deploy --only storage,functions,firestore,hosting`
3. Build with `--dart-define=APP_EDITION=production`

The production client still falls back to the Spark client path if Functions/Storage are missing.

Admins add teachers and viewers from **More → Users**.

## New customer onboarding

This product is **white-label, one institution per deploy**. Each customer gets their own brand pack and (usually) their own Firebase project. Do not put multiple schools in one app unless product later adds a picker.

### 1. Brand pack

| File | Purpose | Suggested size |
|------|---------|----------------|
| `brand.json` | Display name, tagline, primary color (`#RRGGBB`) | — |
| `logo.png` | Login and home header | square, ~1024×1024, clear mark |
| `background.png` | Login backdrop | portrait, ~1080×1920 |
| `app_icon.png` | Store / home-screen icon | 1024×1024, no rounded-rect frame |
| `splash.png` | Native splash (can match icon) | 1024×1024 or larger |

`brand.json` fields: `id`, `displayName`, `tagline`, `primaryColor`, `logo`, `background`, `appIcon`, `splash`. Optional later: `logoUrl`, `backgroundUrl` (remote overlays).

```bash
cp -R brands/_template brands/<customer_id>
# add images + edit brands/<customer_id>/brand.json
dart run tool/apply_brand.dart <customer_id>
dart run flutter_launcher_icons
```

The running app **only** reads `assets/branding/` (the active copy). Keep customer source files in `brands/<customer_id>/`.

### 2. Firebase (Spark is enough to start)

1. Create a Firebase project for that customer (or reuse one while piloting).
2. Enable **Email/password** Auth and **Firestore**.
3. `firebase use <customer-project-id>`
4. `firebase deploy --only firestore` (rules + indexes).
5. Run `flutterfire configure` if the Android/iOS app IDs or project differ from this repo, then commit the generated `firebase_options.dart` / `google-services.json` / `GoogleService-Info.plist`.
6. `flutter run` (or ship an APK/IPA/web build).
7. In the app: **First-time setup** — creates `institutions/default`, the admin user, and a demo class/student.

Do **not** deploy Functions or Storage until they are on **Blaze**.

### 3. After go-live

- Admin adds teachers and viewers from **More → Users**.
- Bundled images are enough on Spark. On production, `institutions/default.branding` (`displayName`, `tagline`, `primaryColor`, `logoUrl`, `backgroundUrl`) can override look without a rebuild if Storage URLs are set.
- Store listings need a **unique** Android `applicationId` / iOS bundle ID per customer if they ship side by side; change those, then re-run FlutterFire. The demo IDs are `com.institution.student_app` / `com.institution.studentApp`.
