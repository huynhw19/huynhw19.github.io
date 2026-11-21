-- Member profile comments for discoverable ConfigKit profiles.
create table if not exists public.community_profile_comments (
  id uuid primary key default gen_random_uuid(),
  profile_user_id uuid not null references auth.users(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  constraint community_profile_comments_no_self check (profile_user_id <> author_user_id)
);
alter table public.community_profile_comments enable row level security;
revoke all on public.community_profile_comments from anon, public;
grant select, insert, delete on public.community_profile_comments to authenticated;
create index if not exists community_profile_comments_profile_created_idx
  on public.community_profile_comments(profile_user_id, created_at desc);
drop policy if exists "Members can read comments on discoverable profiles" on public.community_profile_comments;
create policy "Members can read comments on discoverable profiles"
  on public.community_profile_comments for select to authenticated
  using (exists (
    select 1 from public.community_profiles p
    where p.user_id = profile_user_id and p.is_discoverable = true
  ));
drop policy if exists "Members can comment on discoverable profiles" on public.community_profile_comments;
create policy "Members can comment on discoverable profiles"
  on public.community_profile_comments for insert to authenticated
  with check (
    author_user_id = (select auth.uid())
    and profile_user_id <> (select auth.uid())
    and exists (
      select 1 from public.community_profiles p
      where p.user_id = profile_user_id and p.is_discoverable = true
    )
  );
drop policy if exists "Authors can delete their own profile comments" on public.community_profile_comments;
create policy "Authors can delete their own profile comments"
  on public.community_profile_comments for delete to authenticated
  using (author_user_id = (select auth.uid()));
