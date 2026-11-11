create table if not exists public.community_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'ConfigKit member',
  avatar_url text,
  bio text not null default '',
  is_discoverable boolean not null default true,
  updated_at timestamptz not null default now(),
  constraint community_profiles_display_name_length check (char_length(display_name) between 1 and 80),
  constraint community_profiles_bio_length check (char_length(bio) <= 500)
);
alter table public.community_profiles enable row level security;
grant select, insert, update on public.community_profiles to authenticated;
drop policy if exists "Members can view discoverable community profiles" on public.community_profiles;
create policy "Members can view discoverable community profiles" on public.community_profiles for select to authenticated using (is_discoverable or user_id = (select auth.uid()));
drop policy if exists "Members can create their own community profile" on public.community_profiles;
create policy "Members can create their own community profile" on public.community_profiles for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Members can update their own community profile" on public.community_profiles;
create policy "Members can update their own community profile" on public.community_profiles for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create index if not exists community_profiles_discoverable_name_idx on public.community_profiles (is_discoverable, display_name);
create index if not exists user_follows_following_id_idx on public.user_follows (following_id);
create or replace function private.sync_community_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
declare profile_name text; profile_avatar text;
begin
 profile_name := coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''),nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),nullif(btrim(new.raw_user_meta_data ->> 'name'), ''),nullif(btrim(new.raw_user_meta_data ->> 'preferred_username'), ''),'ConfigKit member');
 profile_avatar := coalesce(nullif(new.raw_user_meta_data ->> 'avatar_url', ''),nullif(new.raw_user_meta_data ->> 'picture', ''));
 insert into public.community_profiles (user_id, display_name, avatar_url) values (new.id, left(profile_name, 80), profile_avatar)
 on conflict (user_id) do update set display_name = excluded.display_name, avatar_url = excluded.avatar_url, updated_at = now();
 return new;
end; $$;
revoke all on function private.sync_community_profile() from public, anon, authenticated;
drop trigger if exists sync_community_profile_on_auth_user on auth.users;
create trigger sync_community_profile_on_auth_user after insert or update of raw_user_meta_data on auth.users for each row execute function private.sync_community_profile();
insert into public.community_profiles (user_id, display_name, avatar_url)
select id,left(coalesce(nullif(btrim(raw_user_meta_data ->> 'display_name'), ''),nullif(btrim(raw_user_meta_data ->> 'full_name'), ''),nullif(btrim(raw_user_meta_data ->> 'name'), ''),nullif(btrim(raw_user_meta_data ->> 'preferred_username'), ''),'ConfigKit member'),80),coalesce(nullif(raw_user_meta_data ->> 'avatar_url', ''),nullif(raw_user_meta_data ->> 'picture', ''))
from auth.users on conflict (user_id) do nothing;
