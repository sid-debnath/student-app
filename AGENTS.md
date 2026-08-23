# Student management app — agent context

Use this file as the source of truth for architecture, product decisions, and **two deployment editions** (no-cost Spark vs production Blaze). Prefer changing code to match this document unless the user explicitly changes the product.

## Product

Flutter app for attendance, homework, timetable, marks/report cards, announcements, and parent–teacher meetings (PTM). Intended for schools, colleges, and other educational institutions.

- **Roles:** `admin`, `teacher`, `viewer`
- **Viewer** is the shared parent **and** student UX (not a separate student role)
- **Tenancy:** one institution at `institutions/{institutionId}` with `institutionId` = `default` (`kDefaultInstitutionId` in `lib/core/constants.dart`)
- **White-label:** each customer build uses a brand pack under `brands/<id>/` copied to `assets/branding/` (`dart run tool/apply_brand.dart <id>`). Do not add a multi-institution picker unless asked.
- **Do not** add multi-institution tenancy unless asked

## Firebase project (current)

| Item | Value |
|------|--------|
| Project ID | `student-mgmt-sdd2011-bddf7` |
| Display name | `student-mgmt-sdd2011` |
| Auth | Email/password enabled |
| Firestore | Native `(default)`, region `asia-south1`, rules/indexes deployed |
| Storage | **Not created** (Get started in console still required for uploads) |
| Cloud Functions | **Not deployed** — Blaze/billing required |
| Plan | Spark (free) is enough for client Auth + Firestore |

Ignore older GCP project `student-mgmt-sdd2011` (incomplete). Always use `student-mgmt-sdd2011-bddf7`.

Client apps: Android `com.institution.student_app`, iOS `com.institution.studentApp`, plus web.

## Architecture

```
Flutter (lib/)  →  Firebase Auth
                →  Cloud Firestore  (source of truth for roles)
                →  Firebase Storage (planned; not live)
                →  FCM topic subscribe (client)
                →  Cloud Functions (production / Blaze only)
```

- **State:** `flutter_riverpod` 3.x (`lib/core/providers.dart`)
- **Routing:** `go_router` (`lib/core/router.dart`) — signed-in users without a Firestore profile stay on `/login`
- **Entry:** `lib/main.dart` — `Firebase.initializeApp(DefaultFirebaseOptions)`
- **Options:** `lib/firebase_options.dart` (generated; do not invent new keys)
- **Data access:** repositories in `lib/data/`, paths in `lib/data/paths.dart` (`InstitutionPaths`)
- **UI:** feature screens under `lib/features/`
- **Branding:** `lib/core/branding.dart` + `assets/branding/` (logo, background, app icon, splash). Optional Firestore `institutions/{id}.branding` overlays name/color/remote image URLs after login.

### Auth and roles (Spark path)

Roles live on `institutions/default/users/{uid}` (`role`, `institutionId`, `classIds`, `studentIds`). Security rules **must not** require Auth custom claims (`request.auth.token.role`) unless Functions are deployed again.

- **First-time setup:** create Auth user, then client batch-write institution + admin user + demo class/student (`AuthRepository.bootstrapInstitution`)
- **Create teacher/viewer:** secondary Firebase Auth app (`userAdmin`) so the admin session is not replaced (`AuthRepository.createInstitutionUser`)
- **Custom claims** exist only in unused `functions/index.js`; do not call those callables on Spark

### Firestore layout

Under `institutions/default/`:

| Collection | Purpose |
|------------|---------|
| `users` | Profiles: `admin` / `teacher` / `viewer` (`classIds`, `studentIds`) |
| `classes` | Class/section/year, `teacherIds` (`AcademicClass` in Dart) |
| `students` | Name, `classId`, `roll`, `viewerUids` |
| `attendance` | Per class-day |
| `homework` | Assignments |
| `timetable/{classId}/periods` | Weekly periods |
| `exams`, `marks`, `reportCards` | Assessments |
| `announcements` | Institution/class news |
| `ptmSlots`, `ptmBookings`, `ptmNotes` | PTM |

Rules: `firebase/firestore.rules`. Indexes: `firebase/firestore.indexes.json`. Deploy with `firebase deploy --only firestore`.

Bootstrap: signed-in user may **get** missing `institutions/default` and **create** institution + own admin user + demo class/student while that institution doc does not exist.

### Navigation (role tabs)

- **Admin:** Home, Roster, News, More (Users, Timetable, Exams, PTM, Homework, Attendance)
- **Teacher / viewer:** Home, Attendance, Homework, More (Timetable, Marks, Announcements, PTM)

## Features (implemented)

| Feature | Notes |
|---------|--------|
| Login / first-time setup | Email + password; setup creates institution |
| Roster | Classes and students (admin) |
| Users | Admin creates teachers/viewers and links class/student IDs |
| Attendance | Class-day marking |
| Homework | CRUD for staff; viewers read |
| Timetable | Weekly periods by class |
| Marks / report cards | Exams, subject marks, published snapshots |
| Announcements | Targeted to institution or class |
| PTM | Slots, viewer booking, notes/docs |
| FCM | Client stores token and subscribes to topics; **server send is production/Blaze only** |

## Deployment modes (required)

The app has **two supported editions**. Default for development and institution pilots is the **no-cost** edition. Production is a later upgrade, not a rewrite.

| Edition | Google billing | Goal |
|---------|----------------|------|
| **No-cost (Spark)** | Firebase Spark — no billing account | App must run end-to-end: Auth, Firestore CRUD, first-time setup, roster, attendance, homework, timetable, marks, announcements, PTM booking |
| **Production (Blaze)** | Pay-as-you-go / Blaze | Enterprise-style scale, availability, and extras: Cloud Functions, Storage, server FCM, App Check, backups, Hosting, store builds |

**Agent rule:** every feature must work on Spark unless the user is explicitly building the production edition. Do not add a hard dependency on Cloud Functions, Cloud Storage, or paid APIs for core institution workflows. Optional production services go behind “nice to have” paths that fail softly on Spark (e.g. skip FCM send, skip file upload if no bucket).

### No-cost edition (current default)

Must keep working:

- Email/password Auth
- Firestore as source of truth (including **roles on user documents**, not custom claims)
- Client bootstrap (`AuthRepository.bootstrapInstitution`) and client user create (`AuthRepository.createInstitutionUser` via secondary Auth app)
- All screens listed under Features
- Security rules that do not require `request.auth.token.role` / `institutionId` claims

Acceptable Spark limits:

- No Cloud Functions deploy
- No Storage bucket / file attachments (PTM notes can stay text-only)
- No server-side push; in-app Firestore listeners are enough
- No custom claims
- Regional Firestore only (`asia-south1`); no multi-region

### Production edition (pay-as-you-go)

Turn on when the institution needs reliability and scale. Same Flutter app; enable Google Cloud services on project `student-mgmt-sdd2011-bddf7`.

1. **Billing:** upgrade Firebase/GCP to **Blaze**. Set a **budget alert**.
2. **Cloud Functions:** `firebase deploy --only functions` for Admin SDK user create, custom claims, FCM send on writes. Then rules may optionally use claims; keep Firestore profile as fallback so Spark code paths still compile.
3. **Storage:** Console → Get started (prefer `asia-south1`), then `firebase deploy --only storage`. Use for PTM docs, homework files, report PDFs.
4. **Messaging:** Functions send to topics; iOS needs APNs key; Android needs Play/FCM setup.
5. **Availability / scale:** Firestore PITR and scheduled backups; consider multi-region later if SLA requires it; CDN via Firebase Hosting for web.
6. **Hardening:** App Check, authorized Auth domains, release SHA-1/256, App Store/Play signing, privacy policy, data-safety forms.
7. **Ops:** monitoring, error reporting, non-owner IAM roles (not a single personal Google account).

Do not require Blaze to *develop or demo* the product.

### How the Spark vs production switch is structured

This is **one Flutter app and one Git repo**, not two codebases. There is no second “production app.” Edition is selected at **build** time; paid Google services are selected at **Firebase deploy** time. Runtime still fails soft if a production binary talks to a Spark project.

```
                    ┌─────────────────────────────────────┐
                    │  Same source (lib/, firebase/,      │
                    │  functions/)                        │
                    └──────────────┬──────────────────────┘
                                   │
            ┌──────────────────────┴──────────────────────┐
            │                                             │
            ▼                                             ▼
   APP_EDITION=spark (default)                 APP_EDITION=production
   flutter run / build                         flutter build … --dart-define=APP_EDITION=production
            │                                             │
            ▼                                             ▼
   Client-only paths:                          Client may call Functions + Storage
   bootstrapInstitution, createInstitutionUser when AppConfig.useCloudFunctions / useStorage
            │                                             │
            ▼                                             ▼
   firebase deploy --only firestore            Blaze on, then:
                                               firebase deploy --only firestore,functions,storage,hosting
```

**1. Build switch (Flutter)** — compile-time, in `lib/core/app_config.dart`:

| Command | Edition |
|---------|---------|
| `flutter run -d chrome` | Spark (default) |
| `flutter build apk` / `ipa` / `web` with no extra flags | Spark |
| Same commands plus `--dart-define=APP_EDITION=production` | Production client |

`AppConfig.isSpark` / `isProduction` / `useCloudFunctions` / `useStorage` / `useServerFcm` gate optional services. Default `APP_EDITION` is `spark`. Do not add Android product flavors unless store listing later needs two application IDs.

**2. Deploy switch (Firebase / Google Cloud)** — same project `student-mgmt-sdd2011-bddf7` unless we later split staging/prod projects:

| Step | Spark | Production |
|------|--------|------------|
| Billing | Spark, no credit card | Blaze pay-as-you-go + budget alert |
| `firebase deploy --only firestore` | Yes | Yes |
| `firebase deploy --only functions` | No | Yes |
| `firebase deploy --only storage` | No (no bucket) | Yes, after Storage Get started |
| `firebase deploy --only hosting` | Optional | Typical for web |
| Auth + Firestore | Always | Always |

**3. Runtime fallback** — a production-flagged client must still run if Functions/Storage are missing (wrong project, Spark leftover). Catch callable/storage errors and use the Spark path (client writes). Never crash the login/setup flow because Blaze is off.

**4. What is shared vs gated**

| Always on (both editions) | Production-only (`AppConfig`) |
|---------------------------|-------------------------------|
| Email Auth, Firestore, rules on user docs | Cloud Functions callables |
| First-time setup, roster, attendance, homework, timetable, marks, announcements, PTM text | Storage uploads |
| Client FCM **subscribe** | Functions **send** FCM |
| go_router / Riverpod screens | App Check, PITR, multi-region (console, not a Dart flag) |

**5. Not a store “lite vs pro” SKU** — parents/teachers install one app. Spark vs production is an **operator** choice (how the institution’s Firebase project is billed and which binary you ship). Changing edition does not change roles or screens.

**Today:** `AppConfig` gates Functions, Storage, and server FCM. Spark is the default. Production builds try callables first, then the client Spark path. PTM file upload runs only when `AppConfig.useStorage` is true and still saves the text note if Storage is missing.

## What is not done yet (production gap)

Current project is **no-cost**: Auth + Firestore live; Storage not created; Functions not deployed.

When moving to production, also:

- Password reset / email verification UI
- Cleanup of Auth users with no Firestore profile
- Android SDK + CocoaPods for store builds (this machine is Chrome-only today)
- Hosting domain on Auth authorized domains
- Secrets stay out of git; client keys in `firebase_options.dart` are expected

## How to run (dev)

```bash
cd /Users/siddharthdebnath/dev/student-app
flutter pub get
flutter run -d chrome
```

Firebase CLI project: `firebase use student-mgmt-sdd2011-bddf7`.

GitHub remote (HTTPS): `https://github.com/sid-debnath/student-app.git`. Push needs a PAT or SSH; `user.name` / `user.email` do not authenticate Git.

## White-label branding and customer onboarding

One **customer** = one brand pack + one Firebase project (typical) + one binary. Tenancy inside the app stays `institutions/default`.

**Brand pack** (`brands/<id>/`, copied to `assets/branding/`):

| File | Use |
|------|-----|
| `brand.json` | `id`, `displayName`, `tagline`, `primaryColor` (`#RRGGBB`), asset file names |
| `logo.png` | In-app logo (login, home app bar) |
| `background.png` | Login screen backdrop |
| `app_icon.png` | Android / iOS / web launcher icons via `flutter_launcher_icons` |
| `splash.png` | Splash / fallback |

```bash
cp -R brands/_template brands/<id>
# drop in artwork, edit brand.json
dart run tool/apply_brand.dart <id>
dart run flutter_launcher_icons
```

Code must load look from `BrandConfig` / `assets/branding/`, not hard-coded logos. After login, merge optional Firestore `institutions/{id}.branding` (`displayName`, `tagline`, `primaryColor`, `logoUrl`, `backgroundUrl`). Empty URLs keep bundled assets (Spark).

**Onboard a customer**

1. Brand pack as above.
2. Firebase project: Auth email/password + Firestore; `firebase use` + `firebase deploy --only firestore`.
3. If package name / project changed: `flutterfire configure` and commit generated options.
4. Run/ship the app; **First-time setup** writes `institutions/default` + admin + demo class/student.
5. Unique Play/App Store IDs per customer if they install alongside another school’s build (`com.institution.student_app` / `com.institution.studentApp` are the demo IDs).
6. No Functions/Storage until Blaze.

Operator-facing copy of this checklist is in `README.md`.

## Coding conventions for this repo

- Match existing Riverpod / `go_router` / repository patterns
- Keep `viewer` as the parent+student role
- Keep institution id `default` unless migrating tenancy
- Ship one brand pack per customer binary (`brands/<id>` → `assets/branding`); do not hard-code logos or login backgrounds in widgets
- Use `InstitutionPaths` / `institutionId` for tenancy; use `AcademicClass` for class/section records (not the institution itself)
- Prefer Firestore profile checks in rules over custom claims while targeting the **no-cost** edition
- Gate Functions/Storage/server FCM with `AppConfig` in `lib/core/app_config.dart` (`--dart-define=APP_EDITION=production`). Default is Spark.
- Production client must fall back to Spark paths if callables or Storage fail
- Do not re-clone Flutter into `$HOME/flutter`; use `/opt/homebrew/bin/flutter`
- Git: `safe.directory` for `/opt/homebrew/share/flutter` if “dubious ownership” appears
