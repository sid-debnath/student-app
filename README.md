# Student management app

Flutter client with Firebase (Auth, Firestore, Storage, Cloud Functions, FCM).

Roles:

- **admin** — roster, users, timetable, exams, announcements, PTM overview
- **teacher** — attendance, homework, marks, class announcements, PTM slots/notes
- **viewer** — shared parent/student view of one or more linked children

## One-time Firebase setup

1. Create a Firebase project and enable Email/Password auth, Firestore, Storage, Messaging, and Functions (Blaze).
2. From this directory:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
firebase login
cd functions && npm install && cd ..
firebase deploy
```

3. Run the app, use **First-time setup** to create the first admin and sample class/student.

Admins invite teachers and viewers from **More → Users**. Pass class IDs for teachers and student IDs for viewers.

## Run

```bash
flutter pub get
flutter run
```

Placeholder values in `lib/firebase_options.dart` must be replaced by `flutterfire configure` before Auth/Firestore will work.
