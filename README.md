# EnableWork+

EnableWork+ helps persons with disabilities find and apply for employment opportunities. This private monorepo contains an Android application, a separate web administrator dashboard, and Supabase backend assets.

## Approved scope

Exactly two system roles exist:
- **PWD Job Seeker:** Android registration/login, profile/resume management, accessibility preferences, dashboard, job discovery/applications/status, and the approved AI features in later phases.
- **System Administrator:** Web login, job seeker management, employer/company records, job postings, application monitoring/status updates, and basic statistics.

Employers are company records managed by administrators. They have no accounts, login, dashboard, or self-service publishing.

Technology: Flutter/Dart for Android and the approved Flutter Web admin; Supabase PostgreSQL, Auth, Storage, RLS and Edge Functions. OpenAI requests will run only through secure Edge Functions in Phase 6. No AI integration is present.

Project context: PHP 22,000 development fee, one developer and one tester, target November 25, 2026. Phase 0 requirements are the working source of truth as authorized by the owner; the final agreement/SOW was not available in this session.

## Repository layout

```text
mobile/       Android Flutter app (enablework_plus)
admin/        Separate Flutter Web app (enablework_admin)
supabase/     Future migrations/functions; preparation notes only
docs/        Setup, architecture and verification notes
```

Each app keeps screens, widgets, services, models, state and utilities separate under lib/. Empty directories are placeholders, not implemented features. Shared packages and a state management dependency are deferred until a concrete need exists.

## Development setup

Install Flutter stable and Android Studio with the Android SDK, command-line tools, platform tools and an emulator (or enable USB debugging on a test phone). Install the Flutter/Dart VS Code extensions. Git and GitHub CLI are used for version control.

In Windows PowerShell:

```powershell
flutter --version
flutter doctor -v
flutter doctor --android-licenses
flutter devices
Set-Location mobile
flutter pub get
flutter analyze
flutter build apk --debug
flutter run -d <ANDROID_DEVICE_ID>
Set-Location ..\admin
flutter pub get
flutter analyze
flutter build web
flutter run -d chrome
```

Replace the device placeholder with an actual Android device ID. Chrome success does not verify Android runtime behavior. The generated Android application ID is `com.enableworkplus.enablework_plus`, a provisional identifier to review before distribution. Release signing and deployment are not configured; do not distribute the starter as a production release.

The starter uses Flutter 3.47.9 and Dart 3.13.7. Commit each application's pubspec.lock to keep dependency resolution reproducible. These apps currently show only a setup placeholder; no authentication or product screens exist.

## Supabase and environment configuration

See [Supabase setup](docs/supabase-setup.md). The root .env.example contains placeholders only. Flutter does not auto-load .env files; future client initialization will read public values through --dart-define or --dart-define-from-file. Client configuration is extractable from builds and must never contain secrets.

Never commit service-role/secret keys, OpenAI keys, database passwords, signing keys, real PWD information, or populated .env files. RLS must enforce permissions before database access is enabled. No client connection or complete schema exists in Phase 0.

## Git workflow and contribution guidelines

Use small feature branches and meaningful milestone commits. Review staged changes before committing, keep secrets and generated build output out of Git, run relevant checks, and request review before merging. Work through PLAN -> IMPLEMENT -> TEST -> VALIDATE -> APPROVE -> NEXT PHASE. Phase 1 requires explicit owner approval.

```powershell
git status --short --branch
git switch -c feature/short-description
git diff
git add <reviewed-paths>
git diff --cached
git commit -m "Describe the completed change"
```

The existing origin must be https://github.com/mRPy30/enablework-plus.git. GitHub authentication is managed on the owner's Windows machine. No remote creation, push or remote modification is performed by this scaffold.

See [Phase 0 status](docs/phase-0.md) and [local push instructions](docs/git-workflow.md).
