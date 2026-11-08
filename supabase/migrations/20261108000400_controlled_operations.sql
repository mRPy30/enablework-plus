begin;
create function public.submit_application(p_job_id uuid, p_resume_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare j public.jobs%rowtype; r public.resumes%rowtype; employer uuid; active boolean; result uuid;
begin
 if not private.is_active_job_seeker() then raise exception 'Not authorized' using errcode='42501'; end if;
 -- Consistent lock order: employer, job, resume. Employer reassignment is not client-writable.
 select employer_id into employer from public.jobs where id=p_job_id;
 select is_active into active from public.employers where id=employer for share;
 select * into j from public.jobs where id=p_job_id for share;
 if j.id is null or not coalesce(active,false) or j.status <> 'published' or
    (j.application_deadline is not null and j.application_deadline <= clock_timestamp()) then
   raise exception 'Job is not accepting applications' using errcode='23514'; end if;
 select * into r from public.resumes where id=p_resume_id for update;
 if r.id is null or r.job_seeker_id <> auth.uid() or r.upload_status <> 'ready' then
   raise exception 'An owned ready resume is required' using errcode='42501'; end if;
 insert into public.applications(job_id,job_seeker_id,resume_id)
 values(p_job_id,auth.uid(),p_resume_id) returning id into result;
 return result;
end; $$;

create function public.set_application_status(p_application_id uuid, p_status public.application_status) returns void
language plpgsql security definer set search_path = '' as $$
declare previous public.application_status;
begin
 if not private.is_active_administrator() then raise exception 'Not authorized' using errcode='42501'; end if;
 select status into previous from public.applications where id=p_application_id for update;
 if previous is null then raise exception 'Application not found' using errcode='P0002'; end if;
 if not ((previous='submitted' and p_status in ('under_review','rejected')) or
   (previous='under_review' and p_status in ('shortlisted','rejected')) or
   (previous='shortlisted' and p_status in ('hired','rejected'))) or p_status is null then
   raise exception 'Invalid status transition' using errcode='23514'; end if;
 update public.applications set status=p_status,status_updated_at=now(),status_updated_by=auth.uid()
 where id=p_application_id;
end; $$;

create function public.set_job_status(p_job_id uuid, p_status public.job_status) returns void
language plpgsql security definer set search_path = '' as $$
declare employer uuid; active boolean; j public.jobs%rowtype;
begin
 if not private.is_active_administrator() then raise exception 'Not authorized' using errcode='42501'; end if;
 select employer_id into employer from public.jobs where id=p_job_id;
 select is_active into active from public.employers where id=employer for share;
 select * into j from public.jobs where id=p_job_id for update;
 if j.id is null then raise exception 'Job not found' using errcode='P0002'; end if;
 if p_status is null or (p_status='published' and (not coalesce(active,false) or
   (j.application_deadline is not null and j.application_deadline <= clock_timestamp()))) then
   raise exception 'Job cannot be published' using errcode='23514'; end if;
 if p_status='draft' and exists(select 1 from public.applications where job_id=p_job_id) then
   raise exception 'A job with applications cannot return to draft' using errcode='23514'; end if;
 update public.jobs set status=p_status, published_at=case when p_status='published'
   then coalesce(published_at,now()) else published_at end, updated_by=auth.uid() where id=p_job_id;
end; $$;

create function public.set_job_seeker_status(p_user_id uuid, p_status public.account_status) returns void
language plpgsql security definer set search_path = '' as $$
begin
 if not private.is_active_administrator() then raise exception 'Not authorized' using errcode='42501'; end if;
 update public.profiles set account_status=p_status where id=p_user_id and role='job_seeker';
 if not found then raise exception 'Job seeker not found' using errcode='P0002'; end if;
end; $$;

create function public.begin_resume_upload(p_title text) returns public.resumes
language plpgsql security definer set search_path = '' as $$
declare result public.resumes; resume_id uuid := gen_random_uuid();
begin
 if not private.is_active_job_seeker() then raise exception 'Not authorized' using errcode='42501'; end if;
 insert into public.resumes(id,job_seeker_id,title,storage_path)
 values(resume_id,auth.uid(),p_title,auth.uid()::text||'/'||resume_id::text||'/resume.pdf') returning * into result;
 return result;
end; $$;

create function public.set_current_resume(p_resume_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
 if not private.is_active_job_seeker() then raise exception 'Not authorized' using errcode='42501'; end if;
 -- Serialize selections for this seeker, including when no current row exists.
 perform 1 from public.job_seeker_profiles where user_id=auth.uid() for update;
 perform 1 from public.resumes where id=p_resume_id and job_seeker_id=auth.uid() and upload_status='ready' for update;
 if not found then raise exception 'An owned ready resume is required' using errcode='42501'; end if;
 update public.resumes set is_current=false where job_seeker_id=auth.uid() and is_current;
 update public.resumes set is_current=true where id=p_resume_id;
end; $$;

create function public.begin_resume_deletion(p_resume_id uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare r public.resumes%rowtype;
begin
 if not private.is_active_job_seeker() then raise exception 'Not authorized' using errcode='42501'; end if;
 select * into r from public.resumes where id=p_resume_id and job_seeker_id=auth.uid() for update;
 if r.id is null then raise exception 'Resume not found' using errcode='42501'; end if;
 if exists(select 1 from public.applications where resume_id=p_resume_id) then
   raise exception 'Submitted resumes must be retained' using errcode='23503'; end if;
 update public.resumes set upload_status='deleting',is_current=false where id=p_resume_id;
 return r.storage_path;
end; $$;

-- Bootstrap is trusted SQL only, not an API/administrator UI capability.
create function private.bootstrap_administrator(p_user_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
 perform 1 from public.profiles where id=p_user_id for update;
 if not found then raise exception 'Auth user/profile must exist' using errcode='P0002'; end if;
 if exists(select 1 from public.resumes where job_seeker_id=p_user_id) or
    exists(select 1 from public.applications where job_seeker_id=p_user_id) then
   raise exception 'Cannot promote an account with seeker records' using errcode='23514'; end if;
 delete from public.job_seeker_profiles where user_id=p_user_id;
 update public.profiles set role='system_administrator' where id=p_user_id;
end; $$;
revoke execute on function private.bootstrap_administrator(uuid) from public, anon, authenticated, service_role;

-- Revoke default PUBLIC execute explicitly on every exposed privileged RPC.
do $$ declare fn record; begin
 for fn in select oid::regprocedure as signature from pg_proc where pronamespace='public'::regnamespace
   and proname in ('submit_application','set_application_status','set_job_status',
    'set_job_seeker_status','begin_resume_upload','set_current_resume','begin_resume_deletion') loop
   execute format('revoke execute on function %s from public, anon, authenticated',fn.signature);
   execute format('grant execute on function %s to authenticated',fn.signature);
 end loop;
end; $$;
commit;
