-- Expose only the signed-in user's live Supabase Auth sessions and allow
-- revoking another session without exposing auth.sessions to the browser.
-- The current session is deliberately protected from per-device revocation.

create or replace function public.list_my_auth_sessions()
returns table (
  session_id uuid,
  created_at timestamptz,
  refreshed_at timestamp without time zone,
  user_agent text,
  is_current boolean,
  device_name text,
  first_seen_at timestamptz,
  last_seen_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    s.id,
    s.created_at,
    s.refreshed_at,
    coalesce(nullif(s.user_agent, ''), ''),
    s.id::text = (auth.jwt() ->> 'session_id'),
    coalesce(nullif(d.device_name, ''), nullif(s.user_agent, ''), 'Unknown device'),
    d.first_seen_at,
    d.last_seen_at
  from auth.sessions as s
  left join public.configkit_device_sessions as d
    on d.session_id = s.id and d.user_id = s.user_id
  where s.user_id = auth.uid()
  order by coalesce(s.refreshed_at, s.created_at) desc;
$$;

create or replace function public.revoke_my_auth_session(p_session_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_current_session_id text := auth.jwt() ->> 'session_id';
  v_deleted integer := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if p_session_id is null then
    raise exception 'A session ID is required' using errcode = '22004';
  end if;

  if p_session_id::text = v_current_session_id then
    raise exception 'You cannot revoke the device you are currently using' using errcode = '22023';
  end if;

  delete from auth.sessions
   where id = p_session_id
     and user_id = v_user_id;
  get diagnostics v_deleted = row_count;

  delete from public.configkit_device_sessions
   where session_id = p_session_id
     and user_id = v_user_id;

  return v_deleted > 0;
end;
$$;

revoke all on function public.list_my_auth_sessions() from public, anon;
revoke all on function public.revoke_my_auth_session(uuid) from public, anon;
grant execute on function public.list_my_auth_sessions() to authenticated;
grant execute on function public.revoke_my_auth_session(uuid) to authenticated;
