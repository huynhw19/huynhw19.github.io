create or replace function private.kids_can_access_adult_conversation(p_conversation_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.kids_adult_conversations v join public.family_children c on c.id=v.child_id where v.id=p_conversation_id and (c.parent_id=(select auth.uid()) or (c.child_user_id=(select auth.uid()) and (v.adult_user_id=c.parent_id or private.kids_teacher_contact_allowed(c.id,v.adult_user_id))) or (v.adult_user_id=(select auth.uid()) and private.kids_teacher_contact_allowed(c.id,(select auth.uid())))));
$$;
revoke all on function public.kids_teacher_approve_friendship(uuid) from public,anon,authenticated;
