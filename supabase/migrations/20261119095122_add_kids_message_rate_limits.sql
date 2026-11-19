-- Apply a modest per-sender message rate limit across peer and trusted-adult chats.
create or replace function private.enforce_kids_message_rate_limit()
returns trigger language plpgsql security definer set search_path=''
as $$
declare sender uuid; recent_count integer;
begin
 if tg_table_name='kids_messages' then
   select child_user_id into sender from public.family_children where id=new.sender_child_id;
   if sender is null or sender<>(select auth.uid()) then raise exception 'Message sender is not the signed-in child' using errcode='42501'; end if;
   perform pg_advisory_xact_lock(hashtextextended(sender::text,0));
   select count(*)::integer into recent_count from public.kids_messages m join public.family_children c on c.id=m.sender_child_id where c.child_user_id=sender and m.created_at>now()-interval '1 minute';
 else
   sender:=new.sender_user_id;
   if sender is null or sender<>(select auth.uid()) then raise exception 'Message sender does not match the signed-in account' using errcode='42501'; end if;
   perform pg_advisory_xact_lock(hashtextextended(sender::text,0));
   select count(*)::integer into recent_count from public.kids_adult_messages m where m.sender_user_id=sender and m.created_at>now()-interval '1 minute';
 end if;
 if recent_count>=20 then raise exception 'Please wait a moment before sending more messages' using errcode='P0001'; end if;
 return new;
end;
$$;
revoke all on function private.enforce_kids_message_rate_limit() from public,anon,authenticated;
drop trigger if exists kids_messages_rate_limit on public.kids_messages;
create trigger kids_messages_rate_limit before insert on public.kids_messages for each row execute function private.enforce_kids_message_rate_limit();
drop trigger if exists kids_adult_messages_rate_limit on public.kids_adult_messages;
create trigger kids_adult_messages_rate_limit before insert on public.kids_adult_messages for each row execute function private.enforce_kids_message_rate_limit();
create index if not exists kids_messages_sender_created_idx on public.kids_messages(sender_child_id,created_at desc);
create index if not exists kids_adult_messages_sender_created_idx on public.kids_adult_messages(sender_user_id,created_at desc);
