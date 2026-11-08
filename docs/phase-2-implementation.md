# Phase 2 implementation and local QA

Date: November 8, 2026. Baseline: 9d7b427. The owner confirmed Phase 1 publication and Android startup, approved Phase 2, briefly paused for an emulator preview, then authorized resuming. Phase 2 changes remain local and uncommitted for review.

## Implemented scope

- Job-seeker dashboard with profile completion, current resume and exact own-application counts.
- Profile editor for name, optional phone, city/province, headline, summary, education, experience, skills, work preferences and optional work adjustments.
- PDF selection and bounded reading, upload/validation stage feedback, version list, current selection, pending-file validation retry, and confirmed removal of unattached resumes.
- Persisted accessibility preferences: 80%-200% app text size, high contrast and reduced motion. App scaling composes with the system scaler. System high contrast/reduced motion are respected; preference state resets on account changes.
- Loading, empty, retry, conflict, expired/denied-session and network-error states. User-facing messages do not print raw SDK/database errors or credentials.

Exactly two application roles remain: PWD Job Seeker and System Administrator. Employers remain company records only. No employer login, full job browser/application form, AI integration, production setup or deployment is included. No admin frontend features were added; its authentication suite was rerun for regression coverage.

## Files and architecture

| Area | Source |
| --- | --- |
| Profile/preferences/resume DTOs, validation and completion rules | mobile/lib/models/seeker_workspace.dart |
| Guarded Supabase operations, native PDF adapter and upload lifecycle | mobile/lib/services/seeker_repository.dart |
| Loading/mutation state, stale-response disposal and error handling | mobile/lib/state/seeker_controller.dart |
| Dashboard/profile/resumes/accessibility screens and navigation | mobile/lib/screens/*_screen.dart and seeker_home.dart |
| Shared accessible feedback/cards | mobile/lib/widgets/workspace_widgets.dart |
| System text-scaling composition | mobile/lib/utils/preference_text_scaler.dart |
| Existing Auth gate and global theme integration | mobile/lib/main.dart; auth_screen.dart; auth_service.dart |
| Atomic profile/save/count RPCs | supabase/migrations/20261108000600_profile_workspace.sql |
| Security/controller/widget/preview tests | mobile/test/workspace_*.dart; supabase/tests/ |

No state-management framework or new database tables are needed. file_picker 13.3.2 is the one added direct dependency. The installed Android plugin manifest was inspected and declares document-selection queries without broad storage/media permissions. Native picker behavior still needs an Android integration check.

## Database addition

The first five migrations are unchanged. Migration 006 adds:

- my_job_seeker_profile(): a single joined read of the caller's profile/details and exact update timestamp.
- save_my_job_seeker_profile(p_profile,p_details,p_expected_updated_at): a transaction that updates only permitted fields. It rejects authority/owner keys, invalid text lists and stale versions; a detail failure rolls back identity changes.
- my_application_counts(): exact per-status aggregates for the active caller, avoiding the Data API row cap.
- A private text-array validation helper with restricted execution.

All three public functions are SECURITY INVOKER with a fixed empty search_path. They require an active job seeker and retain the existing table RLS and column permissions. No service-role frontend operation or extra system role is introduced. Existing direct column-limited updates remain governed by Phase 1 rules; the atomic RPC is the app's preferred save path.

Profile completion uses name, headline, summary, skills, education/experience and city/province. Optional phone and work-adjustment disclosure do not increase the score. It is a user-interface completeness indicator, not a job-match or hiring score.

## Resume lifecycle and security

1. The system picker selects one PDF. Length is checked before reading, and streamed bytes are capped at 5 MiB even when metadata is incorrect. The client checks the PDF header before creating a backend record.
2. begin_resume_upload creates an owned pending record/path. Upload uses the signed-in user's session, PDF MIME and upsert=false.
3. The existing non-AI resume-finalize function validates the file and performs its server-only finalization. Only ready files can become current.
4. If upload/finalization times out, the pending record is retained. Refresh shows retry-validation/removal controls. No silent cleanup can delete a server-completed file, and no overwrite is attempted.
5. Application-attached resumes show a retention message and have no Remove action. Server RPC/Storage policies enforce this even if the UI is tampered with.
6. Removal follows begin_resume_deletion -> Storage API remove -> complete_resume_deletion. Interrupted removals remain retryable.

Progress is labeled by actual stage; no fabricated percentage is shown. No inline PDF viewer/download export, malware-scanning service or file-sharing feature is added. Size/MIME/header validation does not guarantee that PDF content is harmless; the Phase 1 file-handling limitation remains.

Repositories check current account identity and active job-seeker access before operations. Profile/resume queries include the owner restriction, RLS remains authoritative, and completed responses are ignored after controller disposal. No profile/resume contents are cached to local files. Only confirmed server accessibility preferences are applied; failed saves keep prior settings. User drafts remain in memory and disappear with their protected workspace on sign-out/account change.

## Validation results

| Check | Result |
| --- | --- |
| Flutter analyze, mobile | PASS: no issues |
| Flutter tests, mobile | PASS: 36 tests including profile save, PDF validation/cancellation, stale-response disposal, wrong-account denial, global accessibility, OS reduced motion, account switching and narrow-screen 200% text |
| Flutter analyze and tests, admin | PASS: no issues; 6 tests |
| PostgreSQL migration replay/security | PASS: all six migrations; 93 checks in in-memory PostgreSQL 18.6/PGlite |
| Existing resume handler isolated tests | PASS: 13 checks; mocked Auth/Storage/network |
| Visual review | Four actual-widget PNG renders using synthetic data, no backend or real user accounts. Initial encoding/navigation issues corrected and captures regenerated. |
| Local Supabase prerequisite | BLOCKED: API not reachable and CLI migration up targets 127.0.0.1:54322 but receives ECONNREFUSED |
| Live Auth/Storage/profile RPC suite | Prepared/extended; NOT PASSED here because the local runtime/settings are unavailable |
| Android Phase 2 APK/native picker/TalkBack | NOT VERIFIED in this session; the owner's successful build/startup preceded these screen changes |

Database tests use explicit managed-schema test doubles; PostgreSQL 17/Supabase service replay still requires the real local runtime. Widget tests use fake repositories and cannot prove actual HTTP integration or device screen-reader behavior. Source-widget PNGs are not emulator screenshots. Early failing test assumptions/layout issues were corrected before the successful final test run.

## Run locally after backend prerequisites

From ordinary Windows PowerShell in the SAME checkout containing these Phase 2 files:

```powershell
Set-Location 'C:\Users\Janvier\enablework-plus'
npm.cmd --prefix supabase/tests ci
$env:SUPABASE_HOME = Join-Path (Get-Location) 'config/local/cli-home'
$cli = Join-Path (Get-Location) 'supabase/tests/node_modules/.bin/supabase.cmd'
# Start the inspected, loopback-bound local runtime using the Phase 1 runbook first.
# The CLI defaults to LOCAL. Do not add --remote, link, deploy or db push.
& $cli migration up --workdir .
if ($LASTEXITCODE -ne 0) { throw 'Local migration did not complete. Stop before integration testing.' }
& ./tools/run-local-services.ps1 -Mode Test
```

No database reset is needed or authorized by these instructions. Inspect any pre-existing local data before migration. The migration command was attempted by the agent against local only and failed to connect; nothing was applied to hosted services.

The ignored config/local/mobile.json must contain the local PUBLIC key and correct app callback, as documented in phase-1-local-setup.md. Never put a secret/service-role key in it. Then:

```powershell
Set-Location mobile
flutter pub get
flutter analyze
flutter test
flutter devices
$androidDeviceId = Read-Host 'Actual Android device ID'
if ([string]::IsNullOrWhiteSpace($androidDeviceId)) { throw 'Android device required.' }
flutter run -d $androidDeviceId --dart-define-from-file=../config/local/mobile.json
```

If flutter run is already active, use capital R for a hot restart; main.dart changed from the Phase 1 root widget. A full stop/start is appropriate if a plugin dependency was added after the current APK was built. Without working local configuration/Auth, the app deliberately shows setup/login instead of exposing the protected screens. There is no production demo-login bypass.

## Manual QA before approval

- Confirm the exact checkout: Android Studio previously showed another copy under StudioProjects; do not assume it contains these source changes.
- Sign in as dummy seeker A, edit and relaunch; verify all fields persist. Test concurrent edits and the reload/conflict message.
- Use dummy seeker B to confirm no profile, preferences, counts or resume leakage. Suspend A through the controlled admin operation and confirm protected access closes.
- Upload a small synthetic PDF, cancel selection, reject non-PDF/oversized files, simulate connection loss, retry validation, select current and remove an unattached version.
- Confirm an application-attached resume cannot be removed or overwritten, including direct HTTP attempts.
- Test system/app text scale, high contrast, reduced motion, landscape, software keyboard, focus order, TalkBack labels and navigation targets on Android.
- Run the real local service suite on PostgreSQL 17. Do not equate isolated test success with full integration success.

Stop for owner review. No commit/push, hosted Supabase action, production account, AI integration or next-phase implementation was performed for this Phase 2 step.

## Publication validation update

The owner authorized Git publication after the mobile branding integration. Flutter analyze was rerun with no issues; all 38 mobile tests passed, including the two additional branding checks. Android resources also compiled and linked against API 36 in the branding step. Live local Supabase integration and Android device QA remain pending; Git publication does not deploy or apply migration 006 to hosted services. Earlier statements about uncommitted review status describe the pre-publication handoff.
