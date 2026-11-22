create table if not exists public.profile_photos (
  user_id uuid primary key references public.job_seeker_profiles(user_id) on delete cascade,
  storage_path text not null unique,
  content_type text not null check (content_type in ('image/jpeg','image/png','image/webp')),
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 20971520),
  updated_at timestamptz not null default now(),
  constraint profile_photos_path_owner check (storage_path = user_id::text || '/avatar')
);

alter table public.profile_photos enable row level security;

drop policy if exists "profile photos owner read" on public.profile_photos;
create policy "profile photos owner read" on public.profile_photos
  for select to authenticated using (user_id = (select auth.uid()));

create or replace function public.set_my_profile_photo(
  p_storage_path text, p_content_type text, p_size_bytes bigint
) returns public.profile_photos
language plpgsql security definer set search_path = public, pg_temp
as $$
declare result public.profile_photos;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if p_storage_path <> auth.uid()::text || '/avatar' then raise exception 'Invalid photo path'; end if;
  if p_content_type not in ('image/jpeg','image/png','image/webp') then raise exception 'Unsupported image type'; end if;
  if p_size_bytes <= 0 or p_size_bytes > 20971520 then raise exception 'Profile photo exceeds 20 MB'; end if;
  insert into public.profile_photos(user_id, storage_path, content_type, size_bytes)
    values (auth.uid(), p_storage_path, p_content_type, p_size_bytes)
  on conflict (user_id) do update set storage_path=excluded.storage_path,
    content_type=excluded.content_type, size_bytes=excluded.size_bytes, updated_at=now()
  returning * into result;
  return result;
end;
$$;
revoke all on function public.set_my_profile_photo(text,text,bigint) from public;
grant execute on function public.set_my_profile_photo(text,text,bigint) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', false, 20971520,
        array['image/jpeg','image/png','image/webp']::text[])
on conflict (id) do update set public=false, file_size_limit=20971520,
  allowed_mime_types=array['image/jpeg','image/png','image/webp']::text[];

drop policy if exists "profile photos owner select" on storage.objects;
create policy "profile photos owner select" on storage.objects for select to authenticated
  using (bucket_id='profile-photos' and owner_id=(select auth.uid())::text);
drop policy if exists "profile photos owner insert" on storage.objects;
create policy "profile photos owner insert" on storage.objects for insert to authenticated
  with check (bucket_id='profile-photos' and owner_id=(select auth.uid())::text
    and (storage.foldername(name))[1]=(select auth.uid())::text
    and name=(select auth.uid())::text || '/avatar');
drop policy if exists "profile photos owner update" on storage.objects;
create policy "profile photos owner update" on storage.objects for update to authenticated
  using (bucket_id='profile-photos' and owner_id=(select auth.uid())::text)
  with check (bucket_id='profile-photos' and owner_id=(select auth.uid())::text
    and name=(select auth.uid())::text || '/avatar');
drop policy if exists "profile photos owner delete" on storage.objects;
create policy "profile photos owner delete" on storage.objects for delete to authenticated
  using (bucket_id='profile-photos' and owner_id=(select auth.uid())::text);
