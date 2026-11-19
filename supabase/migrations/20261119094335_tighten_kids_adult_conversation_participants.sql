drop policy if exists kids_adult_conversations_related_insert on public.kids_adult_conversations;
create policy kids_adult_conversations_related_insert on public.kids_adult_conversations for insert to authenticated with check (
 exists(select 1 from public.family_children c where c.id=kids_adult_conversations.child_id and ((c.parent_id=(select auth.uid()) and kids_adult_conversations.adult_user_id=(select auth.uid())) or (c.child_user_id=(select auth.uid()) and (kids_adult_conversations.adult_user_id=c.parent_id or private.kids_teacher_contact_allowed(c.id,kids_adult_conversations.adult_user_id))) or (kids_adult_conversations.adult_user_id=(select auth.uid()) and private.kids_teacher_contact_allowed(c.id,(select auth.uid())))))
);
drop policy if exists kids_adult_messages_related_insert on public.kids_adult_messages;
create policy kids_adult_messages_related_insert on public.kids_adult_messages for insert to authenticated with check (
 sender_user_id=(select auth.uid()) and exists(select 1 from public.kids_adult_conversations v join public.family_children c on c.id=v.child_id where v.id=kids_adult_messages.conversation_id and ((c.parent_id=(select auth.uid()) and v.adult_user_id=(select auth.uid())) or (c.child_user_id=(select auth.uid()) and (v.adult_user_id=c.parent_id or private.kids_teacher_contact_allowed(c.id,v.adult_user_id))) or (v.adult_user_id=(select auth.uid()) and private.kids_teacher_contact_allowed(c.id,(select auth.uid())))))
);
