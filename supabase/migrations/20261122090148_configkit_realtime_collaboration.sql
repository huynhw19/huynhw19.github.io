create schema if not exists private;

create table public.configkit_collab_documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 180),
  document_type text not null check (document_type in ('document','slides')),
  content jsonb not null default '{}'::jsonb
    check (jsonb_typeof(content) = 'object' and octet_length(content::text) <= 250000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.configkit_collab_members (
  document_id uuid not null references public.configkit_collab_documents(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','editor','viewer')),
  invited_by uuid references auth.users(id) on delete set null,
  joined_at timestamptz not null default now(),
  primary key (document_id,user_id)
);

create table public.configkit_collab_invites (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.configkit_collab_documents(id) on delete cascade,
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  role text not null check (role in ('editor','viewer')),
  invited_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by uuid references auth.users(id) on delete set null,
  revoked_at timestamptz,
  check (expires_at > created_at and expires_at <= created_at + interval '7 days')
);

create table public.configkit_collab_updates (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.configkit_collab_documents(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  update_b64 text not null check (char_length(update_b64) between 1 and 300000),
  created_at timestamptz not null default now()
);

create table public.configkit_collab_comments (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.configkit_collab_documents(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create table public.configkit_collab_snapshots (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.configkit_collab_documents(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  label text not null check (char_length(btrim(label)) between 1 and 100),
  state_b64 text not null check (char_length(state_b64) between 1 and 2000000),
  created_at timestamptz not null default now()
);

create index configkit_collab_members_user_idx on public.configkit_collab_members(user_id, joined_at desc);
create index configkit_collab_updates_document_idx on public.configkit_collab_updates(document_id, created_at, id);
create index configkit_collab_comments_document_idx on public.configkit_collab_comments(document_id, created_at desc);
create index configkit_collab_snapshots_document_idx on public.configkit_collab_snapshots(document_id, created_at desc);
create index configkit_collab_invites_document_idx on public.configkit_collab_invites(document_id, created_at desc);

alter table public.configkit_collab_documents enable row level security;
alter table public.configkit_collab_members enable row level security;
alter table public.configkit_collab_invites enable row level security;
alter table public.configkit_collab_updates enable row level security;
alter table public.configkit_collab_comments enable row level security;
alter table public.configkit_collab_snapshots enable row level security;

create or replace function private.configkit_collab_is_member(p_document_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.configkit_collab_members m
    where m.document_id = p_document_id and m.user_id = (select auth.uid())
  );
$$;

create or replace function private.configkit_collab_can_edit(p_document_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.configkit_collab_members m
    where m.document_id = p_document_id
      and m.user_id = (select auth.uid())
      and m.role in ('owner','editor')
  );
$$;

create or replace function private.configkit_collab_is_owner(p_document_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.configkit_collab_documents d
    where d.id = p_document_id and d.owner_id = (select auth.uid())
  );
$$;

create or replace function private.configkit_collab_can_access_topic(p_topic text)
returns boolean language plpgsql stable security definer set search_path = ''
as $$
declare v_document_id uuid;
begin
  if p_topic is null or p_topic !~ '^collab:[0-9a-fA-F-]{36}$' then return false; end if;
  begin v_document_id := pg_catalog.substr(p_topic, 8)::uuid;
  exception when others then return false;
  end;
  return private.configkit_collab_is_member(v_document_id);
end;
$$;

create or replace function private.configkit_collab_add_owner_member()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.configkit_collab_members(document_id,user_id,role,invited_by)
  values (new.id,new.owner_id,'owner',new.owner_id)
  on conflict (document_id,user_id) do nothing;
  return new;
end;
$$;

create trigger configkit_collab_add_owner_member
after insert on public.configkit_collab_documents
for each row execute function private.configkit_collab_add_owner_member();

create or replace function private.configkit_collab_accept_invite(p_token_hash text)
returns table(document_id uuid, role text)
language plpgsql security definer set search_path = ''
as $$
declare
  v_invite public.configkit_collab_invites%rowtype;
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'Sign in before accepting a collaboration invitation'; end if;
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then raise exception 'This collaboration invitation is invalid'; end if;
  select * into v_invite from public.configkit_collab_invites i
  where i.token_hash = p_token_hash and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()
  for update;
  if not found then raise exception 'This invitation has expired, been revoked, or was already used'; end if;
  if exists (select 1 from public.configkit_collab_members m where m.document_id = v_invite.document_id and m.user_id = v_user_id) then
    raise exception 'You already have access to this document';
  end if;
  insert into public.configkit_collab_members(document_id,user_id,role,invited_by)
  values (v_invite.document_id,v_user_id,v_invite.role,v_invite.invited_by);
  update public.configkit_collab_invites set accepted_at = now(), accepted_by = v_user_id where id = v_invite.id;
  return query select v_invite.document_id, v_invite.role;
end;
$$;

create or replace function public.configkit_accept_collab_invite(p_token_hash text)
returns table(document_id uuid, role text)
language sql security invoker set search_path = ''
as $$ select * from private.configkit_collab_accept_invite(p_token_hash); $$;

create or replace function private.configkit_collab_touch_document()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  update public.configkit_collab_documents set updated_at = now() where id = new.document_id;
  return new;
end;
$$;

create trigger configkit_collab_updates_touch after insert on public.configkit_collab_updates
for each row execute function private.configkit_collab_touch_document();
create trigger configkit_collab_comments_touch after insert on public.configkit_collab_comments
for each row execute function private.configkit_collab_touch_document();
create trigger configkit_collab_snapshots_touch after insert on public.configkit_collab_snapshots
for each row execute function private.configkit_collab_touch_document();

grant usage on schema private to authenticated;
revoke all on function private.configkit_collab_is_member(uuid) from public, anon;
revoke all on function private.configkit_collab_can_edit(uuid) from public, anon;
revoke all on function private.configkit_collab_is_owner(uuid) from public, anon;
revoke all on function private.configkit_collab_can_access_topic(text) from public, anon;
revoke all on function private.configkit_collab_accept_invite(text) from public, anon;
revoke all on function public.configkit_accept_collab_invite(text) from public, anon;
grant execute on function private.configkit_collab_is_member(uuid) to authenticated;
grant execute on function private.configkit_collab_can_edit(uuid) to authenticated;
grant execute on function private.configkit_collab_is_owner(uuid) to authenticated;
grant execute on function private.configkit_collab_can_access_topic(text) to authenticated;
grant execute on function private.configkit_collab_accept_invite(text) to authenticated;
grant execute on function public.configkit_accept_collab_invite(text) to authenticated;

grant select, insert, update, delete on public.configkit_collab_documents to authenticated;
grant select, insert, update, delete on public.configkit_collab_members to authenticated;
grant select, insert, update, delete on public.configkit_collab_invites to authenticated;
grant select, insert on public.configkit_collab_updates to authenticated;
grant select, insert, update, delete on public.configkit_collab_comments to authenticated;
grant select, insert, delete on public.configkit_collab_snapshots to authenticated;

create policy "Collaboration members can view documents"
on public.configkit_collab_documents for select to authenticated
using (private.configkit_collab_is_member(id));
create policy "Signed-in users can create their own collaboration documents"
on public.configkit_collab_documents for insert to authenticated
with check (owner_id = (select auth.uid()));
create policy "Editors can update collaboration document metadata"
on public.configkit_collab_documents for update to authenticated
using (private.configkit_collab_can_edit(id))
with check (private.configkit_collab_can_edit(id));
create policy "Owners can delete collaboration documents"
on public.configkit_collab_documents for delete to authenticated
using (private.configkit_collab_is_owner(id));

create policy "Collaboration members can view document members"
on public.configkit_collab_members for select to authenticated
using (private.configkit_collab_is_member(document_id));
create policy "Owners can add collaboration members"
on public.configkit_collab_members for insert to authenticated
with check (private.configkit_collab_is_owner(document_id) and role in ('editor','viewer'));
create policy "Owners can update collaboration member roles"
on public.configkit_collab_members for update to authenticated
using (private.configkit_collab_is_owner(document_id) and user_id <> (select auth.uid()))
with check (private.configkit_collab_is_owner(document_id) and user_id <> (select auth.uid()) and role in ('editor','viewer'));
create policy "Owners can remove members and members can leave"
on public.configkit_collab_members for delete to authenticated
using (
  user_id <> (select owner_id from public.configkit_collab_documents d where d.id = document_id)
  and (user_id = (select auth.uid()) or private.configkit_collab_is_owner(document_id))
);

create policy "Owners can view collaboration invitations"
on public.configkit_collab_invites for select to authenticated
using (private.configkit_collab_is_owner(document_id));
create policy "Owners can create collaboration invitations"
on public.configkit_collab_invites for insert to authenticated
with check (private.configkit_collab_is_owner(document_id) and invited_by = (select auth.uid())
  and role in ('editor','viewer') and expires_at > now() and expires_at <= now() + interval '7 days');
create policy "Owners can update collaboration invitations"
on public.configkit_collab_invites for update to authenticated
using (private.configkit_collab_is_owner(document_id))
with check (private.configkit_collab_is_owner(document_id));
create policy "Owners can delete collaboration invitations"
on public.configkit_collab_invites for delete to authenticated
using (private.configkit_collab_is_owner(document_id));

create policy "Members can read collaboration updates"
on public.configkit_collab_updates for select to authenticated
using (private.configkit_collab_is_member(document_id));
create policy "Editors can append collaboration updates"
on public.configkit_collab_updates for insert to authenticated
with check (private.configkit_collab_can_edit(document_id) and user_id = (select auth.uid()));

create policy "Members can read collaboration comments"
on public.configkit_collab_comments for select to authenticated
using (private.configkit_collab_is_member(document_id));
create policy "Members can add collaboration comments"
on public.configkit_collab_comments for insert to authenticated
with check (private.configkit_collab_is_member(document_id) and user_id = (select auth.uid()));
create policy "Authors and owners can edit collaboration comments"
on public.configkit_collab_comments for update to authenticated
using (user_id = (select auth.uid()) or private.configkit_collab_is_owner(document_id))
with check (user_id = (select auth.uid()) or private.configkit_collab_is_owner(document_id));
create policy "Authors and owners can delete collaboration comments"
on public.configkit_collab_comments for delete to authenticated
using (user_id = (select auth.uid()) or private.configkit_collab_is_owner(document_id));

create policy "Members can read collaboration snapshots"
on public.configkit_collab_snapshots for select to authenticated
using (private.configkit_collab_is_member(document_id));
create policy "Editors can create collaboration snapshots"
on public.configkit_collab_snapshots for insert to authenticated
with check (private.configkit_collab_can_edit(document_id) and user_id = (select auth.uid()));
create policy "Owners can delete collaboration snapshots"
on public.configkit_collab_snapshots for delete to authenticated
using (private.configkit_collab_is_owner(document_id));

do $$
declare t text;
begin
  foreach t in array array['configkit_collab_documents','configkit_collab_members','configkit_collab_invites','configkit_collab_updates','configkit_collab_comments','configkit_collab_snapshots'] loop
    execute format(
      'create policy %I on public.%I as restrictive for all to authenticated using ((auth.jwt()->>''client_id'' is null) and private.email_2fa_access_allowed()) with check ((auth.jwt()->>''client_id'' is null) and private.email_2fa_access_allowed())',
      t || '_verified_session_gate', t
    );
  end loop;
end;
$$;

drop policy if exists "ConfigKit collaborators can receive private presence and broadcasts" on realtime.messages;
drop policy if exists "ConfigKit collaborators can send private presence and broadcasts" on realtime.messages;
create policy "ConfigKit collaborators can receive private presence and broadcasts"
on realtime.messages for select to authenticated
using (extension in ('presence','broadcast') and private.configkit_collab_can_access_topic(realtime.topic()));
create policy "ConfigKit collaborators can send private presence and broadcasts"
on realtime.messages for insert to authenticated
with check (extension in ('presence','broadcast') and private.configkit_collab_can_access_topic(realtime.topic()));
