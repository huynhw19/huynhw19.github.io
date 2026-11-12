create policy kids_pin_credentials_deny_direct_access
on private.kids_pin_credentials for all to public using (false) with check (false);
create index if not exists kids_friendships_requested_by_idx on public.kids_friendships(requested_by);
create index if not exists kids_messages_sender_child_idx on public.kids_messages(sender_child_id);
create index if not exists kids_safety_reports_message_idx on public.kids_safety_reports(message_id);
create index if not exists kids_safety_reports_reporter_idx on public.kids_safety_reports(reporter_child_id);
create or replace function private.kids_my_friends_internal()
returns table(friendship_id uuid,friend_child_id uuid,friend_name text,status text,my_parent_approved boolean,friend_parent_approved boolean)
language sql stable security definer set search_path='' as $$
 select f.id,c.id,c.child_name,f.status,
 case when f.child_a_id=me.id then f.parent_a_approved else f.parent_b_approved end,
 case when f.child_a_id=me.id then f.parent_b_approved else f.parent_a_approved end
 from public.family_children me join public.kids_friendships f on f.child_a_id=me.id or f.child_b_id=me.id
 join public.family_children c on c.id=case when f.child_a_id=me.id then f.child_b_id else f.child_a_id end
 where me.child_user_id=(select auth.uid());
$$;
revoke all on function private.kids_my_friends_internal() from public,anon;
grant execute on function private.kids_my_friends_internal() to authenticated;
create or replace function public.kids_my_friends()
returns table(friendship_id uuid,friend_child_id uuid,friend_name text,status text,my_parent_approved boolean,friend_parent_approved boolean)
language sql stable security invoker set search_path='' as $$
 select * from private.kids_my_friends_internal();
$$;
revoke all on function public.kids_my_friends() from public,anon;
grant execute on function public.kids_my_friends() to authenticated;