create table if not exists public.configkit_apps (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 100),
  description text not null default '' check (char_length(description) <= 2000),
  category text not null default 'Other' check (category in ('Productivity','Utilities','Education','Games','Developer tools','Security','Other')),
  supported_os text[] not null default array['web']::text[],
  delivery_type text not null check (delivery_type in ('file','link')),
  file_path text,
  file_name text,
  redirect_url text,
  version text not null default '' check (char_length(version) <= 40),
  status text not null default 'draft' check (status in ('draft','published','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint configkit_apps_os_check check (cardinality(supported_os) > 0 and supported_os <@ array['ios','android','windows','macos','linux','web']::text[]),
  constraint configkit_apps_delivery_check check (
    (delivery_type = 'file' and file_path is not null and file_name is not null and redirect_url is null)
    or (delivery_type = 'link' and redirect_url is not null and file_path is null and file_name is null)
  ),
  constraint configkit_apps_https_link_check check (redirect_url is null or redirect_url ~ '^https://')
);
create index if not exists configkit_apps_published_updated_idx on public.configkit_apps(status, updated_at desc);
create index if not exists configkit_apps_owner_updated_idx on public.configkit_apps(owner_id, updated_at desc);
alter table public.configkit_apps enable row level security;
revoke all on public.configkit_apps from public, anon, authenticated;
grant select on public.configkit_apps to anon, authenticated;
grant insert, update, delete on public.configkit_apps to authenticated;
drop policy if exists "Published ConfigKit apps are visible" on public.configkit_apps;
create policy "Published ConfigKit apps are visible" on public.configkit_apps for select to anon, authenticated using (status = 'published');
drop policy if exists "App owners can view their apps" on public.configkit_apps;
create policy "App owners can view their apps" on public.configkit_apps for select to authenticated using (owner_id = (select auth.uid()));
drop policy if exists "Signed-in users can create their own apps" on public.configkit_apps;
create policy "Signed-in users can create their own apps" on public.configkit_apps for insert to authenticated with check (owner_id = (select auth.uid()));
drop policy if exists "App owners can update their apps" on public.configkit_apps;
create policy "App owners can update their apps" on public.configkit_apps for update to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
drop policy if exists "App owners can delete their apps" on public.configkit_apps;
create policy "App owners can delete their apps" on public.configkit_apps for delete to authenticated using (owner_id = (select auth.uid()));
drop policy if exists "ConfigKit apps require verified session" on public.configkit_apps;
create policy "ConfigKit apps require verified session" on public.configkit_apps as restrictive for all to authenticated using (private.email_2fa_access_allowed()) with check (private.email_2fa_access_allowed());
drop policy if exists "ConfigKit apps block OAuth client tokens" on public.configkit_apps;
create policy "ConfigKit apps block OAuth client tokens" on public.configkit_apps as restrictive for all to authenticated using ((select auth.jwt() ->> 'client_id') is null) with check ((select auth.jwt() ->> 'client_id') is null);
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('configkit-app-files','configkit-app-files',false,262144000,null)
on conflict (id) do update set public=false,file_size_limit=262144000,allowed_mime_types=null;
drop policy if exists "App owners upload their own app files" on storage.objects;
create policy "App owners upload their own app files" on storage.objects for insert to authenticated with check (bucket_id='configkit-app-files' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "App owners read their own app files" on storage.objects;
create policy "App owners read their own app files" on storage.objects for select to authenticated using (bucket_id='configkit-app-files' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Published app files can be downloaded by signed-in users" on storage.objects;
create policy "Published app files can be downloaded by signed-in users" on storage.objects for select to authenticated using (
  bucket_id='configkit-app-files' and exists (
    select 1 from public.configkit_apps a
    where a.file_path=storage.objects.name and a.status='published'
  )
);
drop policy if exists "App owners update their own app files" on storage.objects;
create policy "App owners update their own app files" on storage.objects for update to authenticated using (bucket_id='configkit-app-files' and (storage.foldername(name))[1]=(select auth.uid())::text) with check (bucket_id='configkit-app-files' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "App owners delete their own app files" on storage.objects;
create policy "App owners delete their own app files" on storage.objects for delete to authenticated using (bucket_id='configkit-app-files' and (storage.foldername(name))[1]=(select auth.uid())::text);
