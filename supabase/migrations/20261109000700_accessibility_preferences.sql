-- Accessibility preference data foundation. Local only; no new UI/capability.
begin;
create function private.valid_preference_selection(items text[], allowed text[])
returns boolean language sql immutable security invoker set search_path = '' as $$
 select items is not null and items <@ allowed
   and cardinality(items) <= cardinality(allowed)
   and coalesce(array_ndims(items), 1) = 1
   and (cardinality(items) = 0 or array_lower(items, 1) = 1)
   and array_position(items, null) is null
   and cardinality(items) = (select count(distinct item) from unnest(items) item);
$$;
revoke execute on function private.valid_preference_selection(text[],text[])
 from public, anon, authenticated;
grant execute on function private.valid_preference_selection(text[],text[]) to authenticated;
alter table public.accessibility_preferences
 add column accessibility_needs text[] not null default '{}',
 add column enabled_features text[] not null default '{}',
 add column preferences_reviewed boolean not null default false,
 add constraint accessibility_needs_allowed check (
   private.valid_preference_selection(accessibility_needs,
     array['visual','mobility','hearing','speech','intellectual','learning','psychosocial'])),
 add constraint enabled_features_allowed check (
   private.valid_preference_selection(enabled_features,
     array['voice_guidance','text_to_speech','voice_search','simplified_language','step_by_step_guidance']));
-- Candidate IDs scheduled for a later feature phase; no runtime capability is
-- implemented, advertised or activated by this data migration.
comment on column public.accessibility_preferences.enabled_features is
 'Explicit private choices; capability implementations and UI follow separately.';
comment on column public.accessibility_preferences.preferences_reviewed is
 'Explicit UI review only; not legal consent, diagnosis, or authorization.';
-- Existing active-owner RLS and original column grants remain intact.
grant update(accessibility_needs, enabled_features, preferences_reviewed)
 on public.accessibility_preferences to authenticated;
commit;
