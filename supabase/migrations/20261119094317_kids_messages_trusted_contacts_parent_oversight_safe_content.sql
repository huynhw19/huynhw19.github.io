-- Trusted adult messaging, teacher approval, parent visibility, and safe content.
alter table public.kids_friendships add column if not exists teacher_approved_by uuid references auth.users(id) on delete set null, add column if not exists teacher_approved_at timestamptz;
alter table public.kids_messages add column if not exists message_kind text not null default 'text', add column if not exists drawing_data jsonb;
alter table public.kids_messages add constraint kids_messages_safe_content_only check (
 media_path is null and media_type is null and media_name is null and message_kind in ('text','sticker','drawing')
 and char_length(body) between 1 and 1000
 and case when message_kind='drawing' then drawing_data is not null and jsonb_typeof(drawing_data)='array' and pg_column_size(drawing_data)<=12000 and jsonb_array_length(drawing_data) between 1 and 40 else drawing_data is null end
);
create table if not exists public.kids_teacher_contacts (
 id uuid primary key default gen_random_uuid(), child_id uuid not null references public.family_children(id) on delete cascade,
 teacher_user_id uuid not null references auth.users(id) on delete cascade, requested_at timestamptz not null default now(),
 approved_at timestamptz, approved_by uuid references auth.users(id) on delete set null, unique(child_id,teacher_user_id)
);
create index if not exists kids_teacher_contacts_teacher_idx on public.kids_teacher_contacts(teacher_user_id,approved_at);
create table if not exists public.kids_adult_conversations (
 id uuid primary key default gen_random_uuid(), child_id uuid not null references public.family_children(id) on delete cascade,
 adult_user_id uuid not null references auth.users(id) on delete cascade, created_at timestamptz not null default now(), unique(child_id,adult_user_id)
);
create index if not exists kids_adult_conversations_child_idx on public.kids_adult_conversations(child_id,created_at desc);
create table if not exists public.kids_adult_messages (
 id uuid primary key default gen_random_uuid(), conversation_id uuid not null references public.kids_adult_conversations(id) on delete cascade,
 sender_user_id uuid not null default auth.uid() references auth.users(id) on delete cascade, body text not null check(char_length(body) between 1 and 1000),
 message_kind text not null default 'text' check(message_kind in ('text','sticker','drawing')), drawing_data jsonb, created_at timestamptz not null default now(),
 constraint kids_adult_messages_safe_content check (
 char_length(body) between 1 and 1000 and case when message_kind='drawing' then drawing_data is not null and jsonb_typeof(drawing_data)='array' and pg_column_size(drawing_data)<=12000 and jsonb_array_length(drawing_data) between 1 and 40 else drawing_data is null end
 )
);
create index if not exists kids_adult_messages_conversation_created_idx on public.kids_adult_messages(conversation_id,created_at);
create or replace function private.kids_is_linked_teacher(p_child_id uuid,p_teacher_id uuid default auth.uid()) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.family_children c join public.education_students s on s.student_user_id=c.child_user_id where c.id=p_child_id and s.user_id=p_teacher_id);
$$;
create or replace function private.kids_teacher_contact_allowed(p_child_id uuid,p_teacher_id uuid default auth.uid()) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.kids_teacher_contacts t where t.child_id=p_child_id and t.teacher_user_id=p_teacher_id and t.approved_at is not null and private.kids_is_linked_teacher(p_child_id,p_teacher_id));
$$;
revoke all on function private.kids_is_linked_teacher(uuid,uuid),private.kids_teacher_contact_allowed(uuid,uuid) from public,anon;
grant execute on function private.kids_is_linked_teacher(uuid,uuid),private.kids_teacher_contact_allowed(uuid,uuid) to authenticated;
create or replace function private.can_access_kids_friendship(p_friendship_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.kids_friendships f join public.family_children a on a.id=f.child_a_id join public.family_children b on b.id=f.child_b_id where f.id=p_friendship_id and f.status='approved' and f.parent_a_approved and f.parent_b_approved and f.teacher_approved_at is not null and a.messaging_enabled and b.messaging_enabled and (a.child_user_id=(select auth.uid()) or b.child_user_id=(select auth.uid())));
$$;
revoke all on function private.can_access_kids_friendship(uuid) from public,anon;
grant execute on function private.can_access_kids_friendship(uuid) to authenticated;
create or replace function public.kids_my_friends_with_teacher_approval() returns table(friendship_id uuid,friend_child_id uuid,friend_name text,status text,my_parent_approved boolean,friend_parent_approved boolean,teacher_approved boolean) language sql stable security invoker set search_path='' as $$
 select f.id,c.id,c.child_name,f.status,case when f.child_a_id=me.id then f.parent_a_approved else f.parent_b_approved end,case when f.child_a_id=me.id then f.parent_b_approved else f.parent_a_approved end,f.teacher_approved_at is not null from public.family_children me join public.kids_friendships f on f.child_a_id=me.id or f.child_b_id=me.id join public.family_children c on c.id=case when f.child_a_id=me.id then f.child_b_id else f.child_a_id end where me.child_user_id=(select auth.uid());
$$;
revoke all on function public.kids_my_friends_with_teacher_approval() from public,anon;
grant execute on function public.kids_my_friends_with_teacher_approval() to authenticated;
create or replace function public.kids_teacher_approve_friendship(p_friendship_id uuid) returns text language plpgsql security definer set search_path='' as $$
declare f public.kids_friendships%rowtype;
begin
 if auth.uid() is null or coalesce(auth.jwt() ? 'client_id',false) then raise exception 'Not authorised' using errcode='42501'; end if;
 select * into f from public.kids_friendships where id=p_friendship_id for update;
 if not found or f.status not in ('pending','approved') then raise exception 'Friend request is not available'; end if;
 if not private.kids_is_linked_teacher(f.child_a_id,auth.uid()) or not private.kids_is_linked_teacher(f.child_b_id,auth.uid()) then raise exception 'Only a teacher linked to both students can approve this connection' using errcode='42501'; end if;
 update public.kids_friendships set teacher_approved_by=auth.uid(),teacher_approved_at=now(),status=case when parent_a_approved and parent_b_approved then 'approved' else 'pending' end,updated_at=now() where id=p_friendship_id returning status into f.status;
 return f.status;
end; $$;
revoke all on function public.kids_teacher_approve_friendship(uuid) from public,anon;
grant execute on function public.kids_teacher_approve_friendship(uuid) to authenticated;
create or replace function public.kids_parent_approve_friendship(p_friendship_id uuid,p_parent_id uuid,p_approve boolean) returns text language plpgsql security definer set search_path='' as $$
declare f public.kids_friendships%rowtype; owns_a boolean; owns_b boolean;
begin
 if auth.uid() is null or auth.uid()<>p_parent_id or coalesce(auth.jwt() ? 'client_id',false) then raise exception 'Not authorised' using errcode='42501'; end if;
 select * into f from public.kids_friendships where id=p_friendship_id for update;
 if not found or f.status not in ('pending','approved') then raise exception 'Friend request not found'; end if;
 owns_a:=exists(select 1 from public.family_children where id=f.child_a_id and parent_id=p_parent_id);
 owns_b:=exists(select 1 from public.family_children where id=f.child_b_id and parent_id=p_parent_id);
 if not owns_a and not owns_b then raise exception 'Not allowed to approve this request' using errcode='42501'; end if;
 if not p_approve then update public.kids_friendships set status='rejected',updated_at=now() where id=p_friendship_id; return 'rejected'; end if;
 update public.kids_friendships set parent_a_approved=parent_a_approved or owns_a,parent_b_approved=parent_b_approved or owns_b,status=case when (parent_a_approved or owns_a) and (parent_b_approved or owns_b) and teacher_approved_at is not null then 'approved' else 'pending' end,updated_at=now() where id=p_friendship_id returning status into f.status;
 return f.status;
end; $$;
revoke all on function public.kids_parent_approve_friendship(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.kids_parent_approve_friendship(uuid,uuid,boolean) to service_role;
alter table public.kids_teacher_contacts enable row level security;
alter table public.kids_adult_conversations enable row level security;
alter table public.kids_adult_messages enable row level security;
revoke all on public.kids_teacher_contacts,public.kids_adult_conversations,public.kids_adult_messages from public,anon;
grant select on public.kids_teacher_contacts to authenticated;
grant select,insert on public.kids_adult_conversations to authenticated;
grant select,insert on public.kids_adult_messages to authenticated;
create policy kids_teacher_contacts_related_read on public.kids_teacher_contacts for select to authenticated using (
 exists(select 1 from public.family_children c where c.id=kids_teacher_contacts.child_id and (c.parent_id=(select auth.uid()) or c.child_user_id=(select auth.uid()))) or teacher_user_id=(select auth.uid())
);
create policy kids_adult_conversations_related_read on public.kids_adult_conversations for select to authenticated using (
 exists(select 1 from public.family_children c where c.id=kids_adult_conversations.child_id and (c.parent_id=(select auth.uid()) or c.child_user_id=(select auth.uid()) or (kids_adult_conversations.adult_user_id=(select auth.uid()) and private.kids_teacher_contact_allowed(c.id,(select auth.uid())))))
);
create policy kids_adult_conversations_related_insert on public.kids_adult_conversations for insert to authenticated with check (
 exists(select 1 from public.family_children c where c.id=kids_adult_conversations.child_id and ((c.parent_id=(select auth.uid()) and kids_adult_conversations.adult_user_id=(select auth.uid())) or (c.child_user_id=(select auth.uid()) and (kids_adult_conversations.adult_user_id=c.parent_id or private.kids_teacher_contact_allowed(c.id,kids_adult_conversations.adult_user_id))) or (kids_adult_conversations.adult_user_id=(select auth.uid()) and private.kids_teacher_contact_allowed(c.id,(select auth.uid())))))
);
create policy kids_adult_messages_related_read on public.kids_adult_messages for select to authenticated using (
 exists(select 1 from public.kids_adult_conversations v join public.family_children c on c.id=v.child_id where v.id=kids_adult_messages.conversation_id and (c.parent_id=(select auth.uid()) or c.child_user_id=(select auth.uid()) or (v.adult_user_id=(select auth.uid()) and private.kids_teacher_contact_allowed(c.id,(select auth.uid())))))
);
create policy kids_adult_messages_related_insert on public.kids_adult_messages for insert to authenticated with check (
 sender_user_id=(select auth.uid()) and exists(select 1 from public.kids_adult_conversations v join public.family_children c on c.id=v.child_id where v.id=kids_adult_messages.conversation_id and (c.parent_id=(select auth.uid()) or c.child_user_id=(select auth.uid()) or (v.adult_user_id=(select auth.uid()) and private.kids_teacher_contact_allowed(c.id,(select auth.uid())))))
);
drop policy if exists "Kids can upload media to approved chats" on storage.objects;
drop policy if exists kids_chat_media_upload_disabled on storage.objects;
create policy kids_chat_media_upload_disabled on storage.objects for insert to authenticated with check (bucket_id='kids-chat-media' and false);
