-- Deliberately no auth.users inserts, passwords, role promotions or personal data.
-- Run tools/seed-local.mjs only against the local API to create disposable Auth fixtures.
-- Public dummy employers/jobs require the seeded administrator's audit identity.
-- The script then inserts them using that administrator's ordinary user session.
select 1;
