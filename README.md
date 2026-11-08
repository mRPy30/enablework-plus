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
docs/         Setup, architecture and verification notes
```

Each app keeps screens, widgets, services, models, state and utilities separate under lib/. Empty directories are placeholders, not implemented features. Shared packages and a state management dependency are deferred until a concrete need exists.

## Development setup

Install Flutter stable and Android Studio with the Android SDK, command-line tools, platform tools and an emulator (or enable USB debugging on a test phone). Install the Flutter/Dart VS Code extensions. Git and GitHub CLI are used for version control.

For configured Phase 1 authentication, follow docs/phase-1-local-setup.md. The commands below provide basic tool/build checks; run without connection settings to see the setup screen.

In Windows PowerShell, start from the local repository:

```powershell
Set-Location 'C:\Users\Janvier\enablework-plus'
flutter --version
flutter doctor -v
flutter doctor --android-licenses
flutter devices
Set-Location mobile
flutter pub get
flutter analyze
flutter build apk --debug
$androidDeviceId = Read-Host 'Enter the Android device ID shown by flutter devices'
if ([string]::IsNullOrWhiteSpace($androidDeviceId)) { throw 'An Android device ID is required.' }
flutter run -d $androidDeviceId
Set-Location ..\admin
flutter pub get
flutter analyze
flutter build web
flutter run -d chrome
```

When prompted, enter an actual Android device ID from flutter devices. Stop the running app before continuing to the admin commands. Chrome success does not verify Android runtime behavior. The generated Android application ID is `com.enableworkplus.enablework_plus`, a provisional identifier to review before distribution. Release signing and deployment are not configured; do not distribute the starter as a production release.

The starter uses Flutter 3.47.9 and Dart 3.13.7. Commit each application's pubspec.lock to keep dependency resolution reproducible. The local Phase 1 implementation adds authentication foundations; full product screens remain deferred.

## Supabase and environment configuration

See [Supabase setup](docs/supabase-setup.md). The root .env.example contains placeholders only. Flutter does not auto-load .env files; client initialization reads public values through --dart-define or --dart-define-from-file. Client configuration is extractable from builds and must never contain secrets.

Never commit service-role/secret keys, OpenAI keys, database passwords, signing keys, real PWD information, or populated .env files. RLS must enforce permissions before database access is enabled. The Phase 0 scaffold had no client connection or schema; the local Phase 1 foundation is documented below.

## Git workflow and contribution guidelines

Use small feature branches and meaningful milestone commits. Review staged changes before committing, keep secrets and generated build output out of Git, run relevant checks, and request review before merging. Work through PLAN -> IMPLEMENT -> TEST -> VALIDATE -> APPROVE -> NEXT PHASE. Phase 1 requires explicit owner approval.

```powershell
git status --short --branch
git switch -c feature/short-description
git diff
git add -- README.md
git diff --cached
git commit -m "Describe the completed change"
```

The Git example stages README.md only; explicitly name any additional reviewed files. Personal VS Code settings are ignored; .vscode/extensions.json is shared for extension recommendations.

The existing origin must be https://github.com/mRPy30/enablework-plus.git. GitHub authentication is managed on the owner's Windows machine. No remote changes are performed by the local Phase 1 work. Publishing or hosted database changes require explicit authorization.

See [Phase 0 status](docs/phase-0.md) and [local push instructions](docs/git-workflow.md).


## Phase 1 local implementation

Phase 0 is accepted as complete by the owner. The Phase 1 implementation is local-only and awaits review/runtime validation. See [local setup](docs/phase-1-local-setup.md), [schema and ERD](docs/database/phase-1-schema.md), [security matrix](docs/database/security-matrix.md), and [results](docs/phase-1-results.md).

mobile/ provides job-seeker signup/login/recovery and platform-protected session persistence. admin/ provides administrator login/recovery with memory-only sessions and no registration action. RLS, protected database roles and restricted operations enforce authorization. Neither app can enable a hosted backend in this local milestone. OpenAI remains deferred.
