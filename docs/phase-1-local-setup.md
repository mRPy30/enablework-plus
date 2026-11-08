# Phase 1 local development

No hosted Supabase project is linked or modified. No deployment, production accounts, real PWD data, OpenAI integration or Git push is part of this implementation.

## Prerequisites

Flutter 3.47.9/Dart 3.13.7; Node 24+; Docker Desktop (or compatible Podman) running on Windows. Supabase CLI 3.0.0 is pinned as a test/development dependency. Never expose the local stack to a public network. Docker/Podman is not installed in the inspected environment, so actual Auth/Storage and PostgreSQL 17 replay remain blocked here.

In Windows PowerShell:

```powershell
Set-Location 'C:\Users\Janvier\enablework-plus'
npm.cmd --prefix supabase/tests ci
# Keeps local CLI state/keys in an ignored directory, separate from hosted login state.
$env:SUPABASE_HOME = Join-Path (Get-Location) 'config/local/cli-home'
$cli = Join-Path (Get-Location) 'supabase/tests/node_modules/.bin/supabase.cmd'
# Docker Desktop example: create this loopback-bound network once.
# If the name already exists, inspect its binding option before reusing it.
docker network create --opt com.docker.network.bridge.host_binding_ipv4=127.0.0.1 enablework-local
if ($LASTEXITCODE -ne 0) { throw 'Inspect the existing network before continuing.' }
& $cli start --workdir . --network-id enablework-local
if ($LASTEXITCODE -ne 0) { throw 'Start failed. Check Docker before continuing.' }
```

For subsequent starts, reuse the already-inspected enablework-local network and omit the network-create step. A Podman setup requires independently verifying equivalent loopback-only port bindings.

Start applies local migrations for this new stack. If a local instance already exists, inspect it before replacing/resetting data. Do not use db push, link, deploy or --remote. No automatic reset command is provided; any deliberate local reset destroys dummy local data and requires reviewing the selected instance first.

## Isolated database/security tests

```powershell
node supabase/tests/database.test.mjs
node supabase/tests/edge-function.test.mjs
```

The Edge suite executes the actual TypeScript handler under mocked Auth/Storage/network boundaries, including authentication, ownership, PDF signature, size and server-only finalization. It is not an actual Deno/Edge runtime or HTTP integration test.

The database suite starts fresh in-memory PostgreSQL through PGlite, applies all five application migrations and evaluates real RLS/constraints/functions. It uses explicit managed-schema test doubles, not GoTrue/Storage services. PGlite is PostgreSQL 18.6; the actual Supabase configuration targets PostgreSQL 17. Passing this suite does not validate exact service integration, email delivery, HTTP uploads, multiple concurrent database connections or PostgreSQL 17 compatibility.

## Actual local Auth and Storage tests

After the local stack is running:

```powershell
& ./tools/run-local-services.ps1 -Mode Test
```

This privately captures local CLI status values without printing credentials, creates disposable local Auth accounts, tests registration confirmation requirements, role forgery, login/refresh/logout, REST isolation, private Storage, PDF finalization and duplicate submissions, then cleans up those fixtures. Configuration guards reject hosted API/DB URLs before any network/database operation. The local email inbox is http://127.0.0.1:54324 for manual confirmation/recovery tests; complete actual confirmation/recovery links on both clients as part of the manual QA gate.

## Optional dummy development seed

```powershell
& ./tools/run-local-services.ps1 -Mode Seed
```

Creates two dummy seekers, one controlled dummy administrator, a company, published/draft jobs and a dummy PDF. Passwords are random; login details are saved only to ignored config/local/dummy-users.json. This seed is explicit and not automatic during database reset; seed.sql intentionally does not insert into Supabase-managed auth.users. Seed is not idempotent: each invocation creates a new isolated dummy dataset. Do not repeatedly run it unless more fixtures are intended. Actual creation is blocked until the local runtime is available.

## Configure the apps

```powershell
New-Item -ItemType Directory -Path config/local -Force | Out-Null
Copy-Item config/examples/mobile.local.example.json config/local/mobile.json
Copy-Item config/examples/admin.local.example.json config/local/admin.json
```

Edit the ignored files locally: replace only the public-key placeholder with the public local key from your local Supabase status. Never put a secret/service-role key into either JSON. Preserve the callback values. Examples contain no actual keys.

Mobile example uses Android emulator host 10.0.2.2. Admin uses loopback; both point to the same host-local project on port 54321. A physical Android device can use adb reverse tcp:54321 tcp:54321 and change its ignored config to http://127.0.0.1:54321. For email confirmation/recovery links generated with loopback hosts, use adb reverse for both 54321 (API) and 54324 (local inbox) and select the loopback API URL in the ignored mobile config. This lets Android open the actual verification link before returning to the app. USB/device connectivity and callback behavior still need manual validation. The callback scheme is com.enableworkplus.app; the Android application ID remains com.enableworkplus.enablework_plus.

```powershell
Set-Location mobile
flutter pub get
flutter analyze
flutter test
flutter devices
$androidDeviceId = Read-Host 'Enter the Android device ID'
if ([string]::IsNullOrWhiteSpace($androidDeviceId)) { throw 'An Android device is required.' }
flutter run -d $androidDeviceId --dart-define-from-file=../config/local/mobile.json
Set-Location ../admin
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=3000 --dart-define-from-file=../config/local/admin.json
```

Stop the running mobile app before proceeding to admin commands. Config-file parsing and session initialization fail closed with a generic setup screen. The frontends intentionally reject non-local endpoints during this milestone. Android stores sessions using platform secure storage; admin keeps sessions in memory and requires login after reload.

## Auth configuration

Email/password only, confirmation enabled, minimum 12 characters with upper/lower/digit requirement, refresh rotation, anonymous sign-in disabled, explicit redirects only. Email recovery/confirmation is captured locally, not sent to real people. Administrator creation requires trusted SQL: after creating a dummy Auth identity, call private.bootstrap_administrator using a local database owner connection. Ordinary authenticated users, even application administrators, cannot call it. No production administrator is provisioned.

resume-finalize is a non-AI local Edge Function. It uses only Supabase-provided server runtime credentials; do not create or commit credential files. Its bearer identity check is mandatory in addition to the gateway JWT check. API/Storage tests must pass before relying on it.

## Review gate

Complete all blocked runtime checks, manual Android/browser signup/recovery tests, exact PostgreSQL 17 migration replay, parallel submission/deactivation and file-lifecycle checks. Review retention, production MFA/deep links and file-validation limitations before a production design decision. Stop for owner review; neither a hosted migration nor the next phase is authorized.
