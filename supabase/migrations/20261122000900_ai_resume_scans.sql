begin;

create type public.resume_ai_scan_status as enum ('queued', 'processing', 'completed', 'failed');

create table public.resume_ai_scans (
  id uuid primary key default gen_random_uuid(),
  resume_id uuid not null references public.resumes(id) on delete cascade,
  job_seeker_id uuid not null references public.job_seeker_profiles(user_id) on delete cascade,
  status public.resume_ai_scan_status not null default 'queued',
  result jsonb,
  error_message text check (error_message is null or length(error_message) <= 1000),
  model text check (model is null or length(model) <= 120),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  check ((status = 'completed') = (result is not null)),
  check (status <> 'failed' or error_message is not null)
);

create index resume_ai_scans_owner_idx on public.resume_ai_scans(job_seeker_id, created_at desc);
create index resume_ai_scans_resume_idx on public.resume_ai_scans(resume_id, created_at desc);

alter table public.resume_ai_scans enable row level security;
revoke all on public.resume_ai_scans from public, anon, authenticated;
grant select on public.resume_ai_scans to authenticated;

create policy resume_ai_scans_read on public.resume_ai_scans for select to authenticated
using (
  (private.is_active_job_seeker() and job_seeker_id = auth.uid()) or
  (private.is_active_administrator() and exists (
    select 1 from public.resumes r
    where r.id = resume_id and r.upload_status = 'ready'
      and exists (select 1 from public.applications a where a.resume_id = r.id)
  ))
);

commit;
