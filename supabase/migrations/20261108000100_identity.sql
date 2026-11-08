-- Local Phase 1 foundation. Never run against a hosted project without approval.
begin;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
revoke create on schema public from public, anon, authenticated;
grant usage on schema private to authenticated;

create type public.app_role as enum ('job_seeker', 'system_administrator');
create type public.account_status as enum ('active', 'suspended');
create type public.job_status as enum ('draft', 'published', 'inactive');
create type public.application_status as enum
  ('submitted', 'under_review', 'shortlisted', 'rejected', 'hired');
create type public.resume_upload_status as enum ('pending', 'ready', 'failed', 'deleting');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null default 'job_seeker',
  full_name text not null default '' check (length(full_name) <= 120),
  phone text check (length(phone) <= 32),
  account_status public.account_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.job_seeker_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  headline text check (length(headline) <= 180),
  summary text check (length(summary) <= 5000),
  city text check (length(city) <= 120),
  province text check (length(province) <= 120),
  education_summary text check (length(education_summary) <= 5000),
  experience_summary text check (length(experience_summary) <= 5000),
  skills text[] not null default '{}',
  preferred_job_types text[] not null default '{}',
  preferred_work_arrangements text[] not null default '{}',
  accommodation_needs text check (length(accommodation_needs) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (cardinality(skills) <= 100),
  check (cardinality(preferred_job_types) <= 20),
  check (cardinality(preferred_work_arrangements) <= 20)
);
create table public.accessibility_preferences (
  user_id uuid primary key references public.job_seeker_profiles(user_id) on delete cascade,
  text_scale numeric(3,2) not null default 1.00 check (text_scale between 0.80 and 2.00),
  high_contrast boolean not null default false,
  reduce_motion boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create function private.touch_updated_at() returns trigger language plpgsql
set search_path = '' as $$ begin new.updated_at := now(); return new; end; $$;
create trigger touch_profiles before update on public.profiles
for each row execute function private.touch_updated_at();
create trigger touch_seekers before update on public.job_seeker_profiles
for each row execute function private.touch_updated_at();
create trigger touch_preferences before update on public.accessibility_preferences
for each row execute function private.touch_updated_at();

create function private.require_seeker_parent() returns trigger language plpgsql
security definer set search_path = '' as $$
begin
 if not exists(select 1 from public.profiles where id=new.user_id and role='job_seeker') then
   raise exception 'Job-seeker parent required' using errcode='23514'; end if;
 return new;
end; $$;
create trigger require_seeker_parent before insert or update of user_id on public.job_seeker_profiles
for each row execute function private.require_seeker_parent();
create function private.require_admin_without_seeker_row() returns trigger language plpgsql
security definer set search_path = '' as $$
begin
 if new.role='system_administrator' and exists(select 1 from public.job_seeker_profiles where user_id=new.id) then
   raise exception 'Remove unused seeker row through trusted bootstrap first' using errcode='23514'; end if;
 return new;
end; $$;
create trigger require_admin_without_seeker_row before update of role on public.profiles
for each row execute function private.require_admin_without_seeker_row();
-- Role checks consult the database, never editable user metadata or stale JWT role claims.
create function private.is_active_job_seeker() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles
    where id = (select auth.uid()) and role = 'job_seeker' and account_status = 'active');
$$;
create function private.is_active_administrator() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles
    where id = (select auth.uid()) and role = 'system_administrator' and account_status = 'active');
$$;

create function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, role, full_name) values
    (new.id, 'job_seeker', left(coalesce(new.raw_user_meta_data ->> 'full_name', ''),120));
  insert into public.job_seeker_profiles(user_id) values (new.id);
  insert into public.accessibility_preferences(user_id) values (new.id);
  return new;
end; $$;
create trigger enablework_new_user after insert on auth.users
for each row execute function private.handle_new_user();

alter table public.profiles enable row level security;
alter table public.job_seeker_profiles enable row level security;
alter table public.accessibility_preferences enable row level security;
revoke all on public.profiles, public.job_seeker_profiles, public.accessibility_preferences
  from public, anon, authenticated;
grant select on public.profiles, public.job_seeker_profiles, public.accessibility_preferences to authenticated;
grant update(full_name, phone) on public.profiles to authenticated;
grant update(headline, summary, city, province, education_summary, experience_summary,
  skills, preferred_job_types, preferred_work_arrangements, accommodation_needs)
  on public.job_seeker_profiles to authenticated;
grant update(text_scale, high_contrast, reduce_motion) on public.accessibility_preferences to authenticated;

create policy profiles_read on public.profiles for select to authenticated using (
  (id = (select auth.uid()) and account_status = 'active') or
  ((select private.is_active_administrator()) and role = 'job_seeker'));
create policy profiles_update on public.profiles for update to authenticated
using (id = (select auth.uid()) and account_status = 'active')
with check (id = (select auth.uid()) and account_status = 'active');
create policy seekers_read on public.job_seeker_profiles for select to authenticated using (
  ((select private.is_active_job_seeker()) and user_id = (select auth.uid())) or
  (select private.is_active_administrator()));
create policy seekers_update on public.job_seeker_profiles for update to authenticated
using ((select private.is_active_job_seeker()) and user_id = (select auth.uid()))
with check ((select private.is_active_job_seeker()) and user_id = (select auth.uid()));
create policy preferences_read on public.accessibility_preferences for select to authenticated
using ((select private.is_active_job_seeker()) and user_id = (select auth.uid()));
create policy preferences_update on public.accessibility_preferences for update to authenticated
using ((select private.is_active_job_seeker()) and user_id = (select auth.uid()))
with check ((select private.is_active_job_seeker()) and user_id = (select auth.uid()));

revoke execute on all functions in schema private from public, anon, authenticated;
grant execute on function private.is_active_job_seeker(), private.is_active_administrator() to authenticated;
commit;
