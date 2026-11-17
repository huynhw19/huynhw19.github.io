create table public.configkit_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Untitled note' check (char_length(btrim(title)) between 1 and 200),
  content text not null default '' check (char_length(content) <= 100000),
  folder text not null default 'Personal' check (char_length(btrim(folder)) between 1 and 80),
  tags text[] not null default '{}',
  color text not null default 'sage' check (color = any (array['sage','blue','amber','rose','violet','slate'])),
  is_pinned boolean not null default false,
  is_favorite boolean not null default false,
  is_archived boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  configkit_search_vector tsvector generated always as (
    setweight(to_tsvector('simple', coalesce(title,'')), 'A') ||
    setweight(to_tsvector('simple', coalesce(content,'')), 'B') ||
    setweight(to_tsvector('simple', coalesce(folder,'')), 'C')
  ) stored,
  check (coalesce(array_length(tags,1),0) <= 30)
);
create index configkit_notes_owner_updated_idx on public.configkit_notes(user_id,updated_at desc) where deleted_at is null;
create index configkit_notes_owner_trash_idx on public.configkit_notes(user_id,deleted_at desc) where deleted_at is not null;
create index configkit_notes_owner_folder_idx on public.configkit_notes(user_id,folder);
create index configkit_notes_tags_idx on public.configkit_notes using gin(tags);
create index configkit_notes_search_idx on public.configkit_notes using gin(configkit_search_vector);
alter table public.configkit_notes enable row level security;
create policy "Users manage their own ConfigKit notes"
on public.configkit_notes for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
revoke all on table public.configkit_notes from public, anon;
grant usage on schema public to authenticated;
grant select,insert,update,delete on table public.configkit_notes to authenticated;
comment on table public.configkit_notes is 'Private per-user ConfigKit Notes. RLS restricts all rows to the owning authenticated user.';
