-- ConfigKit Profile Library: private profile metadata, immutable versions, and owner-only Storage access.
create table public.configkit_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  description text not null default '' check (char_length(description) <= 2000),
  folder text not null default 'My Profiles' check (char_length(folder) between 1 and 80),
  tags text[] not null default '{}',
  is_favorite boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  configkit_search_vector tsvector generated always as (
    setweight(to_tsvector('simple', coalesce(name,'')), 'A') ||
    setweight(to_tsvector('simple', coalesce(description,'')), 'B') ||
    setweight(to_tsvector('simple', coalesce(folder,'')), 'C')
  ) stored
);
create index configkit_profiles_user_updated_idx on public.configkit_profiles(user_id, updated_at desc);
create index configkit_profiles_tags_idx on public.configkit_profiles using gin(tags);
create index configkit_profiles_search_idx on public.configkit_profiles using gin(configkit_search_vector);

create table public.configkit_profile_versions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.configkit_profiles(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  version_number integer not null check (version_number > 0),
  filename text not null check (char_length(filename) between 1 and 255),
  storage_path text not null unique,
  mime_type text not null default 'application/x-apple-aspen-config',
  file_size bigint not null check (file_size between 1 and 2097152),
  checksum text,
  notes text not null default '' check (char_length(notes) <= 1000),
  safety_report jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(profile_id, version_number),
  unique(profile_id, id)
);
create index configkit_profile_versions_profile_idx on public.configkit_profile_versions(profile_id, version_number desc);
create index configkit_profile_versions_user_idx on public.configkit_profile_versions(user_id, created_at desc);

alter table public.configkit_profiles enable row level security;
alter table public.configkit_profile_versions enable row level security;

create policy "Users manage their own ConfigKit profiles"
on public.configkit_profiles for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users read their own ConfigKit profile versions"
on public.configkit_profile_versions for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Users add versions to their own ConfigKit profiles"
on public.configkit_profile_versions for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1 from public.configkit_profiles p
    where p.id = profile_id and p.user_id = (select auth.uid())
  )
);

create policy "Users delete versions from their own ConfigKit profiles"
on public.configkit_profile_versions for delete to authenticated
using (
  (select auth.uid()) = user_id
  and exists (
    select 1 from public.configkit_profiles p
    where p.id = profile_id and p.user_id = (select auth.uid())
  )
);

revoke all on table public.configkit_profiles, public.configkit_profile_versions from anon, public;
grant select, insert, update, delete on table public.configkit_profiles to authenticated;
grant select, insert, delete on table public.configkit_profile_versions to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'configkit-profile-library',
  'configkit-profile-library',
  false,
  2097152,
  array['application/x-apple-aspen-config','application/xml','text/xml','application/octet-stream']
)
on conflict (id) do update set
  public = false,
  file_size_limit = 2097152,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Profile library owners read their own files" on storage.objects;
drop policy if exists "Profile library owners upload their own files" on storage.objects;
drop policy if exists "Profile library owners delete their own files" on storage.objects;

create policy "Profile library owners read their own files"
on storage.objects for select to authenticated
using (
  bucket_id = 'configkit-profile-library'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and array_length(storage.foldername(name),1) = 2
);

create policy "Profile library owners upload their own files"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'configkit-profile-library'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and array_length(storage.foldername(name),1) = 2
);

create policy "Profile library owners delete their own files"
on storage.objects for delete to authenticated
using (
  bucket_id = 'configkit-profile-library'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and array_length(storage.foldername(name),1) = 2
);
