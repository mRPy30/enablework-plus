# Phase 1 access and trust boundaries

RLS is enabled on all seven application tables; grants limit operations and writable columns. API-exposed schema is public only. private helper schema is not exposed, helper functions pin search_path and qualify references, and default PUBLIC execution is revoked on privileged functions. No security-definer views are used.

| Resource | Anonymous | Active job seeker | Active administrator |
| --- | --- | --- | --- |
| profiles | none | own read; edit full_name/phone only | own plus seeker read; own personal-field edit; seeker status via RPC |
| job_seeker_profiles | none | own read/edit content | read seekers; no arbitrary content editing |
| accessibility_preferences | none | own read/edit | no routine access |
| employers | none | companies linked to visible/historical applied jobs | create/read/edit/deactivate |
| jobs | none | open published or historical applied-to jobs | create/read/edit content; status via RPC |
| applications | none | own read; submit through RPC | read all; status through RPC |
| resumes | none | own read/title edit; lifecycle through RPC | read ready resumes attached to applications |
| storage.objects/resumes | none | own registered pending upload; own read; deletion only after begin_resume_deletion | read application-attached files only |
| role assignment | none | none | no frontend promotion capability |
| finalize_resume_upload | none | denied | denied in frontend; server-only function execution |

Suspension checks query the database rather than relying on stale role claims. Existing JWTs cannot bypass application/storage account_status checks. Supabase session validity and authorization are separate: suspension does not itself revoke an Auth session.

## Resume boundaries

- Private resumes bucket, PDF only, 5 MiB. Paths contain UUIDs and a generic filename.
- begin_resume_upload creates a pending record and exact allowed path. Upload with upsert=false using the owner's JWT.
- The non-AI resume-finalize Edge Function validates the bearer user through Auth, fetches metadata/file using that user's RLS permissions, bounds file reads and checks the %PDF- signature.
- Only after that check does its server-side runtime key invoke finalize_resume_upload. Authenticated frontend roles cannot invoke that RPC or write ready status/size directly.
- Signature/MIME/size checks do NOT constitute antivirus scanning, full PDF parsing, sanitization, or a guarantee that embedded PDF content is harmless. No inline viewer or malware scanning service is implemented. Treat files as untrusted; additional scanning needs an explicit scope decision before production file distribution.
- There is no UPDATE Storage policy. Neither owner nor administrator can overwrite submitted content. A new file requires a new resume version/ID.
- Deletion: begin_resume_deletion locks the row and refuses application-attached resumes; remove object via Storage API; complete_resume_deletion refuses while the object still exists. Interrupted deletion can be retried; pending/failed uploads can use the same workflow. No SQL deletion from managed storage.objects is used by application code.
- Authenticated downloads are the default. If later introducing signed preview URLs, keep them short-lived and private. No URL is stored as a durable resume reference now.

## Credentials and accounts

Both frontends reject privileged key formats and non-local endpoints in this local milestone. Client-side key checks are accidental-secret guards, not authorization. Database role checks use auth.uid() plus protected profiles, never client-supplied metadata.

Mobile sessions use flutter_secure_storage. Android backup is disabled. Cleartext HTTP is enabled only in the debug manifest for local emulator access; production URLs/deep links/release signing are not configured. The custom callback scheme is for development; verified production App Links require later review.

Admin sessions are memory-only (persistSession=false); reload requires login. This is an explicit current limitation, not a claim of browser secure storage or full persistent session restoration. The SDK may retain short-lived PKCE verification state to complete recovery links. Admin MFA is not implemented or required by these development policies; decide before production.

Authentication API test/seed credentials exist only in the local Node process. The optional dummy seed writes generated login details only to ignored config/local/dummy-users.json. Never paste or commit it. The test runner restricts API and database destinations to loopback fixed local ports and does not change Auth login state for GitHub/Supabase CLI.

## Sources

- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/database/functions
- https://supabase.com/docs/guides/auth/managing-user-data
- https://supabase.com/docs/guides/storage/security/access-control
