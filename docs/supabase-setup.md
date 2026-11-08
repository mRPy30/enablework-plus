# Supabase setup status

The Phase 1 local foundation is implemented in supabase/config.toml, migrations/, functions/ and tests/. Follow [the local runbook](phase-1-local-setup.md), [schema/ERD](database/phase-1-schema.md) and [security matrix](database/security-matrix.md). Full local service tests remain blocked until Docker/Podman is running; no hosted project is linked or modified.

Client examples are under config/examples/. Actual client settings belong in ignored config/local/mobile.json and config/local/admin.json. The root .env.example is placeholders only and is not automatically loaded by Flutter. Do not put server credentials into any frontend configuration.

Local-only supabase/config.local.toml and config.local.json are ignored convenience files, not automatically loaded CLI overrides. Authored supabase/config.toml, migrations, functions and documentation stay versionable. Supabase CLI .supabase/.temp/.branches runtime state is excluded.

For a later, separately approved hosted development project: inspect existing projects first; confirm organization, region and plan; keep database passwords in a password manager; capture only the public client URL/key in client configuration; verify PostgreSQL access with select current_database(), current_user, version(). Document required Auth settings separately. Do not link, apply migrations, provision hosted accounts or deploy based on this document alone.

No real PWD data, medical documents or OpenAI integration is introduced. Phase 6 AI requests must use secure Edge Functions and server-only secrets; no AI storage schema or credentials are configured now.
