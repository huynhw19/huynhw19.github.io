create table public.configkit_backups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'ConfigKit backup' check (char_length(btrim(name)) between 1 and 120),
  storage_path text not null unique,
  file_size bigint not null check (file_size between 1 and 104857600),
  checksum text not null check (checksum ~ '^[0-9a-f]{64}$'),
  format_version integer not null default 1 check (format_version = 1),
  record_counts jsonb not null default '{}'::jsonb check (jsonb_typeof(record_counts) = 'object'),
  storage_file_count integer not null default 0 check (storage_file_count between 0 and 10000),
  created_at timestamptz not null default now()
);
create index configkit_backups_owner_created_idx on public.configkit_backups(user_id,created_at desc);
alter table public.configkit_backups enable row level security;
create policy "Users read their own ConfigKit backups" on public.configkit_backups for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users create their own ConfigKit backups" on public.configkit_backups for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users delete their own ConfigKit backups" on public.configkit_backups for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on table public.configkit_backups from public,anon;
grant select,insert,delete on table public.configkit_backups to authenticated;
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('configkit-account-backups','configkit-account-backups',false,104857600,array['application/json'])
on conflict (id) do update set public=false,file_size_limit=104857600,allowed_mime_types=array['application/json'];
create policy "Account owners read their own backup archives" on storage.objects for select to authenticated using (bucket_id='configkit-account-backups' and (storage.foldername(name))[1]=(select auth.uid())::text and array_length(storage.foldername(name),1)=2 and (storage.foldername(name))[2] ~* '^[0-9a-f-]{36}$');
create policy "Account owners upload their own backup archives" on storage.objects for insert to authenticated with check (bucket_id='configkit-account-backups' and (storage.foldername(name))[1]=(select auth.uid())::text and array_length(storage.foldername(name),1)=2 and (storage.foldername(name))[2] ~* '^[0-9a-f-]{36}$');
create policy "Account owners delete their own backup archives" on storage.objects for delete to authenticated using (bucket_id='configkit-account-backups' and (storage.foldername(name))[1]=(select auth.uid())::text and array_length(storage.foldername(name),1)=2 and (storage.foldername(name))[2] ~* '^[0-9a-f-]{36}$');
comment on table public.configkit_backups is 'Private per-user portable ConfigKit workspace backup archives. Archives are stored in a private Storage bucket.';
