-- Parents can review all child conversations but may only send in the parent-child thread; teachers and children can send only in their approved direct thread.
create or replace function private.kids_can_send_adult_message(p_conversation_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
 select exists(
   select 1 from public.kids_adult_conversations v
   join public.family_children c on c.id=v.child_id
   where v.id=p_conversation_id
     and (
       (c.parent_id=(select auth.uid()) and v.adult_user_id=(select auth.uid()))
       or (c.child_user_id=(select auth.uid()) and (v.adult_user_id=c.parent_id or private.kids_teacher_contact_allowed(c.id,v.adult_user_id)))
       or (v.adult_user_id=(select auth.uid()) and private.kids_teacher_contact_allowed(c.id,(select auth.uid())))
     )
 );
$$;
revoke all on function private.kids_can_send_adult_message(uuid) from public,anon;
grant execute on function private.kids_can_send_adult_message(uuid) to authenticated;
drop policy if exists kids_adult_messages_related_insert on public.kids_adult_messages;
create policy kids_adult_messages_related_insert on public.kids_adult_messages for insert to authenticated
with check(sender_user_id=(select auth.uid()) and private.kids_can_send_adult_message(conversation_id));
