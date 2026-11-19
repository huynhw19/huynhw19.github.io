-- A teacher's approval remains valid only while that teacher is still linked to both students by parent-approved Education links.
create or replace function private.can_access_kids_friendship(p_friendship_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
 select exists(
   select 1 from public.kids_friendships f
   join public.family_children a on a.id=f.child_a_id
   join public.family_children b on b.id=f.child_b_id
   where f.id=p_friendship_id and f.status='approved'
     and f.parent_a_approved and f.parent_b_approved
     and f.teacher_approved_at is not null and f.teacher_approved_by is not null
     and private.kids_is_linked_teacher(f.child_a_id,f.teacher_approved_by)
     and private.kids_is_linked_teacher(f.child_b_id,f.teacher_approved_by)
     and a.messaging_enabled and b.messaging_enabled
     and (a.child_user_id=(select auth.uid()) or b.child_user_id=(select auth.uid()))
 );
$$;
create or replace function public.kids_my_friends_with_teacher_approval()
returns table(friendship_id uuid,friend_child_id uuid,friend_name text,status text,my_parent_approved boolean,friend_parent_approved boolean,teacher_approved boolean)
language sql stable security invoker set search_path=''
as $$
 select f.id,c.id,c.child_name,f.status,
   case when f.child_a_id=me.id then f.parent_a_approved else f.parent_b_approved end,
   case when f.child_a_id=me.id then f.parent_b_approved else f.parent_a_approved end,
   f.teacher_approved_at is not null and f.teacher_approved_by is not null
     and private.kids_is_linked_teacher(f.child_a_id,f.teacher_approved_by)
     and private.kids_is_linked_teacher(f.child_b_id,f.teacher_approved_by)
 from public.family_children me
 join public.kids_friendships f on f.child_a_id=me.id or f.child_b_id=me.id
 join public.family_children c on c.id=case when f.child_a_id=me.id then f.child_b_id else f.child_a_id end
 where me.child_user_id=(select auth.uid());
$$;
