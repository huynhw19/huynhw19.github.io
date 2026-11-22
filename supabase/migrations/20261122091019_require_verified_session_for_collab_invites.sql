create or replace function private.configkit_collab_accept_invite(p_token_hash text)
returns table(document_id uuid, role text)
language plpgsql security definer
set search_path = ''
as $$
declare
  v_invite public.configkit_collab_invites%rowtype;
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Sign in before accepting a collaboration invitation';
  end if;
  if (auth.jwt()->>'client_id') is not null or not private.email_2fa_access_allowed() then
    raise exception 'A verified ConfigKit session is required to accept this invitation';
  end if;
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'This collaboration invitation is invalid';
  end if;
  select * into v_invite
  from public.configkit_collab_invites i
  where i.token_hash = p_token_hash
    and i.accepted_at is null
    and i.revoked_at is null
    and i.expires_at > now()
  for update;
  if not found then
    raise exception 'This invitation has expired, been revoked, or was already used';
  end if;
  if exists (
    select 1 from public.configkit_collab_members m
    where m.document_id = v_invite.document_id and m.user_id = v_user_id
  ) then
    raise exception 'You already have access to this document';
  end if;
  insert into public.configkit_collab_members(document_id,user_id,role,invited_by)
  values (v_invite.document_id,v_user_id,v_invite.role,v_invite.invited_by);
  update public.configkit_collab_invites
  set accepted_at = now(), accepted_by = v_user_id
  where id = v_invite.id;
  return query select v_invite.document_id, v_invite.role;
end;
$$;
