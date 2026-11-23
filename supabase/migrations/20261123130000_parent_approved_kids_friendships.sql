-- Parent-to-parent approvals are the complete approval path for Kids peer chats.
-- Teachers may still have separate, parent-approved conversations with a child,
-- but are not required to approve a child's friendships or read peer conversations.

create or replace function private.can_access_kids_friendship(p_friendship_id uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists (
    select 1
    from public.kids_friendships f
    join public.family_children a on a.id=f.child_a_id
    join public.family_children b on b.id=f.child_b_id
    where f.id=p_friendship_id
      and f.status='approved'
      and f.parent_a_approved
      and f.parent_b_approved
      and a.messaging_enabled
      and b.messaging_enabled
      and (a.child_user_id=(select auth.uid()) or b.child_user_id=(select auth.uid()))
  );
$$;

revoke all on function private.can_access_kids_friendship(uuid) from public,anon;
grant execute on function private.can_access_kids_friendship(uuid) to authenticated;

create or replace function public.kids_parent_approve_friendship(
  p_friendship_id uuid,
  p_parent_id uuid,
  p_approve boolean
) returns text
language plpgsql
security definer
set search_path=''
as $$
declare
  f public.kids_friendships%rowtype;
  owns_a boolean;
  owns_b boolean;
begin
  if coalesce(auth.jwt() ? 'client_id',false) then
    raise exception 'OAuth client tokens cannot invoke privileged ConfigKit RPC functions' using errcode='42501';
  end if;

  select * into f
  from public.kids_friendships
  where id=p_friendship_id
  for update;

  if not found or f.status not in ('pending','approved') then
    raise exception 'Friend request not found';
  end if;

  owns_a:=exists(
    select 1 from public.family_children
    where id=f.child_a_id and parent_id=p_parent_id
  );
  owns_b:=exists(
    select 1 from public.family_children
    where id=f.child_b_id and parent_id=p_parent_id
  );

  if not owns_a and not owns_b then
    raise exception 'Not allowed to approve this request' using errcode='42501';
  end if;

  if not p_approve then
    update public.kids_friendships
    set status='rejected',updated_at=now()
    where id=p_friendship_id;
    return 'rejected';
  end if;

  update public.kids_friendships
  set
    parent_a_approved=parent_a_approved or owns_a,
    parent_b_approved=parent_b_approved or owns_b,
    status=case
      when (parent_a_approved or owns_a) and (parent_b_approved or owns_b) then 'approved'
      else 'pending'
    end,
    updated_at=now()
  where id=p_friendship_id
  returning status into f.status;

  return f.status;
end;
$$;

revoke all on function public.kids_parent_approve_friendship(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.kids_parent_approve_friendship(uuid,uuid,boolean) to service_role;

-- Existing requests already approved by both parents become active without
-- requiring a teacher's additional approval.
update public.kids_friendships f
set status='approved',updated_at=now()
from public.family_children a, public.family_children b
where f.child_a_id=a.id
  and f.child_b_id=b.id
  and f.status='pending'
  and f.parent_a_approved
  and f.parent_b_approved
  and a.messaging_enabled
  and b.messaging_enabled;
