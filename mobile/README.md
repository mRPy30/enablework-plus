# EnableWork+ Android application

PWD Job Seeker registration/login/recovery plus a protected Phase 2 dashboard, profile editor, PDF resume lifecycle and accessibility preferences.

- [Phase 2 runbook and results](../docs/phase-2-implementation.md)
- [Local Supabase setup](../docs/phase-1-local-setup.md)
- [Authorization matrix](../docs/database/security-matrix.md)

Authentication and Phase 1 RLS remain mandatory. No employer login, AI integration, real PWD seed data or production deployment exists. The production entry point continues to require a valid seeker session.

## Run from Android Studio

Open `C:\Users\Janvier\enablework-plus\mobile` as the project. With the Flutter and Dart plugins enabled, select your running Android emulator in the device dropdown. Both configurations inherit the project Flutter SDK and the selected device. Select **Medium_Phone_API_37.0** for both targets. Standard Run uses Debug mode and resolves the working directory from the mobile pubspec.yaml beside this README.

| Run configuration | Dart entry point | Launch screen |
|---|---|---|
| **EnableWork+ Offline Demo** | `lib/main_demo.dart` | **EnableWork+ · Sample data** and **Get started** |
| **EnableWork+ Authenticated App** | `lib/main.dart` | Setup message without local settings, or the authentication flow with approved settings |

Choose **EnableWork+ Offline Demo** in the toolbar and press **Run** for the offline walkthrough. To launch the actual application, stop the current run and select **EnableWork+ Authenticated App**. Android Studio remembers your selection locally. If the configurations are missing, check that the open folder contains this README and `pubspec.yaml` and that Flutter and Dart are enabled in **Settings → Plugins**.

To launch the actual app from PowerShell:

```powershell
Set-Location 'C:\Users\Janvier\enablework-plus\mobile'
flutter run --no-pub -t lib/main.dart
```

The shared configurations contain no credentials or backend overrides. Live sign-in requires separately approved local settings and a verified loopback-only backend.

## Offline client demo

From this mobile directory, with an Android device already visible to Flutter:

```powershell
flutter devices
flutter run --no-pub -t lib/main_demo.dart
```

Choose the Android device if prompted. This target uses bundled fictional listings and in-memory data. It never initializes Supabase or opens a personal file picker. The regular `lib/main.dart` target uses the existing authentication flow and does not load demo records.

1. Select **Get started**. In **Applications**, see the empty state and choose **Browse jobs**.
2. Search for **Catalog**, open the work arrangement filter, and choose **Hybrid**. Open **View job** to read the job description and workplace accessibility information.
3. Select **Review application**. Use the current sample resume, or open **Manage resumes**, add a sample, go back and select it.
4. Select **Save application**, then **View application**. The record and dashboard count exist only in this session.
5. Use **Profile → Manage resumes** or **Home → Manage resumes** to revisit the same documents. **Settings** opens the existing accessibility review flow.
6. **End session** clears the session. AI matching remains deferred.

The Android app is for PWD Job Seekers. System Administrators use the separate web application. Employers are company records without accounts or a portal.
