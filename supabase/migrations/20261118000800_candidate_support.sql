begin;

create type public.accommodation_request_status as enum ('requested','in_review','approved','declined','completed');
create type public.interview_status as enum ('scheduled','completed','cancelled');

create table public.accommodation_requests (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete restrict,
  job_seeker_id uuid not null references public.job_seeker_profiles(user_id) on delete restrict,
  request_type text not null check (request_type in ('interview_access','workplace_access','communication','other')),
  details text not null check (length(trim(details)) between 1 and 4000),
  status public.accommodation_request_status not null default 'requested',
  admin_note text check (admin_note is null or length(admin_note) <= 4000),
  reviewed_by uuid references public.profiles(id) on delete restrict,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((reviewed_by is null) = (reviewed_at is null))
);
create index accommodation_requests_owner_idx on public.accommodation_requests(job_seeker_id, created_at desc);
create index accommodation_requests_application_idx on public.accommodation_requests(application_id, status);

create table public.application_messages (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete restrict,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  body text not null check (length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index application_messages_application_idx on public.application_messages(application_id, created_at);

create table public.interviews (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete restrict,
  scheduled_at timestamptz not null,
  duration_minutes smallint not null check (duration_minutes between 15 and 480),
  location_or_link text not null check (length(trim(location_or_link)) between 1 and 1000),
  accessibility_notes text check (accessibility_notes is null or length(accessibility_notes) <= 4000),
  status public.interview_status not null default 'scheduled',
  created_by uuid not null default auth.uid() references public.profiles(id) on delete restrict,
  updated_at timestamptz not null default now()
);
create index interviews_application_idx on public.interviews(application_id, scheduled_at);

create trigger touch_accommodation_requests before update on public.accommodation_requests
for each row execute function private.touch_updated_at();
create trigger touch_interviews before update on public.interviews
for each row execute function private.touch_updated_at();

alter table public.accommodation_requests enable row level security;
alter table public.application_messages enable row level security;
alter table public.interviews enable row level security;
revoke all on public.accommodation_requests, public.application_messages, public.interviews from public, anon, authenticated;
grant select, insert on public.accommodation_requests, public.application_messages, public.interviews to authenticated;
grant update(status, admin_note, reviewed_by, reviewed_at) on public.accommodation_requests to authenticated;
grant update(scheduled_at, duration_minutes, location_or_link, accessibility_notes, status) on public.interviews to authenticated;

create policy accommodation_requests_read on public.accommodation_requests for select to authenticated using (
  (private.is_active_job_seeker() and job_seeker_id = auth.uid()) or private.is_active_administrator());
create policy accommodation_requests_create on public.accommodation_requests for insert to authenticated with check (
  private.is_active_job_seeker() and job_seeker_id = auth.uid() and exists (
    select 1 from public.applications a where a.id = application_id and a.job_seeker_id = auth.uid()));
create policy accommodation_requests_admin_update on public.accommodation_requests for update to authenticated using (private.is_active_administrator()) with check (private.is_active_administrator());

create policy application_messages_read on public.application_messages for select to authenticated using (
  private.is_active_administrator() or exists (select 1 from public.applications a where a.id = application_id and a.job_seeker_id = auth.uid() and private.is_active_job_seeker()));
create policy application_messages_create on public.application_messages for insert to authenticated with check (
  (private.is_active_administrator() or (private.is_active_job_seeker() and exists (select 1 from public.applications a where a.id = application_id and a.job_seeker_id = auth.uid()))) and sender_id = auth.uid());

create policy interviews_read on public.interviews for select to authenticated using (
  private.is_active_administrator() or exists (select 1 from public.applications a where a.id = application_id and a.job_seeker_id = auth.uid() and private.is_active_job_seeker()));
create policy interviews_admin_create on public.interviews for insert to authenticated with check (private.is_active_administrator());
create policy interviews_admin_update on public.interviews for update to authenticated using (private.is_active_administrator()) with check (private.is_active_administrator());

commit;
