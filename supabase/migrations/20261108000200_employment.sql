begin;
create table public.employers (
  id uuid primary key default gen_random_uuid(),
  company_name text not null check (length(trim(company_name)) between 1 and 180),
  description text check (length(description) <= 10000),
  website_url text check (website_url is null or website_url ~ '^https?://'),
  city text check (length(city) <= 120),
  province text check (length(province) <= 120),
  is_active boolean not null default true,
  created_by uuid not null default auth.uid() references public.profiles(id) on delete restrict,
  updated_by uuid not null default auth.uid() references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.employers(id) on delete restrict,
  title text not null check (length(trim(title)) between 1 and 180),
  description text not null check (length(trim(description)) between 1 and 20000),
  qualifications text not null check (length(trim(qualifications)) between 1 and 10000),
  required_skills text[] not null default '{}' check (cardinality(required_skills) <= 100),
  employment_type text not null check (employment_type in ('full_time','part_time','contract','internship')),
  work_arrangement text not null check (work_arrangement in ('onsite','remote','hybrid')),
  city text check (length(city) <= 120),
  province text check (length(province) <= 120),
  salary_min numeric(12,2) check (salary_min >= 0),
  salary_max numeric(12,2) check (salary_max >= 0),
  currency text not null default 'PHP' check (currency ~ '^[A-Z]{3}$'),
  accessibility_details text check (length(accessibility_details) <= 5000),
  status public.job_status not null default 'draft',
  published_at timestamptz,
  application_deadline timestamptz,
  created_by uuid not null default auth.uid() references public.profiles(id) on delete restrict,
  updated_by uuid not null default auth.uid() references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (salary_min is null or salary_max is null or salary_min <= salary_max),
  check (status <> 'published' or published_at is not null)
);
create index jobs_employer_idx on public.jobs(employer_id);
create index jobs_visibility_idx on public.jobs(status, application_deadline);
create function private.audit_record() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); new.updated_by := coalesce(auth.uid(), new.updated_by); return new; end;
$$;
create trigger audit_employers before update on public.employers
for each row execute function private.audit_record();
create trigger audit_jobs before update on public.jobs
for each row execute function private.audit_record();
alter table public.employers enable row level security;
alter table public.jobs enable row level security;
revoke all on public.employers, public.jobs from public, anon, authenticated;
grant select on public.employers, public.jobs to authenticated;
grant insert(company_name, description, website_url, city, province, is_active),
  update(company_name, description, website_url, city, province, is_active)
  on public.employers to authenticated;
grant insert(employer_id, title, description, qualifications, required_skills, employment_type,
  work_arrangement, city, province, salary_min, salary_max, currency, accessibility_details, application_deadline),
  update(title, description, qualifications, required_skills, employment_type, work_arrangement,
  city, province, salary_min, salary_max, currency, accessibility_details, application_deadline)
  on public.jobs to authenticated;
create policy employers_create on public.employers for insert to authenticated
with check ((select private.is_active_administrator()));
create policy employers_update on public.employers for update to authenticated
using ((select private.is_active_administrator())) with check ((select private.is_active_administrator()));
create policy jobs_create on public.jobs for insert to authenticated
with check ((select private.is_active_administrator()));
create policy jobs_update on public.jobs for update to authenticated
using ((select private.is_active_administrator())) with check ((select private.is_active_administrator()));
-- Read policies are installed after applications exists, to support historical access without recursion.
revoke execute on function private.audit_record() from public, anon, authenticated;
commit;
