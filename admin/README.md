# EnableWork+ System Administrator Dashboard

This is the separate Flutter Web application for the **System Administrator** role.
It shares the EnableWork+ Supabase backend with the mobile PWD Job Seeker app; it
does not create an employer account, employer login, or employer dashboard.

## Current foundation

- Provisioned administrator login and password recovery UI.
- Protected dashboard shell with responsive sidebar navigation.
- Initial interfaces for PWD job seekers, companies, job postings, applications,
  and system activity.
- Honest unavailable states while the local Supabase security gate is pending.
- Existing transparent EnableWork+ branding asset reused from the mobile project.

No preview records are presented as live data. The dashboard does not use a
service-role key, public administrator registration, hosted Supabase endpoint, or
frontend-only role trust. Authorization remains enforced by the existing database
RLS/RPC layer.

## Run locally

From PowerShell:

```powershell
Set-Location 'C:\Users\Janvier\enablework-plus\admin'
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_LOCAL_PUBLISHABLE_KEY --dart-define=AUTH_REDIRECT_URL=http://127.0.0.1:3000/
```

Use a provisioned administrator account only. There is intentionally no public
administrator registration flow. Do not put a service-role key in these commands
or in browser code.

See [local setup](../docs/phase-1-local-setup.md) and the [security matrix](../docs/database/security-matrix.md).

## Phase 1 architecture notes

The existing repository already contains a Flutter Web admin foundation, so this
phase keeps Flutter Web rather than introducing a second React/Vite application.
The dashboard is a protected client of the existing `profiles`,
`job_seeker_profiles`, `accessibility_preferences`, `employers`, `jobs`, and
`applications` tables.

The current migrations expose administrator-controlled RPCs for job status,
application status, seeker account status, and controlled resume operations.
They do not expose an administrator-readable activity table or a general
administrator profile-management API. The UI therefore shows an honest empty
activity state and keeps live management writes disabled until the existing RLS
and RPC contracts are connected and reviewed.

There is no employer role or employer authentication surface. Companies are
records selected by the administrator when managing jobs. AI matching remains
deferred and is not represented by fabricated scores or recommendations.
