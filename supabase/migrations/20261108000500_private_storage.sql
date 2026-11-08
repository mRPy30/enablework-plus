begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('resumes','resumes',false,5242880,array['application/pdf'])
on conflict(id) do update set public=false,file_size_limit=5242880,allowed_mime_types=array['application/pdf'];

create function private.can_read_resume_object(object_path text) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.resumes r where r.storage_path=object_path and private.can_read_resume(r.id));
$$;
create function private.can_upload_resume_object(object_path text) returns boolean
language sql stable security definer set search_path = '' as $$
 select private.is_active_job_seeker() and exists(select 1 from public.resumes r
   where r.storage_path=object_path and r.job_seeker_id=auth.uid() and r.upload_status='pending');
$$;
create function private.can_delete_resume_object(object_path text) returns boolean
language sql stable security definer set search_path = '' as $$
 select private.is_active_job_seeker() and exists(select 1 from public.resumes r
   where r.storage_path=object_path and r.job_seeker_id=auth.uid() and r.upload_status='deleting'
   and not exists(select 1 from public.applications a where a.resume_id=r.id));
$$;
revoke execute on function private.can_read_resume_object(text), private.can_upload_resume_object(text),
  private.can_delete_resume_object(text) from public, anon, authenticated;
grant execute on function private.can_read_resume_object(text), private.can_upload_resume_object(text),
  private.can_delete_resume_object(text) to authenticated;
-- storage.objects is managed by Supabase; add policies, never replace the managed schema.
create policy enablework_resume_read on storage.objects for select to authenticated
using (bucket_id='resumes' and private.can_read_resume_object(name));
create policy enablework_resume_upload on storage.objects for insert to authenticated
with check (bucket_id='resumes' and owner_id=(select auth.uid())::text and private.can_upload_resume_object(name));
create policy enablework_resume_delete on storage.objects for delete to authenticated
using (bucket_id='resumes' and private.can_delete_resume_object(name));
-- Intentionally no UPDATE policy: uploads are immutable and upsert is forbidden.

create function public.finalize_resume_upload(p_resume_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare r public.resumes%rowtype; object_metadata jsonb; bytes bigint;
begin
 select * into r from public.resumes where id=p_resume_id for update;
 if r.id is null or r.upload_status <> 'pending' then
   raise exception 'Pending resume required' using errcode='23514'; end if;
 if not exists(select 1 from public.profiles where id=r.job_seeker_id and role='job_seeker' and account_status='active') then
   raise exception 'Active owner required' using errcode='42501'; end if;
 select metadata into object_metadata from storage.objects
 where bucket_id='resumes' and name=r.storage_path;
 if object_metadata is null or coalesce(object_metadata ->> 'mimetype','') <> 'application/pdf' then
   raise exception 'Uploaded PDF required' using errcode='23514'; end if;
 bytes := (object_metadata ->> 'size')::bigint;
 if bytes is null or bytes not between 1 and 5242880 then
   raise exception 'Invalid file size' using errcode='23514'; end if;
 update public.resumes set upload_status='ready',size_bytes=bytes where id=p_resume_id;
end; $$;
-- Only the verified file-finalization Edge Function uses this server-only RPC.
revoke execute on function public.finalize_resume_upload(uuid) from public, anon, authenticated;
grant execute on function public.finalize_resume_upload(uuid) to service_role;

create function public.complete_resume_deletion(p_resume_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare r public.resumes%rowtype;
begin
 if not private.is_active_job_seeker() then raise exception 'Not authorized' using errcode='42501'; end if;
 select * into r from public.resumes where id=p_resume_id and job_seeker_id=auth.uid() for update;
 if r.id is null or r.upload_status <> 'deleting' then
   raise exception 'Deletion has not started' using errcode='23514'; end if;
 if exists(select 1 from storage.objects where bucket_id='resumes' and name=r.storage_path) then
   raise exception 'Remove the Storage object through the Storage API first' using errcode='23514'; end if;
 delete from public.resumes where id=p_resume_id;
end; $$;
revoke execute on function public.complete_resume_deletion(uuid) from public, anon, authenticated;
grant execute on function public.complete_resume_deletion(uuid) to authenticated;
commit;
