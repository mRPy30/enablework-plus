begin;

create table public.job_ai_matches (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  job_seeker_id uuid not null references public.job_seeker_profiles(user_id) on delete cascade,
  status public.resume_ai_scan_status not null default 'queued',
  result jsonb,
  error_message text check (error_message is null or length(error_message) <= 1000),
  model text check (model is null or length(model) <= 120),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(job_id, job_seeker_id, created_at),
  check ((status = 'completed') = (result is not null)),
  check (status <> 'failed' or error_message is not null)
);

create index job_ai_matches_owner_idx on public.job_ai_matches(job_seeker_id, created_at desc);
create index job_ai_matches_job_idx on public.job_ai_matches(job_id, created_at desc);

alter table public.job_ai_matches enable row level security;
revoke all on public.job_ai_matches from public, anon, authenticated;
grant select on public.job_ai_matches to authenticated;
create policy job_ai_matches_read on public.job_ai_matches for select to authenticated
using (private.is_active_job_seeker() and job_seeker_id = auth.uid());

commit;
