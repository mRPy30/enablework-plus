begin;
create table public.resumes (
  id uuid primary key default gen_random_uuid(),
  job_seeker_id uuid not null references public.job_seeker_profiles(user_id) on delete restrict,
  title text not null check (length(trim(title)) between 1 and 180),
  storage_bucket text not null default 'resumes' check (storage_bucket = 'resumes'),
  storage_path text not null,
  mime_type text not null default 'application/pdf' check (mime_type = 'application/pdf'),
  size_bytes bigint check (size_bytes between 1 and 5242880),
  upload_status public.resume_upload_status not null default 'pending',
  is_current boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(id, job_seeker_id),
  unique(storage_bucket, storage_path),
  check (storage_path = job_seeker_id::text || '/' || id::text || '/resume.pdf'),
  check (not is_current or upload_status = 'ready'),
  check (upload_status <> 'ready' or size_bytes is not null)
);
create unique index one_current_resume_per_seeker on public.resumes(job_seeker_id) where is_current;
create index resumes_owner_idx on public.resumes(job_seeker_id);
create index resumes_path_idx on public.resumes(storage_path);
create table public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete restrict,
  job_seeker_id uuid not null references public.job_seeker_profiles(user_id) on delete restrict,
  resume_id uuid not null,
  status public.application_status not null default 'submitted',
  submitted_at timestamptz not null default now(),
  status_updated_at timestamptz,
  status_updated_by uuid references public.profiles(id) on delete restrict,
  updated_at timestamptz not null default now(),
  unique(job_id, job_seeker_id),
  foreign key(resume_id, job_seeker_id) references public.resumes(id, job_seeker_id) on delete restrict
);
create index applications_owner_idx on public.applications(job_seeker_id, submitted_at desc);
create index applications_resume_idx on public.applications(resume_id);
create index applications_status_idx on public.applications(status, submitted_at desc);
create trigger touch_resumes before update on public.resumes
for each row execute function private.touch_updated_at();
create trigger touch_applications before update on public.applications
for each row execute function private.touch_updated_at();

create function private.can_read_job(target_job uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select private.is_active_administrator() or (private.is_active_job_seeker() and exists(
   select 1 from public.jobs j join public.employers e on e.id = j.employer_id
   where j.id = target_job and ((e.is_active and j.status = 'published' and
     (j.application_deadline is null or j.application_deadline > now())) or exists(
       select 1 from public.applications a where a.job_id = j.id and a.job_seeker_id = auth.uid()))));
$$;
create function private.can_read_employer(target_employer uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select private.is_active_administrator() or (private.is_active_job_seeker() and exists(
   select 1 from public.jobs j join public.employers e on e.id = j.employer_id
   where e.id = target_employer and ((e.is_active and j.status = 'published' and
     (j.application_deadline is null or j.application_deadline > now())) or exists(
       select 1 from public.applications a where a.job_id = j.id and a.job_seeker_id = auth.uid()))));
$$;
create function private.can_read_resume(target_resume uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.resumes r where r.id = target_resume and (
   (private.is_active_job_seeker() and r.job_seeker_id = auth.uid()) or
   (private.is_active_administrator() and r.upload_status = 'ready' and exists(
     select 1 from public.applications a where a.resume_id = r.id))));
$$;
create policy jobs_read on public.jobs for select to authenticated using (private.can_read_job(id));
create policy employers_read on public.employers for select to authenticated using (private.can_read_employer(id));
alter table public.resumes enable row level security;
alter table public.applications enable row level security;
revoke all on public.resumes, public.applications from public, anon, authenticated;
grant select on public.resumes, public.applications to authenticated;
grant update(title) on public.resumes to authenticated;
create policy resumes_read on public.resumes for select to authenticated using (private.can_read_resume(id));
create policy resumes_update_title on public.resumes for update to authenticated
using ((select private.is_active_job_seeker()) and job_seeker_id = (select auth.uid()) and upload_status <> 'deleting')
with check ((select private.is_active_job_seeker()) and job_seeker_id = (select auth.uid()) and upload_status <> 'deleting');
create policy applications_read on public.applications for select to authenticated using (
  ((select private.is_active_job_seeker()) and job_seeker_id = (select auth.uid())) or
  (select private.is_active_administrator()));
revoke execute on function private.can_read_job(uuid), private.can_read_employer(uuid),
  private.can_read_resume(uuid) from public, anon, authenticated;
grant execute on function private.can_read_job(uuid), private.can_read_employer(uuid),
  private.can_read_resume(uuid) to authenticated;
commit;
