alter table public.user_follows
  add constraint user_follows_no_self_follow check (follower_id <> following_id);
drop policy if exists "Users can follow as themselves" on public.user_follows;
create policy "Users can follow discoverable members"
on public.user_follows for insert to authenticated
with check (
  follower_id = (select auth.uid())
  and follower_id <> following_id
  and exists (
    select 1 from public.community_profiles cp
    where cp.user_id = following_id and cp.is_discoverable = true
  )
);