alter table public.family_children
  add column if not exists child_user_id uuid unique references auth.users(id) on delete set null,
  add column if not exists messaging_enabled boolean not null default false,
  add column if not exists friend_code text not null default upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 10));
create unique index if not exists family_children_friend_code_uidx on public.family_children(friend_code);
create table if not exists private.kids_pin_credentials (
 child_id uuid primary key references public.family_children(id) on delete cascade,
 pin_hash text not null, failed_attempts integer not null default 0 check(failed_attempts between 0 and 5),
 locked_until timestamptz, updated_at timestamptz not null default now()
);
alter table private.kids_pin_credentials enable row level security;
revoke all on private.kids_pin_credentials from public,anon,authenticated,service_role;
create table if not exists public.kids_friendships (
 id uuid primary key default gen_random_uuid(), child_a_id uuid not null references public.family_children(id) on delete cascade,
 child_b_id uuid not null references public.family_children(id) on delete cascade,
 requested_by uuid not null references public.family_children(id) on delete cascade,
 parent_a_approved boolean not null default false, parent_b_approved boolean not null default false,
 status text not null default 'pending' check(status in ('pending','approved','rejected','blocked')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 constraint kids_friendships_distinct_children check(child_a_id<>child_b_id),
 constraint kids_friendships_requester_is_participant check(requested_by=child_a_id or requested_by=child_b_id)
);
create unique index if not exists kids_friendships_pair_uidx on public.kids_friendships(least(child_a_id,child_b_id),greatest(child_a_id,child_b_id));
create index if not exists kids_friendships_child_a_idx on public.kids_friendships(child_a_id,status);
create index if not exists kids_friendships_child_b_idx on public.kids_friendships(child_b_id,status);
create table if not exists public.kids_messages (
 id uuid primary key default gen_random_uuid(), friendship_id uuid not null references public.kids_friendships(id) on delete cascade,
 sender_child_id uuid not null references public.family_children(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 1000), created_at timestamptz not null default now()
);
create index if not exists kids_messages_friendship_created_idx on public.kids_messages(friendship_id,created_at);
create table if not exists public.kids_safety_reports (
 id uuid primary key default gen_random_uuid(), friendship_id uuid not null references public.kids_friendships(id) on delete cascade,
 message_id uuid references public.kids_messages(id) on delete set null,
 reporter_child_id uuid not null references public.family_children(id) on delete cascade,
 reason text not null check(reason in ('unkind','personal_information','bullying','something_else')),
 details text not null default '' check(char_length(details)<=1000),
 status text not null default 'open' check(status in ('open','reviewed','closed')), created_at timestamptz not null default now()
);
create index if not exists kids_safety_reports_friendship_idx on public.kids_safety_reports(friendship_id,created_at desc);
create or replace function private.is_kids_child(p_child_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.family_children c where c.id=p_child_id and c.child_user_id=(select auth.uid()));
$$;
create or replace function private.is_kids_parent(p_child_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.family_children c where c.id=p_child_id and c.parent_id=(select auth.uid()));
$$;
create or replace function private.can_access_kids_friendship(p_friendship_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.kids_friendships f join public.family_children a on a.id=f.child_a_id join public.family_children b on b.id=f.child_b_id
 where f.id=p_friendship_id and f.status='approved' and f.parent_a_approved and f.parent_b_approved
 and a.messaging_enabled and b.messaging_enabled and (a.child_user_id=(select auth.uid()) or b.child_user_id=(select auth.uid())));
$$;
revoke all on function private.is_kids_child(uuid),private.is_kids_parent(uuid),private.can_access_kids_friendship(uuid) from public,anon;
grant execute on function private.is_kids_child(uuid),private.is_kids_parent(uuid),private.can_access_kids_friendship(uuid) to authenticated;
create or replace function public.kids_set_pin(p_child_id uuid,p_parent_id uuid,p_child_user_id uuid,p_pin text) returns void language plpgsql security definer set search_path='' as $$
begin
 if p_pin !~ '^[0-9]{6}$' then raise exception 'PIN must be six digits'; end if;
 if not exists(select 1 from public.family_children c where c.id=p_child_id and c.parent_id=p_parent_id and c.child_user_id=p_child_user_id) then raise exception 'Child profile not found'; end if;
 insert into private.kids_pin_credentials(child_id,pin_hash,failed_attempts,locked_until,updated_at)
 values(p_child_id,extensions.crypt(p_pin,extensions.gen_salt('bf',12)),0,null,now())
 on conflict(child_id) do update set pin_hash=excluded.pin_hash,failed_attempts=0,locked_until=null,updated_at=now();
end; $$;
revoke all on function public.kids_set_pin(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.kids_set_pin(uuid,uuid,uuid,text) to service_role;
create or replace function public.kids_check_pin(p_child_id uuid,p_parent_id uuid,p_pin text) returns uuid language plpgsql security definer set search_path='' as $$
declare cred private.kids_pin_credentials%rowtype; linked_user uuid;
begin
 select c.child_user_id into linked_user from public.family_children c where c.id=p_child_id and c.parent_id=p_parent_id;
 if linked_user is null then raise exception 'Profile or PIN is not available'; end if;
 select * into cred from private.kids_pin_credentials where child_id=p_child_id for update;
 if not found then raise exception 'Profile or PIN is not available'; end if;
 if cred.locked_until is not null and cred.locked_until>now() then raise exception 'Too many attempts. Try again later.'; end if;
 if extensions.crypt(coalesce(p_pin,''),cred.pin_hash)<>cred.pin_hash then
  update private.kids_pin_credentials set failed_attempts=least(failed_attempts+1,5),locked_until=case when failed_attempts+1>=5 then now()+interval '15 minutes' else null end,updated_at=now() where child_id=p_child_id;
  raise exception 'Incorrect PIN';
 end if;
 update private.kids_pin_credentials set failed_attempts=0,locked_until=null,updated_at=now() where child_id=p_child_id;
 return linked_user;
end; $$;
revoke all on function public.kids_check_pin(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.kids_check_pin(uuid,uuid,text) to service_role;
create or replace function public.kids_send_friend_request(p_requester_child_id uuid,p_recipient_code text) returns uuid language plpgsql security definer set search_path='' as $$
declare recipient_id uuid; new_id uuid;
begin
 if not exists(select 1 from public.family_children c where c.id=p_requester_child_id and c.messaging_enabled and c.child_user_id is not null) then raise exception 'Messaging is not enabled for this profile'; end if;
 select id into recipient_id from public.family_children where friend_code=upper(btrim(p_recipient_code)) and messaging_enabled and child_user_id is not null;
 if recipient_id is null or recipient_id=p_requester_child_id then raise exception 'Friend code not found'; end if;
 insert into public.kids_friendships(child_a_id,child_b_id,requested_by) values(p_requester_child_id,recipient_id,p_requester_child_id) returning id into new_id;
 return new_id;
exception when unique_violation then raise exception 'A friend request already exists for these profiles'; end; $$;
revoke all on function public.kids_send_friend_request(uuid,text) from public,anon,authenticated;
grant execute on function public.kids_send_friend_request(uuid,text) to service_role;
create or replace function public.kids_parent_approve_friendship(p_friendship_id uuid,p_parent_id uuid,p_approve boolean) returns text language plpgsql security definer set search_path='' as $$
declare f public.kids_friendships%rowtype; owns_a boolean; owns_b boolean;
begin
 select * into f from public.kids_friendships where id=p_friendship_id for update;
 if not found or f.status<>'pending' then raise exception 'Pending friend request not found'; end if;
 owns_a:=exists(select 1 from public.family_children where id=f.child_a_id and parent_id=p_parent_id);
 owns_b:=exists(select 1 from public.family_children where id=f.child_b_id and parent_id=p_parent_id);
 if not owns_a and not owns_b then raise exception 'Not allowed to approve this request'; end if;
 if not p_approve then update public.kids_friendships set status='rejected',updated_at=now() where id=p_friendship_id; return 'rejected'; end if;
 update public.kids_friendships set parent_a_approved=parent_a_approved or owns_a,parent_b_approved=parent_b_approved or owns_b,
 status=case when (parent_a_approved or owns_a) and (parent_b_approved or owns_b) then 'approved' else 'pending' end,updated_at=now()
 where id=p_friendship_id returning status into f.status;
 return f.status;
end; $$;
revoke all on function public.kids_parent_approve_friendship(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.kids_parent_approve_friendship(uuid,uuid,boolean) to service_role;
create or replace function public.kids_my_friends() returns table(friendship_id uuid,friend_child_id uuid,friend_name text,status text,my_parent_approved boolean,friend_parent_approved boolean)
language sql stable security definer set search_path='' as $$
 select f.id,c.id,c.child_name,f.status,case when f.child_a_id=me.id then f.parent_a_approved else f.parent_b_approved end,
 case when f.child_a_id=me.id then f.parent_b_approved else f.parent_a_approved end
 from public.family_children me join public.kids_friendships f on f.child_a_id=me.id or f.child_b_id=me.id
 join public.family_children c on c.id=case when f.child_a_id=me.id then f.child_b_id else f.child_a_id end
 where me.child_user_id=(select auth.uid());
$$;
revoke all on function public.kids_my_friends() from public,anon;
grant execute on function public.kids_my_friends() to authenticated;
alter table public.kids_friendships enable row level security;
alter table public.kids_messages enable row level security;
alter table public.kids_safety_reports enable row level security;
revoke all on public.kids_friendships,public.kids_messages,public.kids_safety_reports from public,anon;
grant select on public.kids_friendships to authenticated;
grant select,insert on public.kids_messages to authenticated;
grant select,insert on public.kids_safety_reports to authenticated;
create policy kids_friendships_participant_or_parent_read on public.kids_friendships for select to authenticated using (
 (select private.is_kids_child(child_a_id)) or (select private.is_kids_child(child_b_id)) or
 (select private.is_kids_parent(child_a_id)) or (select private.is_kids_parent(child_b_id)));
create policy kids_messages_participants_read on public.kids_messages for select to authenticated using ((select private.can_access_kids_friendship(friendship_id)));
create policy kids_messages_participants_insert on public.kids_messages for insert to authenticated with check (
 (select private.is_kids_child(sender_child_id)) and (select private.can_access_kids_friendship(friendship_id)) and
 exists(select 1 from public.kids_friendships f where f.id=friendship_id and (f.child_a_id=sender_child_id or f.child_b_id=sender_child_id)));
create policy kids_reports_child_insert on public.kids_safety_reports for insert to authenticated with check (
 (select private.is_kids_child(reporter_child_id)) and exists(select 1 from public.kids_friendships f where f.id=friendship_id and (f.child_a_id=reporter_child_id or f.child_b_id=reporter_child_id)));
create policy kids_reports_parent_read on public.kids_safety_reports for select to authenticated using (
 exists(select 1 from public.kids_friendships f where f.id=friendship_id and ((select private.is_kids_parent(f.child_a_id)) or (select private.is_kids_parent(f.child_b_id)))));
