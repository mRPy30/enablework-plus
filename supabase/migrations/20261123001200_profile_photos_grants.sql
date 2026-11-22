-- RLS controls ownership; this grant allows the authenticated client to issue the owner-scoped SELECT.
grant select on public.profile_photos to authenticated;
