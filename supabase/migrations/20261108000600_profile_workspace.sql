-- Phase 2: transactional self-service editing and exact own-application aggregates.
-- SECURITY INVOKER preserves Phase 1 table grants and RLS; no new system role/table.
begin;
create function private.profile_text_array(value jsonb, maximum integer) returns text[]
language plpgsql immutable security invoker set search_path = '' as $$
declare result text[];
begin
 if jsonb_typeof(value) is distinct from 'array' then
   raise exception 'An array of text is required' using errcode='23514'; end if;
 if jsonb_array_length(value)>maximum or exists(select 1 from jsonb_array_elements(value) item
   where jsonb_typeof(item) <> 'string' or length(btrim(item #>> '{}')) not between 1 and 120) then
   raise exception 'Invalid text list' using errcode='23514'; end if;
 select coalesce(array_agg(btrim(item)), '{}'::text[]) into result from jsonb_array_elements_text(value) item;
 return result;
end; $$;
revoke execute on function private.profile_text_array(jsonb,integer) from public,anon,authenticated;
grant execute on function private.profile_text_array(jsonb,integer) to authenticated;

create function public.my_job_seeker_profile() returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
declare result jsonb;
begin
 if not private.is_active_job_seeker() then raise exception 'Not authorized' using errcode='42501'; end if;
 select jsonb_build_object('profile',to_jsonb(p),'details',to_jsonb(s)) into result
 from public.profiles p join public.job_seeker_profiles s on s.user_id=p.id where p.id=auth.uid();
 if result is null then raise exception 'Profile unavailable' using errcode='42501'; end if;
 return result;
end; $$;

create function public.save_my_job_seeker_profile(p_profile jsonb,p_details jsonb,p_expected_updated_at timestamptz)
returns void language plpgsql security invoker set search_path = '' as $$
declare actual_version timestamptz; item record;
begin
 if not private.is_active_job_seeker() then raise exception 'Not authorized' using errcode='42501'; end if;
 if jsonb_typeof(p_profile) is distinct from 'object' or jsonb_typeof(p_details) is distinct from 'object' or
   (p_profile - array['full_name','phone']) <> '{}'::jsonb or
   (p_details - array['headline','summary','city','province','education_summary','experience_summary',
    'skills','preferred_job_types','preferred_work_arrangements','accommodation_needs']) <> '{}'::jsonb then
   raise exception 'Unexpected profile fields' using errcode='23514'; end if;
 if jsonb_typeof(p_profile->'full_name') is distinct from 'string' or
   length(btrim(p_profile->>'full_name')) not between 1 and 120 then
   raise exception 'A name is required' using errcode='23514'; end if;
 for item in select key,value from jsonb_each(p_profile) union all select key,value from jsonb_each(p_details) loop
   if item.key not in ('skills','preferred_job_types','preferred_work_arrangements') and
      jsonb_typeof(item.value) not in ('string','null') then
     raise exception 'Invalid text field' using errcode='23514'; end if;
 end loop;
 -- Compare a single joined read's timestamp to prevent overwriting another session's edits.
 -- FOR NO KEY UPDATE avoids requesting UPDATE privilege on protected id/timestamp columns.
 select updated_at into actual_version from public.profiles where id=auth.uid() for no key update;
 if not found then raise exception 'Profile unavailable' using errcode='42501'; end if;
 if p_expected_updated_at is null or actual_version is distinct from p_expected_updated_at then
   raise exception 'Profile changed; reload before saving' using errcode='40001'; end if;
 update public.profiles set full_name=btrim(p_profile->>'full_name'),phone=nullif(btrim(p_profile->>'phone'),'')
 where id=auth.uid();
 if not found then raise exception 'Profile unavailable' using errcode='42501'; end if;
 update public.job_seeker_profiles set
   headline=nullif(btrim(p_details->>'headline'),''),summary=nullif(btrim(p_details->>'summary'),''),
   city=nullif(btrim(p_details->>'city'),''),province=nullif(btrim(p_details->>'province'),''),
   education_summary=nullif(btrim(p_details->>'education_summary'),''),
   experience_summary=nullif(btrim(p_details->>'experience_summary'),''),
   accommodation_needs=nullif(btrim(p_details->>'accommodation_needs'),''),
   skills=private.profile_text_array(coalesce(p_details->'skills','[]'::jsonb),100),
   preferred_job_types=private.profile_text_array(coalesce(p_details->'preferred_job_types','[]'::jsonb),20),
   preferred_work_arrangements=private.profile_text_array(coalesce(p_details->'preferred_work_arrangements','[]'::jsonb),20)
 where user_id=auth.uid();
 if not found then raise exception 'Profile unavailable' using errcode='42501'; end if;
end; $$;

create function public.my_application_counts() returns table(status public.application_status,total bigint)
language plpgsql stable security invoker set search_path = '' as $$
begin
 if not private.is_active_job_seeker() then raise exception 'Not authorized' using errcode='42501'; end if;
 return query select a.status,count(*) from public.applications a where a.job_seeker_id=auth.uid() group by a.status;
end; $$;
revoke execute on function public.my_job_seeker_profile(),
 public.save_my_job_seeker_profile(jsonb,jsonb,timestamptz),public.my_application_counts() from public,anon,authenticated;
grant execute on function public.my_job_seeker_profile(),
 public.save_my_job_seeker_profile(jsonb,jsonb,timestamptz),public.my_application_counts() to authenticated;
commit;
