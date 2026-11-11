# Accessibility Preferences Foundation — Phase 1 implementation report

Date: November 9, 2026 (Asia/Taipei). Baseline: 13ea110. Scope is the new accessibility-foundation phase, not a restart of the original project phases.

## Implemented

The existing AccessibilityPreferences, SeekerRepository/SupabaseSeekerRepository and SeekerController are extended; no duplicate preference model/table/repository was created. Interface method signatures remain compatible.

- Seven validated needs: visual, mobility, hearing, speech, intellectual, learning, psychosocial. Empty selections valid; duplicate/unknown/null selections rejected. No need-to-feature inference.
- Finite data identifiers: voice_guidance, text_to_speech, voice_search, simplified_language, step_by_step_guidance. These reserve explicit choices for later feature implementation. No new enabled-setting UI, speech functionality/package, microphone permission or runtime activation is introduced here.
- preferencesReviewed defaults false. It is explicit UI-review state, not legal consent/diagnosis/authorization. Existing Settings Save does not automatically mark an account reviewed.
- Legacy JSON without new keys loads safely; original scale/contrast/motion values survive. Lists returned to callers are read-only; copyWith snapshots lists.
- updateJson distinguishes omitted fields from explicit []/false, including original settings. A legacy or single-setting caller cannot clear unrelated fields. json remains a full six-field representation without ownership or version fields.
- Controller merges partial intent onto the current private preferences. Repository performs one owner-scoped PATCH for a supplied snapshot/version, using both user_id and exact updated_at. Zero matching rows reports a conflict; it does not retry an unconditional overwrite. Legacy direct callers without a version first read one, then PATCH only their supplied fields.
- Existing Settings receives only a narrow save adapter: retain the original preference snapshot and use copyWith. This preserves selections and the version the user edited even if a background reload occurs. No controls/layout/new assessment/review UI was added.
- Existing authenticated identity/active-role checks, post-response account verification, stale response disposal and account-reset behavior remain in place.

## New migration

`supabase/migrations/20261109000700_accessibility_preferences.sql`

The directory was checked before naming it. Migrations 001–006 are byte-for-byte unchanged.

| Column | Definition / default |
|---|---|
| accessibility_needs | text[] NOT NULL, empty array; seven-value allowlist, unique entries |
| enabled_features | text[] NOT NULL, empty array; five-value allowlist, unique entries |
| preferences_reviewed | boolean NOT NULL DEFAULT false |

A private immutable SECURITY INVOKER validator pins search_path, bounds cardinality, rejects null/unknown/duplicate elements, and rejects multidimensional or nonstandard-bound arrays. Authenticated users get only the EXECUTE needed for CHECK evaluation; PUBLIC/anonymous execute is revoked. It grants no role/owner authority.

Existing active-owner policies preferences_read/preferences_update are unchanged. Only UPDATE(accessibility_needs, enabled_features, preferences_reviewed) is added. Existing grants on the original three fields remain. There is no table-wide UPDATE grant or update grant on user_id/created_at/updated_at, role, status, or administrator authority. Administrators do not gain access to this private table.

Old rows preserve text_scale/high_contrast/reduce_motion and receive empty/empty/false. The signup trigger continues to use these safe column defaults. No classification, inference or backfill from profiles/resumes was performed.

## Changed files

All paths resolve under C:\Users\Janvier\enablework-plus.

| File | Change |
|---|---|
| mobile/lib/models/seeker_workspace.dart | Extended existing model, allowlists, validation, partial/full serialization, copy/merge/version |
| mobile/lib/services/seeker_repository.dart | Read new fields/version; validated owner-scoped version-checked PATCH |
| mobile/lib/state/seeker_controller.dart | Preserve unspecified values when saving legacy/partial settings |
| mobile/lib/screens/accessibility_screen.dart | Four-line snapshot/copyWith save adapter; layout unchanged |
| mobile/test/workspace_logic_test.dart | Need/feature/default/legacy/validation/preservation/controller coverage |
| mobile/test/workspace_access_test.dart | Existing account-switch test now starts with populated private choices |
| mobile/test/preference_repository_test.dart | New real-SDK loopback HTTP fixture: payload/version guards, partial updates, conflicts, denied/switched/expired accounts, disposed late save |
| supabase/migrations/20261109000700_accessibility_preferences.sql | New local-only schema migration |
| supabase/tests/database.test.mjs | Pre-007 legacy-row fixture, unchanged-policy comparison, constraints/atomicity/defaults/grants/RLS/version checks |
| supabase/tests/services.test.mjs | Extended actual local HTTP service checks for defaults, full/partial writes, stale version, privacy and rejection |
| docs/accessibility-preferences-foundation.md | This implementation and validation report |

## Validation actually performed

| Check | Result |
|---|---|
| Flutter analyze --no-pub | PASS: no issues after corrections |
| Full Flutter test --no-pub --concurrency=1 --reporter expanded | BLOCKED: 0 test cases executed; all 8 test files failed to load because Windows Application Control blocked flutter_tester.exe. No mobile-suite pass claimed |
| Supplementary standalone Dart checks against the actual model source | PASS: 33 checks. These use Dart only, without the Flutter engine; they do not validate controller/widgets/HTTP or replace the required mobile suite |
| Existing SQL/security suite with all seven migrations | PASS: 117 checks = previous 93 plus 24 added checks |
| Migration/default compatibility | PASS in disposable in-memory PostgreSQL 18.6/PGlite: inserted a legacy account before 007, retained original settings, verified defaults and unchanged policies; removed only that isolated test fixture |
| Actual local service test harness | BLOCKED before fixtures/connections: local runtime settings missing. New service test syntax checks PASS. No real local Auth/Storage/PostgREST pass claimed |
| Local PostgreSQL availability | Port 54322 unreachable; Docker/Podman not on PATH. No real local Supabase/PostgreSQL migration was applied |
| SQL grants/RLS | PASS in isolated PostgreSQL: owner allowed; other seeker/admin hidden and updates affect zero rows; anonymous denied; suspended owner denied; protected columns/table-wide UPDATE remain denied |
| Optimistic update | Fresh exact timestamp update succeeds; stale timestamp changes zero rows in isolated PostgreSQL; full-row invalid update rolls back original values |
| Diff/security/scope checks | git diff --check; changed-file credential/local-environment scan; first six migration/protected source hashes checked unchanged |

PGlite uses managed Auth/Storage test doubles and PostgreSQL 18.6, not the actual local Supabase stack. Its success does not establish production PostgreSQL/service/concurrency behavior. Loopback repository tests were authored and analyzed but did NOT execute because the Flutter engine was blocked. No Windows security settings were modified or bypassed.

## Remaining validation and compatibility note

Run flutter analyze and the full flutter test suite in the user's working Windows environment. The repository/client/widget tests remain unverified at runtime in this session. Run the extended local service suite once a disposable local Supabase stack and its private runtime settings are available. The app's new column projection requires migration 007 on the LOCAL backend before testing it against that backend; safe legacy-row deserialization is not an automatic fallback to an unmigrated schema.

Suggested local checks (ordinary PowerShell):

```powershell
Set-Location 'C:\Users\Janvier\enablework-plus\mobile'
flutter analyze
flutter test --concurrency=1
Set-Location ..
node supabase/tests/database.test.mjs
```

Do not add a hosted migration or disable security controls to obtain a passing result. Inspect any real local data before applying changes; no destructive reset is authorized.

## Boundaries

No assessment/review UI, navigation/jobs/applications, profile/resume changes, AI, native permissions, speech packages, admin changes, hosted migrations or Edge Function deployments were made. Only dummy test values were used. Disability choices remain in the existing private preference path; profile/employer/search/external payloads were not extended.

No Git staging, commit or push occurred. Stop after this foundation phase for owner review; the next phase remains unapproved.
