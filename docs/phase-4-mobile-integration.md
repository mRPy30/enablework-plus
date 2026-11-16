# Phase 4 mobile Supabase integration

Phase 4 connects the authenticated PWD Job Seeker Flutter app to the local Supabase runtime. The offline presentation remains isolated in `mobile/lib/main_demo.dart`; it is not used by the authenticated app and does not write demo records.

## Client configuration

The authenticated app reads `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `AUTH_REDIRECT_URL` through Flutter compile-time defines. The local Android configuration is the ignored file `config/local/mobile.json`. It contains only the local public client key and uses `10.0.2.2` so an Android emulator can reach the host's loopback Supabase gateway. Never place a service-role/secret key in this file or in a frontend build.

Run the authenticated app from `mobile` with:

```powershell
flutter run -d <android-device-id> --dart-define-from-file=../config/local/mobile.json
```

The shared Android Studio configuration `EnableWork+ Authenticated App` supplies the same file automatically. `EnableWork+ Offline Demo` intentionally does not supply backend defines and remains available for offline presentations.

## Authenticated data paths

`SupabaseSeekerRepository` owns the authenticated data boundary. It rechecks the current Auth identity before and after reads/writes, maps only owner-scoped rows, and treats access-loss responses as a sign-out condition. Jobs are read from published jobs belonging to active employers; employers remain records and never become users. Applications are submitted through the database `submit_application` RPC, then reconciled by reading the owner-scoped application instead of blindly retrying a request whose response may have been lost.

Profile, resumes, and accessibility preferences continue to use the existing owner-scoped repository and RLS policies. Resume upload/finalization remains a separate local Edge Function workflow; this phase does not add AI calls or expose privileged credentials.

## Local-only verification

The local Supabase gateway, REST, Auth health, and Studio endpoints must be reachable only through loopback bindings. Apply no migrations or hosted changes from the mobile client. Before device testing, verify the local runtime and migration set with the existing local runbook; do not print keys or commit `config/local/`.
