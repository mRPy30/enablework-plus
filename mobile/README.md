# EnableWork+ Android application

PWD Job Seeker registration/login/recovery plus a protected Phase 2 dashboard, profile editor, PDF resume lifecycle and accessibility preferences.

- [Phase 2 runbook and results](../docs/phase-2-implementation.md)
- [Local Supabase setup](../docs/phase-1-local-setup.md)
- [Authorization matrix](../docs/database/security-matrix.md)

Authentication and Phase 1 RLS remain mandatory. No employer login, AI integration, real PWD seed data or production deployment exists. The production entry point continues to require a valid seeker session.

## Offline client demo

From this mobile directory, with an Android device already visible to Flutter:

```powershell
flutter devices
flutter run --no-pub -t lib/main_demo.dart
```

Choose the Android device if prompted. This target uses bundled fictional listings and in-memory data. It never initializes Supabase or opens a personal file picker. The regular `lib/main.dart` target uses the existing authentication flow and does not load demo records.

1. Select **Open seeker demo**. In **Applications**, see the empty state and choose **Browse jobs**.
2. Search for **Catalog**, open the work arrangement filter, and choose **Hybrid**. Open **View job** to read the job description and workplace accessibility information.
3. Select **Review application**. Use the current sample resume, or open **Manage resumes**, add a sample, go back and select it.
4. Select **Save demo application**, then **View application**. The record and dashboard count exist only in this session.
5. Use **Profile → Manage resumes** or **Home → Manage resumes** to revisit the same documents. **Settings** opens the existing accessibility review flow.
6. **Exit demo** clears the session. AI matching remains deferred.

The Android app is for PWD Job Seekers. System Administrators use the separate web application. Employers are company records without accounts or a portal.
