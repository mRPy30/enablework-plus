# Shared Accessibility Assessment and Review Flow — Phase 2

Date: November 9, 2026 (Asia/Taipei). This phase extends the uncommitted Accessibility Preferences Foundation. It does not replace the application or restart the original project phases. Implementation is ready for code review; UI runtime/device validation remains blocked.

## Shared flow implemented

The existing AccessibilityScreen now owns one in-memory draft and three steps, using the existing preference model/controller/repository:

1. Assessment: Visual, Mobility, Hearing, Speech, Intellectual, Learning, Psychosocial. Each uses a labelled/described CheckboxListTile with native checked semantics. Multiple or no selections are valid. Text explains privacy and that needs do not enable features.
2. Features: reuse existing text scale 80–200%, high contrast and reduced motion controls and text preview. Choices are independent of needs. No microphone, speech adapter, voice/simplified-language/extra nonfunctional switch is added. Existing saved candidate feature IDs remain unchanged and, when present in review, are explicitly labelled not active in this app version.
3. Review/Confirm: readable need summary (including None selected), text scale and On/Off states, and additional saved choices if present. Edit needs/features goes back to the relevant step. Confirm and save is the only write and explicitly sets preferencesReviewed=true.

Back/Next retain draft selections and the original version. Cancel resets to the saved row with no repository mutation. Settings returns to its existing controls/overview; onboarding remains gated with a Nothing was saved message and access to existing Sign out. Android Back moves to the prior step or cancels at the first step. A Settings flow in an inactive IndexedStack tab does not intercept Back elsewhere.

Saved accessibility values apply through the existing confirmed-server callback; unconfirmed drafts do not change the whole application's preferences. Text-size preview remains local to its preview as before.

## Authorization and onboarding

MainApp/AuthScreen/SeekerHome were reinspected. MainApp's existing authenticatedBuilder is retained. AuthScreen still calls requireAccess first and additionally verifies the returned role is jobSeeker before constructing the protected workspace. Login layout, branding and recovery behavior are not rebuilt. Administrator Web UI and SQL permissions are unchanged.

SeekerHome waits for its guarded repository load. If preferencesReviewed=false, it renders the SAME AccessibilityScreen in onboarding mode before constructing dashboard/profile/resume tab children. The bottom navigation is hidden during this gate; Cancel does not expose dashboard. After a confirmed preference row is loaded, the normal four-destination workspace appears. Already reviewed seekers go directly to it.

No new onboarding route, duplicate controller, preference table or public/demo bypass was added. Account identity still keys the protected workspace; changing/signing out disposes its old controller and widget draft. The repository still checks identity/authorization and suppresses changed-account responses through the foundation.

## Settings integration and failure behavior

The Settings destination retains the three existing functional controls. It adds Edit accessibility needs and uses Review changes rather than a direct persistence action. Assessment and Features steps call the same controls and use the same draft as Settings. Opening Settings, making edits or opening review never sets preferencesReviewed or writes a record.

Confirmation preserves all six fields, including existing additional choices and exact updated_at, through the foundation's owner-scoped optimistic update. Local saving plus controller busy/loading guards disable Confirm, Cancel and editing during submission. Workspace tab changes are disabled during an in-flight mutation.

Failure keeps the review/draft visible and does not fabricate success. Existing WorkspaceError displays the underlying friendly message. Stale conflicts are not retried as unconditional writes. Reload and discard draft explicitly fetches the saved record and replaces the local draft only after successful reload. Success displays a confirmation SnackBar; onboarding then continues to the normal dashboard.

## Exact Phase 2 changed files

Base directory: C:\Users\Janvier\enablework-plus.

| File | Change in this phase |
|---|---|
| mobile/lib/screens/accessibility_screen.dart | Existing screen extended to shared assessment/features/review and Settings overview; local draft, Back/Cancel/Confirm, error/reload and accessible controls |
| mobile/lib/screens/seeker_home.dart | Gate unreviewed users before dashboard; reuse same screen from Settings; preserve four tab identities/order; avoid duplicate visible errors and disable tab switching while saving |
| mobile/lib/screens/auth_screen.dart | Explicit returned-role check before invoking seeker workspace builder; no login redesign |
| mobile/test/support/workspace_fakes.dart | Default dashboard fixtures explicitly reviewed; pending preference-save gate and call counter for duplicate-submit tests |
| mobile/test/workspace_access_test.dart | Existing dashboard/accessibility/account-switch fixtures explicitly reviewed where dashboard entry is intended |
| mobile/test/workspace_widget_test.dart | Existing Settings persistence test now reviews and explicitly confirms |
| mobile/test/accessibility_flow_test.dart | New shared-flow/Auth/semantics/cancel/conflict/account-switch/large-text/Back tests and optional actual-widget capture test |
| docs/shared-accessibility-flow.md | This report/runbook |

There are six modified existing files plus the new test and report. Earlier Phase 1 pending changes remain in the checkout; they were not overwritten. The Phase 1 model, repository, controller, SQL tests and all seven migrations are byte-for-byte unchanged relative to this phase's starting snapshot.

## Test and verification results

| Check | Actual result |
|---|---|
| Final flutter analyze --no-pub | PASS: No issues found |
| Full flutter test --no-pub --concurrency=1 --reporter expanded, including relevant existing/new preference suites | BLOCKED before test execution: 0 cases executed, 9 test files failed to load; no mobile-suite pass claimed |
| Database/security suite | PASS: 117 checks, all seven migrations replayed in disposable in-memory PostgreSQL 18.6/PGlite; managed Auth/Storage are test doubles |
| Supplementary pure-Dart checks of actual preference model | PASS: 33 checks; not widget/controller/HTTP validation and not a replacement for Flutter tests |
| Scope/security review | PASS: all seven migrations unchanged, no package/native/admin changes, no credential patterns in edited files, no changes to Profile/Resume functionality, git diff --check |
| Figma visual verification | Unverified: direct design URL remains inaccessible through web reader. Used the documented six-screen requirements and current UI foundation |
| Screenshots | Not produced. Capture test was prepared, but its Flutter engine could not start. No mockup or prior image is presented as an implemented-screen screenshot |

Exact blocking error:

> An Application Control policy or security policy has blocked execution.
> ProcessException: An Application Control policy has blocked this file (at ../../runtime/bin/process_win.cc:579)

Blocked executable: C:\flutter\bin\cache\artifacts\engine\windows-x64\flutter_tester.exe. The Flutter launcher also returned Windows status -1073741816 after reporting the suite failures. No security policy was disabled, bypassed or changed. Earlier analyzer lint issues were corrected before the final clean analysis.

New tests cover seven categories and checked semantics, multiple/empty selections, Back/Next retention, independence from needs, editable loaded values, unsupported feature controls absent, review/Edit, Cancel, full confirmation, errors/conflicts, repeated submit, unreviewed/reviewed Auth handoff, anonymous/denied/admin exclusion, Settings reuse, account-switch draft disposal, large text and Android Back. These tests are authored and analyzed but their assertions did NOT execute here.

## Run locally for remaining validation

In the user's ordinary working Windows environment:

```powershell
Set-Location 'C:\Users\Janvier\enablework-plus\mobile'
flutter analyze
flutter test --concurrency=1
```

Optional actual-widget source captures after the test engine can run (not emulator screenshots):

```powershell
flutter test test/accessibility_flow_test.dart --concurrency=1 --dart-define=FLOW_PREVIEW_DIR=C:/Users/Janvier/Documents/Codex/2026-11-08/files-pasted-by-the-user-enablework/outputs --dart-define=FLOW_FONT_DIR=C:/flutter/bin/cache/artifacts/material_fonts
```

The isolated source-widget capture uses dummy preferences only; no production preview bypass exists. Then validate actual Android TalkBack, large text, Back/focus order, contrast, save/cancel and identity changes using dummy accounts and a working LOCAL Supabase runtime with migration 007. Current isolated SQL success does not establish live Auth/PostgREST or Android behavior. This phase did not apply 007 to any real/hosted stack.

## Known limitations and stop boundary

- Flutter widget/client/controller runtime assertions and implemented-screen captures remain unverified due to Application Control. No currently observed Android run is claimed.
- Figma exact copy/spacing/frame conformance still needs accessible frames or exports; documented content/flow requirements were followed.
- Additional saved candidate feature IDs are preserved metadata, not runtime capabilities. No fake operational voice or cognitive-feature switch is shown. Baseline guidance in this shared flow is available to everyone without an extra capability flag.
- The upcoming five-tab/jobs/applications phase remains unimplemented. Home/Profile/Resumes/Settings remain the workspace navigation once reviewed.

No schema change/new migration, remote Supabase operation, Edge Function deployment, employer functionality, AI, microphone permission, native speech package, Git staging/commit/push occurred. Stop after this Phase 2 for review and approval; no Phase 3 work has started.
