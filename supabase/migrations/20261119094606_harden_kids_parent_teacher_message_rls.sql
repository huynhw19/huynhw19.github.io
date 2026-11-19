create or replace function private.kids_can_access_adult_conversation(p_conversation_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.kids_adult_conversations v join public.family_children c on c.id=v.child_id where v.id=p_conversation_id and (c.parent_id=(select auth.uid()) or c.child_user_id=(select auth.uid()) or (v.adult_user_id=(select auth.uid()) and private.kids_teacher_contact_allowed(c.id,(select auth.uid())))));
$$;
create or replace function private.kids_can_create_adult_conversation(p_child_id uuid,p_adult_user_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.family_children c where c.id=p_child_id and ((c.parent_id=(select auth.uid()) and p_adult_user_id=(select auth.uid())) or (c.child_user_id=(select auth.uid()) and (p_adult_user_id=c.parent_id or private.kids_teacher_contact_allowed(c.id,p_adult_user_id))) or (p_adult_user_id=(select auth.uid()) and private.kids_teacher_contact_allowed(c.id,(select auth.uid())))));
$$;
revoke all on function private.kids_can_access_adult_conversation(uuid),private.kids_can_create_adult_conversation(uuid,uuid) from public,anon;
grant execute on function private.kids_can_access_adult_conversation(uuid),private.kids_can_create_adult_conversation(uuid,uuid) to authenticated;
drop policy if exists kids_adult_conversations_related_read on public.kids_adult_conversations;
create policy kids_adult_conversations_related_read on public.kids_adult_conversations for select to authenticated using(private.kids_can_access_adult_conversation(id));
drop policy if exists kids_adult_conversations_related_insert on public.kids_adult_conversations;
create policy kids_adult_conversations_related_insert on public.kids_adult_conversations for insert to authenticated with check(private.kids_can_create_adult_conversation(child_id,adult_user_id));
drop policy if exists kids_adult_messages_related_read on public.kids_adult_messages;
create policy kids_adult_messages_related_read on public.kids_adult_messages for select to authenticated using(private.kids_can_access_adult_conversation(conversation_id));
drop policy if exists kids_adult_messages_related_insert on public.kids_adult_messages;
create policy kids_adult_messages_related_insert on public.kids_adult_messages for insert to authenticated with check(sender_user_id=(select auth.uid()) and private.kids_can_access_adult_conversation(conversation_id));
drop policy if exists kids_messages_parent_review on public.kids_messages;
create policy kids_messages_parent_review on public.kids_messages for select to authenticated using(exists(select 1 from public.kids_friendships f where f.id=kids_messages.friendship_id and (private.is_kids_parent(f.child_a_id) or private.is_kids_parent(f.child_b_id))));
