# EnableWork+ local backend

Seven application tables, two roles, five ordered SQL migrations, private resume Storage and a non-AI resume validation function. Employers are company records only. No hosted project is linked or modified.

- [Local setup and tests](../docs/phase-1-local-setup.md)
- [Schema and ERD](../docs/database/phase-1-schema.md)
- [Security matrix](../docs/database/security-matrix.md)
- [Implementation results](../docs/phase-1-results.md)

config.toml is authored, tracked local configuration; .supabase/, .temp/, local overrides and client config/local/ files are ignored. Never ignore migrations/ or functions/. seed.sql intentionally contains no Auth accounts; use the guarded local seed script for dummy fixtures.
