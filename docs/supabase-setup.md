# Supabase preparation

No hosted project, database connection, migrations, RLS policies, Auth flows, Storage buckets or Edge Functions have been created or verified by this scaffold.

1. In the Supabase dashboard, create or select the EnableWork+ project in the appropriate organization. Choose a suitable nearby region, set a strong database password, and store it in a password manager.
2. Record the project URL and public publishable key from the project's connection/API settings. The public key is intended for clients; secret/service-role keys are server-only and bypass RLS.
3. Verify PostgreSQL access in the dashboard SQL editor with `select current_database(), current_user, version();`. A successful result confirms access for that dashboard session, not future app authorization. Do not share connection passwords.
4. If direct PostgreSQL access is needed, use the dashboard Connect instructions for the appropriate direct/pooler endpoint. Never commit a connection URI containing a password.
5. Keep migrations/ and functions/ for later phases. Do not apply a complete schema during Phase 0. A Supabase CLI config.toml should be generated with the installed CLI when local backend development is approved; no speculative config is included.
6. Future Flutter initialization will add the official supabase_flutter package and use SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY passed as Dart defines. No package or connection code is needed for these starter apps yet.
7. Future client access requires RLS on exposed tables, least-privilege policies for the two roles, and protected resume storage. Admin privileges must be enforced server-side, not solely by UI checks. Employer records never become auth accounts.
8. During Phase 6 only, store the OpenAI API key as a Supabase Edge Function secret. Never put it in a Flutter build, client configuration or Git. ChatGPT subscription and API billing are separate.

Copy root .env.example to an ignored .env only if local tooling needs it. For later Flutter configuration, use an ignored JSON file with --dart-define-from-file, or explicit --dart-define arguments containing public values only. Do not pass a dotenv-format file to --dart-define-from-file; use a JSON configuration file for the documented workflow.
